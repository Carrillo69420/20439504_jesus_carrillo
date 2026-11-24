# Evidencia 05 — Criterio de conservación de bitácoras

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 5 (sección 11 de la guía)
- Servidores: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`, y `dba-u3-mongo`, MongoDB 7.0.45 en Docker, el del LAB-02
- Fecha: 24 de noviembre de 2026

## Objetivo

Fijar, para cada registro que dejaron los LAB-01 y LAB-02, cuánto tiempo se conserva, dónde, quién puede leerlo y qué se hace al vencer el plazo. El criterio parte de lo observado en esos laboratorios y de la guía NIST SP 800-92 (REF-U3-03). El mecanismo técnico de respaldo se estudia en la Unidad V; aquí solo se fija el criterio.

## Pasos y resultados

### 1. Dónde están hoy las bitácoras

Los tres comandos se corrieron en PowerShell. Ninguno abre una sesión en PostgreSQL, así que no dejan líneas nuevas en la bitácora.

Los archivos de la bitácora de PostgreSQL:

```powershell
docker exec dba-u3-pg ls -l /var/lib/postgresql/data/log
```

```text
total 52
-rw------- 1 postgres postgres 25205 Oct 29 13:01 postgresql-2026-10-29_103255.log
-rw------- 1 postgres postgres 11570 Oct 31 16:27 postgresql-2026-10-31_094251.log
-rw------- 1 postgres postgres  6801 Nov 24 09:42 postgresql-2026-11-24_083201.log
```

Las líneas que guardan una contraseña, contadas sin mostrarlas:

```powershell
docker exec dba-u3-pg grep -rc "PASSWORD '" /var/lib/postgresql/data/log
```

```text
/var/lib/postgresql/data/log/postgresql-2026-11-24_083201.log:0
/var/lib/postgresql/data/log/postgresql-2026-10-31_094251.log:0
/var/lib/postgresql/data/log/postgresql-2026-10-29_103255.log:5
```

Dónde guarda Docker lo que cada contenedor escribe en su salida estándar:

```powershell
docker inspect --format '{{.Name}} {{json .HostConfig.LogConfig}}' dba-u3-pg dba-u3-mongo
```

```text
/dba-u3-pg {"Type":"local","Config":{}}
/dba-u3-mongo {"Type":"local","Config":{}}
```

Lo que muestran:

- **Los archivos se acumulan.** Hay uno por cada arranque del servidor, con la fecha y la hora en el nombre, y nada ha borrado los de octubre. Con un nombre así ningún archivo se reutiliza. PostgreSQL solo sobrescribe un archivo cuando la rotación por tiempo repite su nombre y `log_truncate_on_rotation` está activo, que es como su documentación propone guardar 7 días. También abre uno nuevo cada 24 horas o cada 10 MB, los valores por defecto, que el LAB-01 no cambió. Hoy no hay ningún plazo: los archivos crecen sin límite.
- **Están junto a los datos.** El directorio `log` está dentro de `PGDATA`, en el volumen `dba-u3-pg-data`. Recrear el contenedor con el mismo volumen no los pierde; borrar el volumen, sí, junto con la base.
- **Solo los lee el dueño.** `-rw-------` son los permisos `0600`, el valor por defecto de `log_file_mode`: solo la cuenta `postgres` del sistema puede leerlos. Desde SQL, solo un superusuario, porque el esquema `dba` de la vista `dba.bitacora` está cerrado a `PUBLIC` (LAB-01).
- **Los secretos siguen ahí.** Las 5 líneas del 29 de octubre son la contraseña del `CREATE ROLE rol_temporal` y cuatro resúmenes SCRAM de `ALTER USER` ([evidencia 15 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/15-cronologia.md)). Se quitaron de la copia exportada, pero en el servidor siguen; borrar `rol_temporal` no borró la suya ([evidencia 06 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/06-privilegios-estructura.md)).
- **La bitácora de `mongod` es del contenedor.** Los dos usan el controlador `local` sin opciones: Docker guarda hasta 100 MB por contenedor, en 5 archivos de 20 MB comprimidos, y descarta lo más viejo. Esa bitácora no está en el volumen `dba-u3-mongo-data`, así que un contenedor recreado empieza con ella vacía aunque use el mismo volumen. En `dba-u3-pg` casi no importa, porque desde el LAB-01 su bitácora va al colector.

### 2. El criterio de conservación

| Registro | Ubicación actual | Riesgo de pérdida observado | Sensibilidad | Periodo propuesto | Justificación | Dónde se conserva | Quién puede leerlo | Acción al vencer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Accesos de PostgreSQL | Archivo del colector (`pg_current_logfile()`), en el directorio `log` del volumen `dba-u3-pg-data` | Rotación del archivo; reinstalación o recreación del servidor. Cada arranque abrió un archivo nuevo, y `dba.bitacora` solo lee el actual. Si se borra el volumen, los archivos se van con los datos | Media: quién se conectó, desde qué equipo y cuándo, incluidas cuentas de personas como `soporte_ana` | 90 días | Mucho volumen y un valor que se agota pronto. Es el máximo del ejemplo de NIST para impacto moderado, y alcanza para investigar un acceso descubierto semanas después | En el servidor, hasta 90 días. La copia exportada, sin secretos y con hash, fuera del servidor que la genera | El DBA, para diagnosticar el servidor; Auditoría interna, en las copias exportadas | Supresión del archivo, después de extraer las líneas de privilegios y estructura |
| Cambios de privilegios y estructura | Archivo del colector | Los del archivo de accesos, porque comparten el mismo. Además, un superusuario puede apagar el registro de su sesión con `SET log_statement = 'none'` sin dejar rastro ([evidencia 10 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/10-diseno-auditoria.md)) | Alta: dicen qué puede hacer cada cuenta, y el archivo del 29 de octubre guarda una contraseña y cuatro resúmenes SCRAM (paso 1) | 2 años | Pocas líneas, y la única historia de quién podía hacer qué: el catálogo solo muestra el estado de hoy. Un permiso dado hace meses sigue vigente | Extraídas del archivo a los 90 días, sin secretos y con hash, fuera del servidor | El DBA; Auditoría interna, en las copias exportadas | Supresión, con constancia de la depuración |
| Modificaciones de datos (`log_statement = 'mod'`) | Archivo del colector | Los mismos que los cambios de privilegios, `SET log_statement` incluido | Alta: cada sentencia trae sus valores, como el teléfono y el RFC de las Actividades 7 y 12 del LAB-01 | 90 días | El registro durable de los cambios en `clientes` es la auditoría; estas líneas sirven para cotejarla, como en la Actividad 14 del LAB-01. Son otra copia de datos personales | Igual que los accesos | El DBA; Auditoría interna, en las copias exportadas | Supresión |
| `auditoria.cambios_clientes` | Tabla en `comercial` | El dueño de la tabla o un superusuario pueden borrar renglones o apagar el disparador, y la tabla no avisa ([Actividad 14 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/13-manipulacion.md)). Si se borra el volumen, se pierde con la base | Contiene datos personales: la fila completa antes y después de cada cambio, RFC incluido. Alta | Mientras exista el cliente y, después de su baja, el bloqueo. Plazo a confirmar con el área jurídica: hay que revisar el plazo de prescripción de las acciones que puedan surgir de la relación con el cliente, que es lo que dura el bloqueo (LFPDPPP, arts. 2, fr. III, y 24) | Es la prueba de quién cambió o borró a cada cliente y, a la vez, otra copia de sus datos. Tratar sus renglones como bloqueo concilia las dos cosas (paso 4) | En el esquema `auditoria`, cerrado a la aplicación. Lo que sale al expediente va sin los datos del cliente | Auditoría interna, solo para leer; el DBA, como custodio | Supresión de los renglones del cliente, con constancia de la fecha, la tabla, cuántos renglones y quién la hizo, sin copiar lo borrado |
| Bitácora de `mongod` | `systemLog.path` o salida estándar; `getLog` solo en memoria. En `dba-u3-mongo`, la salida estándar, que Docker guarda con el controlador `local` (paso 1) | `getLog` guarda 1024 eventos y se vació al reiniciar: pasó de 388 a 78 ([informe del LAB-02](../../laboratorio-02-trazabilidad-mongodb/informe.md)). Docker guarda hasta 100 MB y descarta lo más viejo, y un contenedor recreado empieza vacío | Alta: las operaciones lentas traen sus valores, y las dos del LAB-02 traen el teléfono del cliente | 90 días | Es el mismo tipo de registro que los accesos y las modificaciones de PostgreSQL: mismo plazo, aunque cambie el motor | En un archivo (`systemLog.path`) dentro de un volumen, no solo en la salida del contenedor. La copia exportada, con hash, fuera del servidor | El DBA; Auditoría interna, en las copias exportadas | Supresión |
| `system.profile` | Colección limitada de 1 MB | Se sobrescribe sola. Además, al reiniciar, el perfilador volvió al nivel 0 sin aviso, y el `drop()` de la Actividad 4 del LAB-02 borró lo de la Actividad 3 | Alta: guarda el filtro y los valores de las operaciones que perfila, como el teléfono del LAB-02 | Lo que dure el análisis de desempeño que lo use | Es una herramienta de diagnóstico, no de auditoría: solo registra lo que se le pide, y nada avisa cuando se apaga. Para auditar están la bitácora y las instantáneas | En el servidor no se puede conservar. Lo que sirva se exporta con hash al expediente del análisis | El DBA, para diagnosticar el rendimiento; Auditoría interna, en las copias exportadas | Supresión de las copias exportadas al cerrar el análisis |
| Instantáneas de privilegios (MongoDB) | `auditoria.instantaneas_privilegios`, en el mismo servidor que describen | Solo existen las que alguien tomó: en Community, un cambio entre dos tomas no queda en ningún registro ([Actividad 7 del LAB-02](../../laboratorio-02-trazabilidad-mongodb/evidencias/07-privilegios-control-compensatorio.md)). Quien administra los usuarios también puede borrarlas | Alta (seguridad): qué roles tiene cada cuenta. No tiene datos personales | 2 años | En Community son la única historia de privilegios: equivalen a los cambios de privilegios de PostgreSQL, y llevan su plazo | En la colección y, cada una, exportada con hash fuera del servidor | El DBA, que las toma; Auditoría interna, que las compara | Supresión de las vencidas, conservando siempre la más reciente |

Los lectores son los de la matriz de la [evidencia 02](02-responsables.md). En el catálogo de la [evidencia 04](04-catalogo.md), la conservación de CAT-02, CAT-05, CAT-06, CAT-07 y CAT-08 quedó pendiente para esta actividad: corresponde a los renglones de `auditoria.cambios_clientes`, `system.profile`, los tres de PostgreSQL, la bitácora de `mongod` y las instantáneas.

### 3. Cómo se fijaron los plazos

No hay una cifra correcta. NIST SP 800-92 dice que no hay consenso sobre cuánto conservar (nota 49) y que los valores de su tabla 4-1 (sección 4.2, p. 4-6) son un punto de partida, no para adoptarse tal cual. También advierte que las leyes pueden exigir más, sobre todo con datos personales. Para la conservación, la tabla propone de 1 a 2 semanas en sistemas de impacto bajo, de 1 a 3 meses en los de impacto moderado y de 3 a 12 meses en los de impacto alto.

Con eso, los registros se agruparon por lo que valen y lo que contienen:

- **Rutina, 90 días:** accesos, modificaciones y bitácora de `mongod`. Mucho volumen y un valor que se agota pronto. `comercial` se toma como un sistema de impacto moderado, y se usa el máximo de su rango porque un evento puede necesitarse semanas o meses después (NIST, nota 46). Más tiempo solo acumularía datos personales sin finalidad.
- **Seguridad, 2 años:** cambios de privilegios y estructura, e instantáneas de privilegios. El estado actual de los permisos se consulta en el catálogo; su historia solo está en estos registros. Son el doble del máximo de la tabla porque una revisión que cubre un año completo se hace cuando ese año ya terminó: con 12 meses, sus primeros meses ya se habrían borrado.
- **Con el dato completo:** `auditoria.cambios_clientes`. Su plazo depende de la ley, no del DBA (paso 4).
- **Diagnóstico:** `system.profile`. Se conserva lo que pida un análisis y nada más.

Ninguno de estos plazos es legal: son criterio propio, salvo el de la auditoría, que queda a confirmar con el área jurídica. Si una investigación pide conservar algo por más tiempo, se conserva mientras dure. NIST distingue la conservación ordinaria (*retention*) de la que se hace por una investigación (*preservation*), y pide que la segunda prevalezca sobre los plazos ordinarios (secciones 3.2 y 4.2).

Tres de los registros viven en el mismo archivo. Al cumplir 90 días, de cada archivo se extraen, sin secretos, las líneas de privilegios y estructura a la copia de 2 años, y el resto se suprime. NIST llama reducción a esta selección: dejar en el almacenamiento largo solo las entradas que interesan (sección 3.2).

Si una contraseña o un resumen queda en la bitácora, como pasó en el LAB-01, se trata como una divulgación, que es uno de los temas que NIST pide resolver en la política (sección 4.2): se cambia la contraseña de esa cuenta y la línea no sale del servidor sin sustituirse.

### 4. El conflicto con la supresión de datos personales

En la Actividad 13 del LAB-01, el `DELETE` quitó a Pedro Ruiz de `clientes`, pero sus datos siguieron completos en la auditoría y en la bitácora ([evidencia 12 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/12-altas-bajas.md)). Conservar la auditoría choca con la [retención de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/10-retencion.md), que suprime los datos al vencer su plazo, previo bloqueo (LFPDPPP, art. 10). El LAB-01 dejó pendiente un renglón de retención para la auditoría y otro para la bitácora, y la tabla del paso 2 los propone así:

- **En la bitácora, el plazo corto lo resuelve.** Las líneas que traen datos de clientes, las de modificaciones, se suprimen a los 90 días. Las que se quedan 2 años, de privilegios y estructura, no los traen.
- **La auditoría se trata como un bloqueo** (LFPDPPP, art. 2, fr. III). Mientras el cliente exista, sus renglones explican su historia. Después de la baja se conservan sin usarse para nada más, solo para determinar responsabilidades, y se suprimen al vencer la prescripción. El esquema `auditoria`, cerrado a la aplicación, ya va en ese sentido.
- **Las copias que salen del servidor no llevan los datos.** La muestra de la auditoría que pide la Actividad 8 solo trae el evento, el momento, la cuenta, la aplicación, la operación y el cliente.
- **Cada depuración deja constancia** de la fecha, la tabla, cuántos renglones y quién la hizo, sin copiar lo borrado. Así se puede demostrar que se suprimió sin conservar lo suprimido.

El DBA no fija ese plazo. Según la [matriz de gobierno de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md), el área jurídica fija los plazos de conservación y de bloqueo, el responsable de privacidad decide si procede cada cancelación y Dirección aprueba la política. El DBA, como custodio, propone y aplica.

## Preguntas

**1. ¿Por qué la bitácora de cambios de privilegios merece más tiempo de conservación que la de consultas rutinarias?**

Porque su efecto dura y su volumen no. Un `GRANT` sigue vigente hasta que alguien lo revoca: para explicar por qué una cuenta pudo leer `clientes` en cierta fecha, hay que llegar a la línea en que recibió el permiso, aunque haya pasado más de un año. Una consulta rutinaria importa en su momento, y después de unas semanas solo sirve si una investigación la busca. Además:

- **Son pocas líneas**, así que guardarlas dos años casi no cuesta. Las de rutina crecen con cada conexión y cada cambio.
- **No traen datos de clientes.** Las de rutina sí, como el teléfono de un `UPDATE`, y guardarlas más de lo necesario va contra la minimización (LFPDPPP, art. 12). Los secretos de las de privilegios se sustituyen antes de guardarlas.
- **Son las que alguien querría borrar.** Quien abusa de un permiso tiene motivos para quitar su rastro, y en el servidor un superusuario puede hacerlo (Actividad 14 del LAB-01). La copia larga, fuera del servidor, es la que queda.

**2. ¿Qué control de integridad aplicarás a las bitácoras exportadas?**

Una huella SHA-256 por archivo, como en la [Actividad 16 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/15-cronologia.md) y la [Actividad 8 del LAB-02](../../laboratorio-02-trazabilidad-mongodb/evidencias/08-conservacion.md):

1. **Primero se quitan los secretos.** Antes de que el archivo salga del servidor se sustituyen las contraseñas y los resúmenes SCRAM; el archivo del 29 de octubre todavía tiene cinco (paso 1). La huella se calcula sobre la copia limpia.
2. **La huella se calcula dentro del servidor**, con `sha256sum`, en el momento de exportar, y se vuelve a calcular en el equipo que recibe la copia, con `Get-FileHash`. Si coinciden, la copia llegó igual.
3. **La huella se guarda aparte del archivo**, en el expediente y en el historial de Git. Quien altere el archivo puede calcular su nueva huella, pero cambiar también la guardada dejaría su propio commit en el historial. Es lo que pide NIST: un resumen por archivo, guardado de forma segura y protegido contra cambios (sección 3.2).
4. **Se comprueba antes de usarla.** Si la huella ya no coincide, el archivo no sirve como prueba.
5. **Nada cambia sus bytes después.** La huella es de los bytes exactos: un cambio de codificación o de fines de línea la rompe, aunque el texto se vea igual. Por eso se exporta con `-o` y `docker cp`, y no con `>` de PowerShell, que guarda en UTF-16 (LAB-01).

La tabla 4-1 de NIST marca esta verificación como necesaria para las bitácoras rotadas desde el impacto moderado.

**3. ¿Qué diferencia hay entre conservar una bitácora y respaldar una base de datos?**

Responden preguntas distintas. Un respaldo guarda el estado de los datos para volver a él después de una pérdida; una bitácora guarda lo que pasó para poder demostrarlo. Con un respaldo se puede restaurar `clientes`, pero no saber quién dio de baja a Pedro Ruiz; con la bitácora se sabe quién fue, pero no se puede reconstruir la tabla.

| | Conservar una bitácora | Respaldar una base de datos |
| --- | --- | --- |
| Para qué | Demostrar qué pasó, quién lo hizo y cuándo | Recuperar los datos después de una pérdida |
| Qué guarda | Los eventos, en el orden en que ocurrieron | El estado de los datos en un momento |
| Qué lo vuelve inútil | Que se altere: ya no prueba nada | Que no se pueda restaurar |
| Cuánto dura | El plazo de este criterio | El que fije la política de respaldo (Unidad V) |

En `comercial` se ve la diferencia. Un respaldo lógico de la base, como el de `pg_dump`, traería la definición de la vista `dba.bitacora`, pero no sus líneas, porque la vista lee archivos que están fuera de la base. En cambio, sí traería `auditoria.cambios_clientes`, que es una tabla. Ese respaldo es otra copia de los datos personales de la auditoría, y el plazo del paso 4 también lo alcanza, como concluyó la Unidad II para todas las copias.

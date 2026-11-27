# Expediente de auditoría interna — Base comercial

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4
- LAB-03 de la Unidad III, Actividad 9 (sección 15 de la guía). Evidencia oficial de la unidad
- Fecha: 26 de noviembre de 2026

## 1. Alcance

| Elemento | Detalle |
| --- | --- |
| Sistemas | `dba-u3-pg`: PostgreSQL 16.15 en Docker (imagen `postgres:16`), base `comercial`, datos en el volumen `dba-u3-pg-data`, zona horaria America/Mazatlan y sin puerto publicado: el administrador entra con `docker exec` por el socket local. `dba-u3-mongo`: MongoDB 7.0.45 Community en Docker, el del LAB-02; su evidencia son los archivos exportados entonces (E6) |
| Periodo revisado | Del 29 de octubre de 2026 a las 10:32:55, cuando arranca el archivo de bitácora más antiguo, al 26 de noviembre de 2026, fecha de la exportación de E5 |
| Responsable del expediente | Jesús Arturo Carrillo Avilez, como DBA (custodio). Lo revisa Auditoría interna |

## 2. Configuración de auditoría

| Mecanismo | Qué registra | Dónde se configuró | Evidencia |
| --- | --- | --- | --- |
| Bitácora de PostgreSQL | Arranques, conexiones y desconexiones y, con `log_statement = 'mod'`, las sentencias de estructura, privilegios y modificación de datos, cada una con usuario, base, aplicación y cliente | LAB-01, Actividades 2 y 4 | [E1](evidencias/E1-configuracion-registro.txt): `logging_collector`, `log_connections` y `log_disconnections` en `on` y `log_statement` en `mod`, desde el archivo de configuración |
| Auditoría del dato | Disparador `trg_auditoria_clientes` sobre `clientes`: guarda en `auditoria.cambios_clientes` quién, cuándo, con qué aplicación, la operación y los valores antes y después | LAB-01, Actividad 10 | [E3](evidencias/E3-disparadores.txt): activo (`tgenabled = O`). [E4](evidencias/E4-muestra-auditoria.txt): los 10 eventos más recientes |
| Perfilador de MongoDB | Operaciones de la base `comercial` en `system.profile`, en nivel 2 y después con filtro | LAB-02, Actividades 3 y 4 | [E6](evidencias/E6-mongodb/): `system-profile-actividad3.json` y `system-profile.json` |
| Bitácora de `mongod` | Accesos y operaciones lentas | LAB-02, Actividad 5 | E6: `bitacora-mongod.log` |
| Instantáneas de privilegios de MongoDB | Roles de cada cuenta en cada toma: el control compensatorio de Community | LAB-02, Actividad 7 | [LAB-02, evidencia 07](../laboratorio-02-trazabilidad-mongodb/evidencias/07-privilegios-control-compensatorio.md) |

## 3. Bitácora interpretada

Las líneas son de [E5](evidencias/E5-bitacora-postgresql.log), con el formato de la cronología del LAB-01 ([evidencia 15](../laboratorio-01-bitacoras-auditoria/evidencias/15-cronologia.md)). Hasta la línea 241, donde termina la bitácora exportada del LAB-01, E5 es idéntica a esa exportación línea por línea (se comparó con `diff`): esas líneas no cambiaron en el servidor desde el LAB-01.

| # | Cuándo | Quién | Desde dónde | Qué ocurrió | Tipo de evento | Qué prueba | Fuente |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 31/10/2026 09:50:08.326 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Cambia el RFC de María García (cliente 3) de `GAMA780912XYZ` a `GAMA780912ZZZ` | Modificación de datos | Que la cuenta de la aplicación hizo el cambio y a qué hora; la auditoría guarda el valor anterior. No prueba qué persona usaba la aplicación ni que el cambio estuviera autorizado | E5, línea 196; E4, evento 1 |
| 2 | 31/10/2026 10:04:56.378 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Intenta borrar la auditoría y apagar su disparador; los dos intentos se rechazan | Error de privilegios | Que el control preventivo funciona con la cuenta de la aplicación. No dice quién lo intentó | E5, líneas 217 a 221 |
| 3 | 31/10/2026 10:05:15.746 a .749 | `postgres` | Socket local, `psql` | Apaga el disparador, cambia el RFC de María García a `GAMA780912GHI` y vuelve a encenderlo en 3 milisegundos | Cambio de estructura y modificación de datos | Que el superusuario evadió la auditoría del dato: el cambio no está en E4, que salta del evento 3 al 4, y solo la bitácora lo prueba | E5, líneas 226 a 228; [LAB-01, evidencia 13](../laboratorio-01-bitacoras-auditoria/evidencias/13-manipulacion.md) |
| 4 | 31/10/2026 10:07:37.088 | `soporte_ana` | 127.0.0.1, `psql` | Sesión de 6 milisegundos | Acceso | Que hubo una conexión. No prueba qué leyó, porque `mod` no registra `SELECT` | E5, líneas 231 a 233; [LAB-01, evidencia 14](../laboratorio-01-bitacoras-auditoria/evidencias/14-limites.md) |
| 5 | 26/11/2026 23:25:32.820 | `postgres` | Socket local, `psql` | Agrega la columna `canal_alta` a `clientes` | Cambio de estructura | Que el cambio tiene un folio aprobado (`CAM-2026-014`) y se hizo dentro de su ventana | E5, línea 323; [evidencia 06](evidencias/06-conciliacion.md) |

El incidente del RFC de María García son los eventos 1 a 3: el primer cambio entró por la aplicación y quedó auditado, y el segundo lo hizo el administrador con la auditoría apagada. Ninguno de los dos tiene folio.

## 4. Elementos de gobierno

- **Calidad:** ocho hallazgos (C1 a C8) en los clientes 1, 7 y 8, escalados a la Gerencia Comercial, que es la propietaria ([evidencia 01](evidencias/01-calidad.md)).
- **Responsables:** propietario, custodio y usuarios de cada conjunto ([evidencia 02](evidencias/02-responsables.md)).
- **Diccionario:** comentarios en la tabla `clientes` y en todas sus columnas ([script 02](sql/02-comentarios-diccionario.sql)), exportados en [CSV](evidencias/diccionario-clientes.csv) con clasificación y finalidad ([evidencia 03](evidencias/03-diccionario.md)).
- **Catálogo:** ocho conjuntos, de CAT-01 a CAT-08, de los dos motores ([evidencia 04](evidencias/04-catalogo.md)).

## 5. Conservación

El [criterio de conservación](evidencias/05-conservacion.md) fija, para los siete tipos de registro, el plazo, dónde se guarda, quién lo lee y qué se hace al vencer: por ejemplo, 90 días para accesos y modificaciones, y 2 años para cambios de privilegios y estructura y para las instantáneas de MongoDB. Queda pendiente que el área jurídica confirme el plazo de prescripción.

## 6. Políticas

| Política | Regla verificable | Evidencia de hoy |
| --- | --- | --- |
| [POL-01 Acceso](politicas/POL-01-acceso.md) | Cada cuenta, permiso o rol tiene un folio aprobado por el propietario; conciliación mensual y revisión anual | E2 y la [evidencia 06](evidencias/06-conciliacion.md): ningún cambio de cuentas tiene folio |
| [POL-02 Respaldo](politicas/POL-02-respaldo.md) | Respaldo diario fuera del servidor, 30 días, y prueba de restauración mensual | No existe (H-07) |
| [POL-03 Retención](politicas/POL-03-retencion.md) | Plazos de la evidencia 05, constancia de cada depuración y preservación por escrito | Archivos de bitácora desde el 29/10 (E5); no hay constancias |
| [POL-04 Restauración](politicas/POL-04-restauracion.md) | Folio, preservar la evidencia antes y reaplicar las supresiones después | No existe |
| [POL-05 Datos sensibles](politicas/POL-05-datos-sensibles.md) | Cada área lee solo sus campos; datos reales solo en producción; lecturas registradas | E2: no se cumple (H-06); no hay registro de lecturas (H-10) |
| [POL-06 Cambios en producción](politicas/POL-06-cambios-produccion.md) | Folio antes, sin bajar `log_statement` ni apagar el disparador durante, y conciliación de Auditoría interna después | `gobierno.solicitudes_cambio` ([script 04](sql/04-registro-cambios.sql)), evidencia 06 y E5 |

## 7. Conciliación de cambios

La [evidencia 06](evidencias/06-conciliacion.md) compara con los folios las 27 sentencias de estructura y privilegios de E5:

- 1 tiene folio y se hizo dentro de su ventana: `CAM-2026-014` (línea 323).
- 9 son de preparación: el montaje de la auditoría (líneas 130 a 170) y el del registro de cambios (306 a 308).
- 3 fallaron y no cambiaron nada (líneas 36, 104 y 220).
- 14 se hicieron sin folio: permisos, estructura, contraseñas, `log_statement` y el apagado del disparador (H-01, H-03 y H-04).

## 8. Hallazgos

| ID | Hallazgo | Fuente | Severidad | Impacto | Recomendación | Decisión requerida de |
| --- | --- | --- | --- | --- | --- | --- |
| H-01 | El superusuario apagó la auditoría, cambió el RFC de María García y la volvió a encender, sin folio | E5, líneas 226 a 228; evidencia 06 | Alta | Un dato fiscal cambió sin quedar en la auditoría, y la auditoría deja de ser confiable para ese periodo | Investigarlo; confirmar el RFC con la titular; alertar cada `DISABLE TRIGGER` de la bitácora y usar cuentas de administrador nominales | Auditoría interna y Gerencia Comercial |
| H-02 | La cuenta de la aplicación intentó borrar la auditoría y apagar el disparador | E5, líneas 217 a 221 | Media | El control lo impidió, pero alguien usó la cuenta de la aplicación para intentarlo | Investigar quién usaba `app_ventas` y dónde está guardada su contraseña | Auditoría interna |
| H-03 | 14 cambios de permisos, estructura y cuentas sin folio, y el registro de cambios creado sin folio propio | Evidencia 06 | Media | No se puede demostrar que estuvieran autorizados | Regularizarlos con folios posteriores y aplicar POL-01 y POL-06 desde hoy | Comité de cambios y propietarios |
| H-04 | `log_statement` bajó a `ddl` 12 minutos, y en ese hueco cambió el RFC del cliente 3 sin registro | E5, líneas 60 y 80; LAB-01, evidencia 15 | Alta | Un cambio de un dato personal no tiene evidencia | Alertar todo `ALTER SYSTEM` de parámetros `log_*` y permitirlo solo con folio aprobado por Auditoría interna | Auditoría interna |
| H-05 | El archivo de bitácora del 29/10 guarda en el servidor una contraseña y cuatro resúmenes SCRAM | [Evidencia 05](evidencias/05-conservacion.md), paso 1; evidencia 06 | Alta | Quien lea el directorio `log` obtiene una credencial y puede atacar las otras | Cambiar las contraseñas de `app_ventas` y `soporte_ana`, y depurar el archivo con constancia (POL-03), conservando la copia tapada E5 | Auditoría interna, que decide si se preserva, y el DBA |
| H-06 | `soporte_ana` tiene `SELECT` sobre toda la tabla `clientes`, RFC incluido, y la matriz de la Unidad II no le da el RFC a Atención al cliente | E2; [matriz de la Unidad II](../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md) | Media | Lee datos personales que su función no necesita | Darle una vista con sus campos y quitar el `SELECT` directo (POL-05) | Gerencia Comercial y responsable de privacidad |
| H-07 | No hay respaldos | POL-02 | Alta | Si se borra `dba-u3-pg-data` se pierden juntos los clientes, la auditoría y la bitácora | Aplicar POL-02; el procedimiento se define en la Unidad V | Dirección |
| H-08 | No existe un ambiente de pruebas, y `CAM-2026-014` no se probó antes | Evidencia 06; POL-06, regla 1 | Media | Un cambio con errores llega directo a producción | Crear un ambiente de pruebas con datos ficticios (POL-05, regla 2) | Comité de cambios y Dirección |
| H-09 | Ocho problemas de calidad en los clientes 1, 7 y 8 | [Evidencia 01](evidencias/01-calidad.md) | Media | Facturas y contacto con datos erróneos, y analítica sesgada | Corregirlos con el cliente, cada uno con folio | Gerencia Comercial |
| H-10 | Las lecturas de datos personales no se registran | LAB-01, evidencia 14; POL-05 | Media | No se puede saber quién leyó un RFC | Ver la sección 9 | Dirección |

Ningún hallazgo se corrigió durante el laboratorio: los registros 7 y 8 siguen con sus errores, y los permisos de E2 siguen como estaban.

## 9. Limitaciones conocidas y riesgos aceptados

| Limitación | Verificado o solo documentado | Riesgo | Quién debe aceptarlo |
| --- | --- | --- | --- |
| MongoDB Community no tiene auditoría nativa | Verificado en el LAB-02 ([evidencia 01](../laboratorio-02-trazabilidad-mongodb/evidencias/01-edicion-y-limitacion.md)). La auditoría de MongoDB Enterprise solo se documentó, no se practicó | Cambios de usuarios y de estructura sin registro; las instantáneas solo cubren los privilegios en el momento de cada toma | Dirección |
| Las lecturas no se auditan: `mod` no registra `SELECT` y el disparador no se activa con lecturas | Verificado (LAB-01, evidencia 14). `pgaudit` solo se documentó, no se instaló | No se sabe quién leyó datos personales (H-10) | Dirección, con el responsable de privacidad |
| El administrador puede apagar la auditoría | Verificado (E5, líneas 226 a 228) | Solo la bitácora lo detecta, y la custodia el mismo administrador | Dirección, con Auditoría interna |
| Un `SET log_statement` en una sesión no deja rastro | Documentado en el diseño del LAB-01 ([evidencia 10](../laboratorio-01-bitacoras-auditoria/evidencias/10-diseno-auditoria.md)) | La conciliación no ve lo que no se registró | Auditoría interna |
| E1 solo muestra la configuración de hoy | Verificado: las líneas 51, 60 y 80 de E5 muestran que cambió durante el periodo | No prueba que estuvo vigente todo el periodo | Auditoría interna |
| Lo que `getLog` muestra de MongoDB se vacía al reiniciar | Verificado ([LAB-02, evidencia 08](../laboratorio-02-trazabilidad-mongodb/evidencias/08-conservacion.md)) | Pérdida de la bitácora en memoria | DBA, con Dirección |

## 10. Índice de evidencias

| Archivo | Qué contiene | SHA-256 |
| --- | --- | --- |
| [E1-configuracion-registro.txt](evidencias/E1-configuracion-registro.txt) | Parámetros de registro vigentes | — |
| [E2-privilegios.txt](evidencias/E2-privilegios.txt) | Privilegios sobre tablas, sin `postgres` | — |
| [E3-disparadores.txt](evidencias/E3-disparadores.txt) | Disparadores y su estado | — |
| [E4-muestra-auditoria.txt](evidencias/E4-muestra-auditoria.txt) | 10 eventos de la auditoría, solo metadatos | — |
| [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log) | Los cuatro archivos de bitácora, del 29/10 al 26/11, 328 líneas, con las contraseñas tapadas | `b7afc78125c36aa25ecb8ba961367ed2aff2fe4af025fce9f72eb3474288b7b7` ([E5-bitacora-postgresql.sha256](evidencias/E5-bitacora-postgresql.sha256)) |
| [E6-mongodb/system-profile-actividad3.json](evidencias/E6-mongodb/system-profile-actividad3.json) | Perfilado en nivel 2 (LAB-02) | `a328c4113cb1fb144a4ed6af5b684770e5620c7f57d0eee82d7c96d8f321251a` |
| [E6-mongodb/system-profile.json](evidencias/E6-mongodb/system-profile.json) | Perfilado con filtro (LAB-02) | `f3f9492d2af7fe44478eb8517d7fc097ac331a6d69c58ab1c3085f8e645066a8` |
| [E6-mongodb/bitacora-mongod.log](evidencias/E6-mongodb/bitacora-mongod.log) | Bitácora de `mongod` (LAB-02) | `2885c072a00d7e226185ca1aa5db46e9026f03c80f3b8501f86068a7c1c3cc69` |
| [E6-mongodb/hashes.sha256](evidencias/E6-mongodb/hashes.sha256) | Hashes de los tres anteriores | — |
| [E6-mongodb/09-comparacion.md](evidencias/E6-mongodb/09-comparacion.md) | Comparación de la Actividad 9 del LAB-02. Es una copia: sus enlaces funcionan en el [original](../laboratorio-02-trazabilidad-mongodb/evidencias/09-comparacion.md) | — |
| [bitacora-lab01.log](../laboratorio-01-bitacoras-auditoria/evidencias/bitacora-lab01.log) | Bitácora exportada del LAB-01 | `3a9fe43ad4b5f063488d3232103fa82c4b4482491fa9a745c5ee3204475fa470` |
| [01](evidencias/01-calidad.md) a [06](evidencias/06-conciliacion.md), POL-01 a POL-06 y los scripts de `sql/` | Evidencias de las Actividades 1 a 7 | — |

Los hashes se comprobaron con `sha256sum -c` en el equipo después de copiar los archivos, y el `.gitattributes` del laboratorio evita que Git cambie sus finales de línea.

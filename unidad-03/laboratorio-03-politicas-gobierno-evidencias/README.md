# LAB-03 — Políticas, gobierno de datos y evidencias

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad III, evidencia oficial de la unidad: «Configuración o diseño de auditoría con bitácora interpretada»
- Entorno: PostgreSQL 16.15 en Docker (contenedor `dba-u3-pg`, el del LAB-01, con la base `comercial`) y los archivos exportados del LAB-02 (MongoDB 7.0.45)
- Fechas: 24 y 26 de noviembre de 2026

Este README relaciona cada actividad con su evidencia. Las evidencias están en `evidencias/`, en Markdown, con el comando, el resultado y su interpretación, y los scripts, en `sql/`.

| Actividad | Evidencia |
| --- | --- |
| 1. Calidad de datos desde la operación | [01-calidad.md](evidencias/01-calidad.md) y el script [01-verificaciones-calidad.sql](sql/01-verificaciones-calidad.sql) |
| 2. Propietarios, custodios y usuarios | [02-responsables.md](evidencias/02-responsables.md) |
| 3. Diccionario de datos operativo dentro del motor | [03-diccionario.md](evidencias/03-diccionario.md), el script [02-comentarios-diccionario.sql](sql/02-comentarios-diccionario.sql) y el archivo exportado [diccionario-clientes.csv](evidencias/diccionario-clientes.csv) |
| 4. Catálogo mínimo de datos | [04-catalogo.md](evidencias/04-catalogo.md) y el script [03-inventario-tablas.sql](sql/03-inventario-tablas.sql) |
| 5. Criterio de conservación de bitácoras | [05-conservacion.md](evidencias/05-conservacion.md) |
| 6. Políticas prácticas de datos | [POL-01 Acceso](politicas/POL-01-acceso.md), [POL-02 Respaldo](politicas/POL-02-respaldo.md), [POL-03 Retención](politicas/POL-03-retencion.md), [POL-04 Restauración](politicas/POL-04-restauracion.md), [POL-05 Uso de datos sensibles](politicas/POL-05-datos-sensibles.md) y [POL-06 Cambios en producción](politicas/POL-06-cambios-produccion.md) |
| 7. Registro de cambios y conciliación | [06-conciliacion.md](evidencias/06-conciliacion.md) y el script [04-registro-cambios.sql](sql/04-registro-cambios.sql) |
| 8. Evidencias técnicas del expediente | [E1](evidencias/E1-configuracion-registro.txt), [E2](evidencias/E2-privilegios.txt), [E3](evidencias/E3-disparadores.txt), [E4](evidencias/E4-muestra-auditoria.txt) y [E5](evidencias/E5-bitacora-postgresql.log) con su [hash](evidencias/E5-bitacora-postgresql.sha256), generadas con el script [05-evidencias-tecnicas.sql](sql/05-evidencias-tecnicas.sql), y [E6](evidencias/E6-mongodb/), copiada del LAB-02 |
| 9. Expediente de auditoría interna | [EXPEDIENTE.md](EXPEDIENTE.md) |

## Objetivo

Construir los elementos mínimos de gobierno práctico de datos para la base `comercial` (calidad, propietarios, catálogo, diccionario, criterio de conservación, políticas prácticas y registro de cambios) y relacionarlos con las evidencias técnicas de los laboratorios anteriores en un expediente para auditoría interna (sección 2 de la guía).

## Entorno

Se usa el servidor del LAB-01, como pide la sección 6 de la guía. Su despliegue está explicado en el [README del LAB-01](../laboratorio-01-bitacoras-auditoria/README.md). La sesión de administrador se abre igual que entonces:

```powershell
docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off
```

### Preparación (sección 6)

| Comando | Resultado |
| --- | --- |
| `\dn` | `auditoria`, `dba` y `public` |
| `SHOW log_statement;` | `mod` |
| `SELECT count(*) FROM dba.bitacora;` | `8` |

El contenedor se arrancó el 24 de noviembre a las 08:32:01, y PostgreSQL abrió un archivo de bitácora nuevo, `postgresql-2026-11-24_083201.log`. Sus 8 líneas eran las 6 del arranque y las 2 de la conexión de la sesión. `dba.bitacora` solo lee el archivo actual (`pg_current_logfile()`): lo que se registró en el LAB-01 sigue en los archivos del 29 y del 31 de octubre, en el directorio `log` del servidor.

### Evidencias técnicas (Actividad 8)

E1 a E5 salen del script 05, que guarda cada resultado con `\o` dentro del contenedor, porque `>` en PowerShell 5.1 guarda en UTF-16. Los scripts se copiaron al contenedor y se corrieron así:

```powershell
docker exec dba-u3-pg psql -U postgres -d comercial -P pager=off -f /tmp/lab03-sql/05-evidencias-tecnicas.sql
```

Después se copió la carpeta `/tmp/lab03-evid` a `evidencias/` con `docker cp`. E5 une los cuatro archivos de bitácora, no solo el vigente, y su hash se comprobó con `sha256sum -c` en el equipo. En E5 no queda ninguna contraseña ni resumen SCRAM.

## Verificación final (sección 16)

| Punto | Estado | Dónde |
| --- | --- | --- |
| Hallazgos de calidad registrados con responsable de la decisión | Cumplido | [Evidencia 01](evidencias/01-calidad.md) |
| Matriz de responsables con propietario, custodio y usuarios | Cumplido | [Evidencia 02](evidencias/02-responsables.md) |
| Comentarios en la tabla y en todas las columnas de `clientes` | Cumplido, también en `canal_alta` | [Evidencia 03](evidencias/03-diccionario.md) y script 04 |
| Diccionario exportado en CSV con clasificación y finalidad | Cumplido | [diccionario-clientes.csv](evidencias/diccionario-clientes.csv) |
| Catálogo con al menos cinco conjuntos de los dos motores | Cumplido, con ocho | [Evidencia 04](evidencias/04-catalogo.md) |
| Criterio de conservación para los siete tipos de registro | Cumplido | [Evidencia 05](evidencias/05-conservacion.md) |
| Seis políticas con regla verificable y evidencia nombrada | Cumplido | `politicas/` |
| Registro de cambios creado y conciliación con la bitácora | Cumplido | [Evidencia 06](evidencias/06-conciliacion.md) |
| Evidencias E1 a E6 generadas | Cumplido | `evidencias/` |
| `EXPEDIENTE.md` completo, con al menos tres eventos interpretados | Cumplido, con cinco | [EXPEDIENTE.md](EXPEDIENTE.md) |

## Preguntas de la Actividad 8

**1. Compara E2 con la matriz de roles de la Unidad II. ¿Coinciden? Si no, ¿es un hallazgo?**

No coinciden. `soporte_ana` tiene `SELECT` sobre toda la tabla `clientes`, RFC incluido, y la [matriz](../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md) le da a Atención al cliente el nombre, el correo y el teléfono, pero no el RFC. Es un hallazgo (H-06 del expediente). `app_ventas` es la cuenta de la aplicación, que la matriz no contempla, y su `UPDATE` se dio sin folio (línea 34 de E5): también queda como hallazgo (H-03).

**2. ¿Por qué E4 muestra solo metadatos y no `valores_antes` ni `valores_despues`?**

Porque esas columnas traen los datos personales de los clientes, como el RFC, y el expediente circula entre más personas que la base. Para probar que la auditoría funciona bastan quién, cuándo, con qué aplicación, qué operación y sobre qué cliente: es la minimización (LFPDPPP, art. 12) que pide POL-05. Los valores completos solo se entregan con folio, para una investigación.

**3. ¿Qué evidencia demostraría que E1 estuvo vigente durante todo el periodo revisado y no solo hoy?**

E1 es una foto de hoy, y E5 prueba que la configuración cambió: las líneas 51, 60 y 80 mueven `log_statement`. Para cubrir el periodo haría falta una serie de exportaciones de E1 con fecha y hash, tomadas en cada arranque y cada mes, y comprobar en la bitácora que entre una toma y la siguiente no hubo ningún `ALTER SYSTEM` sobre parámetros `log_*`. También ayuda que, después de cada arranque del periodo (líneas 1, 182, 253 y 298 de E5), las líneas sigan saliendo con el prefijo completo y con las sentencias. Aun así, un `SET` dentro de una sesión no dejaría rastro.

## Preguntas de reflexión (sección 18)

**1. ¿Por qué el gobierno de datos no es «burocracia» en el contexto del problema inicial de la unidad?**

Porque sin él no se puede contestar la pregunta del incidente. La bitácora dice quién cambió el RFC de María García y cuándo, pero no si podía hacerlo: para eso hace falta un propietario que autorice, un folio que lo registre y una política que diga qué es indebido. Sin esa referencia, el cambio con folio de hoy y el del 31 de octubre se verían igual.

**2. ¿Qué diferencia hay entre el propietario técnico de una tabla en PostgreSQL y el propietario del dato?**

El propietario técnico es el rol dueño del objeto, aquí `postgres`, que puede modificarlo o borrarlo: es un privilegio del motor. El propietario del dato es el área que decide para qué se usa, quién lo lee y cuándo está bien, aquí la Gerencia Comercial. El DBA es el custodio: ejecuta lo que el propietario decide.

**3. ¿Por qué una política sin evidencia no supera una auditoría?**

Porque el auditor revisa hechos, no intenciones. Si una regla no deja registro, no hay forma de demostrar que se cumplió. POL-02, por ejemplo, pide respaldos diarios, pero hoy no existe ninguno. Por eso cada política nombra su evidencia y dice «hoy no existe» donde falta.

**4. ¿Qué parte del expediente sería la más difícil de mantener actualizada? ¿Cómo lo resolverías?**

La conciliación. Cambia con cada sentencia, depende de leer todos los archivos de bitácora antes de que se depuren, y la tiene que hacer alguien distinto del DBA. La resolvería corriendo cada mes los scripts 04 y 05, que ya leen todos los archivos y guardan el hash, y con un calendario de Auditoría interna para revisar el resultado contra `gobierno.solicitudes_cambio`.

**5. ¿Qué hallazgo de tu expediente tiene mayor impacto y por qué?**

H-01: el administrador apagó la auditoría, cambió un dato fiscal y la volvió a encender en 3 milisegundos. Le quita confianza a toda la auditoría del dato, porque lo único que lo detectó es la bitácora, que custodia la misma persona. H-07, la falta de respaldos, también es alto, pero es un riesgo que todavía no ocurre.

**6. ¿Por qué documentar una limitación es preferible a ocultarla ante una auditoría?**

Porque una limitación oculta es un riesgo que nadie aceptó. Si el auditor la encuentra, pierde la confianza en todo el expediente. Documentada, alguien la acepta formalmente o decide invertir para cerrarla, y las conclusiones se leen con su alcance. Por ejemplo, la conciliación prueba los cambios que se registraron, no que no hubo otros.

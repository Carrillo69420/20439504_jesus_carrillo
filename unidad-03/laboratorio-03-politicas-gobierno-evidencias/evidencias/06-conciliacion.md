# Evidencia 06 — Registro de cambios y conciliación

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 7 (sección 13 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 26 de noviembre de 2026

## Objetivo

Dar a POL-06 su evidencia: un registro de solicitudes de cambio dentro del motor y la comparación de cada cambio de estructura y privilegios de la bitácora con el folio que lo autoriza.

## Pasos y resultados

### 1. El registro y el folio CAM-2026-014

El script [04-registro-cambios.sql](../sql/04-registro-cambios.sql) crea el esquema `gobierno` sin acceso para `PUBLIC` y la tabla `gobierno.solicitudes_cambio`, registra el folio `CAM-2026-014` y hace su cambio dentro de la ventana. Se copió al contenedor con `docker cp` y se corrió con la sesión de administrador:

PowerShell (App):

```powershell
docker exec dba-u3-pg psql -U postgres -d comercial -P pager=off -f /tmp/lab03-sql/04-registro-cambios.sql
```

```text
CREATE SCHEMA
REVOKE
CREATE TABLE
COMMENT
INSERT 0 1
ALTER TABLE
COMMENT
    folio     |   aprobado_por    | dentro_de_ventana
--------------+-------------------+-------------------
 CAM-2026-014 | Comité de cambios | t
(1 row)
```

El `ALTER TABLE` se hizo dentro de la ventana del folio, y el comentario de la columna `canal_alta` lo nombra, como pide la regla 2 de POL-06.

### 2. Los cambios de estructura y privilegios en la bitácora

La guía usa la vista `dba.bitacora`, pero esa vista solo lee el archivo vigente, y en este servidor cada arranque abrió uno nuevo. Por eso la consulta del script lee todos los archivos del directorio `log`:

| Parte | Qué hace |
| --- | --- |
| `pg_ls_logdir()` | Lista los archivos del directorio `log` del servidor |
| `CROSS JOIN LATERAL regexp_split_to_table(pg_read_file('log/' \|\| a.name), E'\n')` | Lee cada archivo y lo parte en líneas |
| `WITH ORDINALITY AS l(linea, num)` | Numera las líneas de cada archivo, como `num` en `dba.bitacora` |
| `regexp_replace(..., 'PASSWORD\s+''[^'']*''', ...)` | Tapa las contraseñas antes de que salgan del servidor |

Resultado, en la misma ejecución:

```text
             archivo              | num |         momento         |  usuario   |                                sentencia
----------------------------------+-----+-------------------------+------------+--------------------------------------------------------------------------
 postgresql-2026-10-29_103255.log |  33 | 2026-10-29 11:20:18.913 | postgres   | REVOKE UPDATE ON clientes FROM soporte_ana;
 postgresql-2026-10-29_103255.log |  34 | 2026-10-29 11:20:18.918 | postgres   | GRANT UPDATE ON clientes TO app_ventas;
 postgresql-2026-10-29_103255.log |  35 | 2026-10-29 11:20:18.920 | postgres   | ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);
 postgresql-2026-10-29_103255.log |  36 | 2026-10-29 11:20:25.157 | postgres   | DROP ROLE rol_temporal;
 postgresql-2026-10-29_103255.log |  41 | 2026-10-29 11:23:43.107 | postgres   | CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
 postgresql-2026-10-29_103255.log |  42 | 2026-10-29 11:23:43.114 | postgres   | DROP ROLE rol_temporal;
 postgresql-2026-10-29_103255.log |  51 | 2026-10-29 11:33:38.531 | postgres   | ALTER SYSTEM SET log_statement = 'mod';
 postgresql-2026-10-29_103255.log |  60 | 2026-10-29 11:39:36.188 | postgres   | ALTER SYSTEM SET log_statement = 'ddl';
 postgresql-2026-10-29_103255.log |  72 | 2026-10-29 11:49:31.350 | postgres   | ALTER USER app_ventas PASSWORD '<REDACTED>'
 postgresql-2026-10-29_103255.log |  80 | 2026-10-29 11:51:02.283 | postgres   | ALTER SYSTEM SET log_statement = 'mod';
 postgresql-2026-10-29_103255.log |  93 | 2026-10-29 11:58:50.116 | postgres   | ALTER USER soporte_ana PASSWORD '<REDACTED>'
 postgresql-2026-10-29_103255.log | 104 | 2026-10-29 11:59:26.271 | postgres   | DROP ROLE soporte_ana;
 postgresql-2026-10-29_103255.log | 113 | 2026-10-29 12:18:50.416 | postgres   | ALTER USER soporte_ana PASSWORD '<REDACTED>'
 postgresql-2026-10-29_103255.log | 114 | 2026-10-29 12:19:05.113 | postgres   | ALTER USER app_ventas PASSWORD '<REDACTED>'
 postgresql-2026-10-29_103255.log | 130 | 2026-10-29 12:49:41.837 | postgres   | CREATE SCHEMA auditoria;
 postgresql-2026-10-29_103255.log | 131 | 2026-10-29 12:49:41.846 | postgres   | REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;
 postgresql-2026-10-29_103255.log | 132 | 2026-10-29 12:49:41.850 | postgres   | CREATE TABLE auditoria.cambios_clientes (
 postgresql-2026-10-29_103255.log | 146 | 2026-10-29 12:57:57.628 | postgres   | CREATE OR REPLACE FUNCTION auditoria.registrar_cambio_cliente()
 postgresql-2026-10-29_103255.log | 169 | 2026-10-29 12:57:57.647 | postgres   | REVOKE ALL ON FUNCTION auditoria.registrar_cambio_cliente() FROM PUBLIC;
 postgresql-2026-10-29_103255.log | 170 | 2026-10-29 12:57:57.649 | postgres   | CREATE TRIGGER trg_auditoria_clientes
 postgresql-2026-10-31_094251.log |  39 | 2026-10-31 10:04:56.378 | app_ventas | ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes
 postgresql-2026-10-31_094251.log |  45 | 2026-10-31 10:05:15.746 | postgres   | ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes;
 postgresql-2026-10-31_094251.log |  47 | 2026-10-31 10:05:15.749 | postgres   | ALTER TABLE clientes ENABLE TRIGGER trg_auditoria_clientes;
 postgresql-2026-11-26_232127.log |   9 | 2026-11-26 23:25:32.766 | postgres   | CREATE SCHEMA gobierno;
 postgresql-2026-11-26_232127.log |  10 | 2026-11-26 23:25:32.776 | postgres   | REVOKE ALL ON SCHEMA gobierno FROM PUBLIC;
 postgresql-2026-11-26_232127.log |  11 | 2026-11-26 23:25:32.778 | postgres   | CREATE TABLE gobierno.solicitudes_cambio (
 postgresql-2026-11-26_232127.log |  26 | 2026-11-26 23:25:32.820 | postgres   | ALTER TABLE clientes ADD COLUMN canal_alta VARCHAR(20);
(27 rows)
```

La bitácora exportada [E5](E5-bitacora-postgresql.log) une los cuatro archivos en orden. Para encontrar una línea en E5 se suma al `num` el desplazamiento de su archivo: 0 para el del 29/10, 181 para el del 31/10 y 297 para el de hoy. Las líneas del LAB-01 coinciden así con las de su [bitácora exportada](../../laboratorio-01-bitacoras-auditoria/evidencias/bitacora-lab01.log). El archivo del 24/11 no tiene ninguna de estas sentencias: ese día solo hubo altas de clientes (A1) y comentarios (A3).

### 3. La conciliación

La columna «Resultado» sale de la línea siguiente de E5: si trae un `ERROR`, el cambio no se hizo.

| Línea de E5 | Momento | Usuario | Sentencia | Resultado | Folio | ¿Autorizado? | Hallazgo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 33 a 35 | 29/10 11:20:18 | `postgres` | `REVOKE UPDATE` a `soporte_ana`, `GRANT UPDATE` a `app_ventas` y columna `segmento` | Se hicieron | — | No | Ejercicio de la Actividad 6 del LAB-01. En producción serían cambios de permisos y estructura sin folio (H-03) |
| 36 | 29/10 11:20:25 | `postgres` | `DROP ROLE rol_temporal` | Falló (línea 37: el rol no existe) | — | No aplica | Ninguno: no cambió nada |
| 41 y 42 | 29/10 11:23:43 | `postgres` | Crea y borra `rol_temporal`, con contraseña | Se hicieron | — | No | Ejercicio del LAB-01. La contraseña quedó escrita en el archivo del servidor (H-05) |
| 51, 60 y 80 | 29/10 11:33:38 a 11:51:02 | `postgres` | `ALTER SYSTEM SET log_statement`: `mod`, `ddl` y otra vez `mod` | Se hicieron | — | No | Ejercicio del LAB-01, pero entre las 11:39:36 y las 11:51:02 la bitácora no registró modificaciones de datos: en ese hueco cambió el RFC del cliente 3 a `GAMA780912XYZ` sin rastro (H-04) |
| 72, 93, 113 y 114 | 29/10 11:49:31 a 12:19:05 | `postgres` | Cambia las contraseñas de `app_ventas` y `soporte_ana` | Se hicieron | — | No | Cambios de cuentas sin folio (H-03), y los resúmenes SCRAM quedaron en el archivo del servidor (H-05) |
| 104 | 29/10 11:59:26 | `postgres` | `DROP ROLE soporte_ana` | Falló (línea 105: hay objetos que dependen del rol) | — | No aplica | Intento de borrar una cuenta de persona sin folio. No cambió nada, pero se registra (H-03) |
| 130 a 170 | 29/10 12:49:41 a 12:57:57 | `postgres` | Crea el esquema `auditoria`, su tabla, la función y el disparador | Se hicieron | — | No | Preparación: es el montaje de la auditoría del dato, anterior a POL-06 |
| 220 | 31/10 10:04:56 | `app_ventas` | `DISABLE TRIGGER trg_auditoria_clientes` | Falló (línea 221: no es dueño de la tabla) | — | No | La cuenta de la aplicación intentó apagar la auditoría y, en la línea 218, borrarla. El control funcionó, pero el intento se investiga (H-02) |
| 226 y 228 | 31/10 10:05:15.746 y .749 | `postgres` | Apaga el disparador y lo vuelve a encender | Se hicieron | — | No | Entre las dos, la línea 227 cambia el RFC del cliente 3 a `GAMA780912GHI`, y la auditoría no lo tiene ([E4](E4-muestra-auditoria.txt) salta del evento 3 al 4). Cambio no autorizado (H-01) |
| 306 a 308 | 26/11 23:25:32 | `postgres` | Crea el esquema `gobierno` y la tabla de solicitudes | Se hicieron | — | No | Preparación: el registro no puede tener folio antes de existir. El Comité de cambios debe regularizarlo con un folio posterior (H-03) |
| 323 | 26/11 23:25:32.820 | `postgres` | `ALTER TABLE clientes ADD COLUMN canal_alta` | Se hizo | `CAM-2026-014` | Sí, dentro de la ventana | No se probó antes en pruebas, porque ese ambiente no existe (H-08) |

De 27 sentencias, solo una tiene folio. Las demás son de los LAB-01 y LAB-03 y se hicieron antes de que existiera POL-06 o el registro, pero no se borran ni se dan por buenas: quedan como hallazgos en el [expediente](../EXPEDIENTE.md).

### 4. Lo que la conciliación no puede ver

- **La vista `dba.bitacora`**: no aparece su creación, porque en la Actividad 2 del LAB-01 `log_statement` valía `none`. Es un hueco de evidencia.
- **El hueco del 29/10 de 11:39:36 a 11:51:02**, con `log_statement` en `ddl`.
- **Los `COMMENT ON` de la A3 de este laboratorio**: están en E5 (archivo del 24/11), pero el filtro de la guía no los incluye. Son documentación, no cambian datos ni permisos.
- **Lo que haga un superusuario con `SET log_statement = 'none'` en su sesión**, que no deja rastro ([LAB-01, evidencia 10](../../laboratorio-01-bitacoras-auditoria/evidencias/10-diseno-auditoria.md)).

## Preguntas

**1. ¿Qué cambios de la bitácora no tienen folio? Clasifícalos: ¿son de preparación del laboratorio o representan hallazgos?**

Todos menos el de la línea 323. Son preparación el montaje de la auditoría (líneas 130 a 170) y el del registro de cambios (306 a 308), porque crean el control mismo. Los demás serían hallazgos en producción, aunque aquí fueran ejercicios: los cambios de permisos, estructura y contraseñas sin folio (H-03), la baja del registro a `ddl` que dejó un hueco (H-04) y, sobre todo, el apagado del disparador de las líneas 226 a 228 (H-01). Los intentos fallidos (36, 104 y 220) no cambiaron nada, pero el de la 220 se investiga porque buscaba evadir la auditoría.

**2. La desactivación del disparador del LAB-01, ¿qué tan grave es como hallazgo? ¿Por qué? ¿Qué distingue la línea 163 de la 169?**

Es de severidad alta. El administrador apagó el único control que guarda los valores antes y después, cambió el RFC de María García, un dato fiscal, y lo volvió a encender en 3 milisegundos. La auditoría quedó sin ese cambio, y sin la bitácora no se sabría. Además, no tenía folio ni la aprobación de Auditoría interna que pide POL-06. En este servidor, las líneas que la guía numera 163 y 169 son la 220 y la 226 de E5. La 220 es de `app_ventas`, la cuenta de la aplicación, y falló porque no es dueña de la tabla: el control de privilegios funcionó. La 226 es de `postgres`, desde el socket local, y se hizo: contra el superusuario no hay control preventivo, solo la detección en la bitácora y la separación de funciones.

**3. ¿Qué limitación tiene esta conciliación si `log_statement` estuvo en `none` durante algún periodo?**

Que solo prueba los cambios que se registraron, no que no hubo otros. Lo que pasó con `none`, o con `ddl` en el caso de los datos, no deja ninguna línea, y la conciliación no puede distinguir un periodo sin cambios de un periodo sin registro. Por eso los huecos se declaran (sección 4) y las líneas `ALTER SYSTEM SET log_statement` se revisan primero: dicen en qué periodos la bitácora fue ciega. Aun así, un `SET` dentro de una sesión no deja ni esa línea.

**4. ¿Quién debería realizar la conciliación: el DBA que hizo los cambios u otra persona?**

Otra persona: Auditoría interna, como fija POL-06. El DBA ejecuta los cambios y custodia la bitácora, así que si él mismo se revisa, un cambio indebido suyo pasaría sin que nadie lo note. Es la separación de funciones de la Unidad I: quien hace no es quien verifica.

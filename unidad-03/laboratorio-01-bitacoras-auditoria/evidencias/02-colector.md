# Evidencia 02 — Colector y vista de la bitácora

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 2 (sección 8 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Script: [`sql/01-colector-y-vista.sql`](../sql/01-colector-y-vista.sql)
- Fecha: 29 de octubre de 2026

## Objetivo

Que PostgreSQL guarde su bitácora en un archivo propio, en lugar de dejarla en la salida del contenedor, y poder leerla con SQL desde la sesión de administrador.

## Pasos y resultados

### 1. Activar el colector

En la sesión de administrador:

```sql
ALTER SYSTEM SET logging_collector = on;
SELECT pg_reload_conf();
SELECT name, setting, pending_restart FROM pg_settings WHERE name = 'logging_collector';
```

```text
ALTER SYSTEM
 pg_reload_conf
----------------
 t
(1 row)

       name        | setting | pending_restart
-------------------+---------+-----------------
 logging_collector | off     | t
(1 row)
```

`ALTER SYSTEM` escribe el valor nuevo en `postgresql.auto.conf`, pero el parámetro sigue en `off`. `pending_restart = t` indica que el servidor ya leyó el cambio y que no lo aplicará hasta que se reinicie. La guía consulta `pending_restart` sin recargar antes, y así sale `f`, porque el servidor todavía no ha leído el archivo. Por eso se agregó `SELECT pg_reload_conf();`.

### 2. Reiniciar y comprobar

`logging_collector` solo cambia al reiniciar (Anexo A, tabla A.1). Se salió de `psql` con `\q` y, en PowerShell:

```powershell
docker restart dba-u3-pg
docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off
```

Ya en la sesión nueva:

```sql
SELECT name, setting, source FROM pg_settings WHERE name = 'logging_collector';
SELECT pg_current_logfile();
```

```text
       name        | setting |       source
-------------------+---------+--------------------
 logging_collector | on      | configuration file
(1 row)

          pg_current_logfile
--------------------------------------
 log/postgresql-2026-10-29_103255.log
(1 row)
```

El colector quedó encendido, y su valor ya no es el de fábrica: viene de un archivo de configuración, `postgresql.auto.conf`. La ruta es relativa al directorio de datos, así que el archivo completo es `/var/lib/postgresql/data/log/postgresql-2026-10-29_103255.log`. El nombre sigue el patrón de `log_filename` (evidencia 01) con la fecha y la hora del arranque, las 10:32:55.

### 3. El cambio visto desde Docker

La salida que guardó Docker entre las 10:32 y las 10:33, consultada desde PowerShell:

```powershell
docker logs --since 2026-10-29T10:32:00-07:00 --until 2026-10-29T10:33:00-07:00 dba-u3-pg
```

```text
2026-10-29 10:32:26.525 MST [1] LOG:  received SIGHUP, reloading configuration files
2026-10-29 10:32:26.526 MST [1] LOG:  parameter "logging_collector" cannot be changed without restarting the server
2026-10-29 10:32:26.526 MST [1] LOG:  configuration file "/var/lib/postgresql/data/postgresql.auto.conf" contains errors; unaffected changes were applied
2026-10-29 10:32:55.252 MST [1] LOG:  received fast shutdown request
2026-10-29 10:32:55.254 MST [1] LOG:  aborting any active transactions
2026-10-29 10:32:55.255 MST [1] LOG:  background worker "logical replication launcher" (PID 32) exited with exit code 1
2026-10-29 10:32:55.256 MST [27] LOG:  shutting down
2026-10-29 10:32:55.257 MST [27] LOG:  checkpoint starting: shutdown immediate
2026-10-29 10:32:55.263 MST [27] LOG:  checkpoint complete: wrote 0 buffers (0.0%); 0 WAL file(s) added, 0 removed, 0 recycled; write=0.001 s, sync=0.001 s, total=0.008 s; sync files=0, longest=0.000 s, average=0.000 s; distance=0 kB, estimate=132 kB; lsn=0/198A878, redo lsn=0/198A878
2026-10-29 10:32:55.266 MST [1] LOG:  database system is shut down

PostgreSQL Database directory appears to contain a database; Skipping initialization

2026-10-29 10:32:55.591 MST [1] LOG:  redirecting log output to logging collector process
2026-10-29 10:32:55.591 MST [1] HINT:  Future log output will appear in directory "log".
```

Se ven las tres partes del cambio:

- **10:32:26, la recarga.** El servidor avisa que `logging_collector` no puede cambiar sin reiniciar. Lo reporta como un error de `postgresql.auto.conf` aunque el archivo esté bien escrito: es su forma de decir que ese valor no se aplicó, y por eso `pending_restart` quedó en `t`.
- **10:32:55, el apagado.** La instancia anterior tenía el colector apagado, así que su apagado quedó en Docker y no en el archivo.
- **10:32:55.591, el arranque.** Lo primero que hace la instancia nueva es pasarle su salida al colector («Future log output will appear in directory "log"»). Desde ahí, la bitácora ya no llega a Docker.

### 4. Leer el archivo desde el motor

```sql
SELECT linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n') AS linea;
```

Resultado, sin la fila del encabezado:

```text
 2026-10-29 10:32:55.591 MST [1] LOG:  starting PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
 2026-10-29 10:32:55.592 MST [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
 2026-10-29 10:32:55.592 MST [1] LOG:  listening on IPv6 address "::", port 5432
 2026-10-29 10:32:55.596 MST [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
 2026-10-29 10:32:55.601 MST [30] LOG:  database system was shut down at 2026-10-29 10:32:55 MST
 2026-10-29 10:32:55.607 MST [1] LOG:  database system is ready to accept connections

(7 rows)
```

`pg_read_file` devuelve el archivo completo como un solo texto, y `regexp_split_to_table` lo parte en una fila por cada salto de línea (`E'\n'`). Salen siete filas para seis líneas porque el archivo termina en un salto de línea, y lo que queda después de él es una fila vacía. Son los mensajes del arranque: `[1]` es el proceso principal del servidor y `[30]` el que comprueba que la base se apagó en orden antes de abrirla. Lo anterior al reinicio no está aquí, sino en Docker (paso 3).

### 5. Vista `dba.bitacora`

```sql
CREATE SCHEMA dba;
REVOKE ALL ON SCHEMA dba FROM PUBLIC;
CREATE VIEW dba.bitacora AS
SELECT t.n AS num, t.linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n')
     WITH ORDINALITY AS t(linea, n)
WHERE t.linea <> '';
```

```text
CREATE SCHEMA
REVOKE
CREATE VIEW
```

La vista guarda la consulta del paso 4 con un nombre. `WITH ORDINALITY` numera las líneas (`num`), para ordenarlas y citarlas en el informe, y `WHERE t.linea <> ''` quita la fila vacía del final. Como `pg_current_logfile()` se evalúa en cada consulta, la vista siempre lee el archivo vigente. El esquema `dba` es solo del administrador: un esquema nuevo no da permisos a `PUBLIC`, y el `REVOKE` lo deja explícito.

### 6. Consultas sobre la vista

```sql
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 10;
SELECT linea FROM dba.bitacora WHERE linea ILIKE '%update%';
SELECT linea FROM dba.bitacora WHERE linea ~ '(FATAL|ERROR)';
```

Resultado de la primera, sin la fila del encabezado:

```text
   6 | 2026-10-29 10:32:55.607 MST [1] LOG:  database system is ready to accept connections
   5 | 2026-10-29 10:32:55.601 MST [30] LOG:  database system was shut down at 2026-10-29 10:32:55 MST
   4 | 2026-10-29 10:32:55.596 MST [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
   3 | 2026-10-29 10:32:55.592 MST [1] LOG:  listening on IPv6 address "::", port 5432
   2 | 2026-10-29 10:32:55.592 MST [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
   1 | 2026-10-29 10:32:55.591 MST [1] LOG:  starting PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
(6 rows)
```

Y de las dos búsquedas:

```text
 linea
-------
(0 rows)

 linea
-------
(0 rows)
```

La vista devuelve las seis líneas numeradas y sin la vacía, de la más reciente a la más antigua. La primera búsqueda no distingue mayúsculas (`ILIKE`) y la segunda usa una expresión regular (`~`). Las dos salen vacías: el servidor todavía no registra sentencias, y en el archivo no hay ningún error. Es el punto de partida de la Actividad 3.

## Límite de la vista

Solo lee el archivo vigente. El colector empieza uno nuevo en cada reinicio y cada vez que rota el archivo, que por defecto es cada día o cada 10 MB (`log_rotation_age` y `log_rotation_size`). Desde ese momento, la vista ya no ve las líneas anteriores. `SELECT * FROM pg_ls_logdir();` lista todos los archivos del directorio `log`.

## Análisis

**¿Por qué `logging_collector` requiere reinicio y `log_statement` solo recarga?** Porque se aplican en momentos distintos. El colector es un proceso aparte que el servidor crea al arrancar, y que recibe la salida de error de todos los demás. Esa salida se conecta al colector en el arranque, antes de crear los procesos que atienden las sesiones, y ellos la heredan. Con el servidor en marcha, todos sus procesos ya escriben en la salida que guarda Docker, y eso no se puede cambiar sin volver a arrancar; por eso el servidor respondió a la recarga con «cannot be changed without restarting the server» (paso 3). `log_statement`, en cambio, se revisa cada vez que una sesión ejecuta una sentencia, así que basta con que el servidor relea la configuración. Lo dice la columna `context` de `pg_settings`: `logging_collector` es `postmaster` (solo al arrancar) y `log_statement` es `superuser` (con una recarga, o un superusuario en su propia sesión con `SET`).

**¿Qué ventaja tiene que la bitácora se lea con SQL y no con una herramienta del sistema operativo o del contenedor? ¿Qué riesgo introduce?** La ventaja es que no hace falta entrar al sistema operativo. El archivo es del usuario del servicio y tiene permisos restringidos, pero el servidor lo lee por su cuenta, y la consulta es la misma en Docker, en Windows o en Linux. Además, buscar en la bitácora se vuelve una consulta: se filtra con `ILIKE` o con expresiones regulares, se ordena, se cuenta, y cada línea tiene un número para citarla.

El riesgo es que la bitácora queda al alcance de las cuentas de la base de datos, no solo de quien administra el equipo. Cuando se registren sentencias, el archivo tendrá los valores que se escribieron en ellas, como un RFC o hasta una contraseña (la guía lo muestra en la Actividad 6), y quien tenga acceso a la vista podrá leerlos sin entrar al equipo. Además, la vista depende de `pg_read_file`, que no se limita a la bitácora: la guía advierte que permite leer cualquier archivo que el proceso del servidor pueda leer, y por eso está reservada a los superusuarios.

**¿Quién debería poder consultar `dba.bitacora`?** Solo el administrador, o quien tenga a su cargo la auditoría; nunca las cuentas cuya actividad registra. Ni `app_ventas` ni `soporte_ana`: la bitácora junta lo que hacen todas las cuentas, con los datos que escriben, y es la evidencia para revisar lo que hicieron. Si la cuenta auditada puede leerla, sabe qué queda registrado y qué no. Es el privilegio mínimo de la Unidad II aplicado a la bitácora.

Hoy solo puede consultarla un superusuario, por dos candados: el esquema `dba` no da permisos a nadie más, y `pg_read_file` por defecto solo la ejecuta un superusuario. Si un auditor distinto del administrador necesitara leerla, no bastaría con darle permiso sobre el esquema y la vista. Las funciones de una vista se ejecutan con los permisos de quien la consulta, así que también necesitaría permiso para ejecutar `pg_read_file`, con el riesgo que se explicó arriba.

## Conclusión

El servidor ya guarda su bitácora en un archivo propio, dentro del directorio de datos, que está en el volumen `dba-u3-pg-data`. Ya no depende de lo que Docker conserve de la salida del contenedor, y se lee con una consulta desde la sesión de administrador. Por ahora el archivo solo tiene el arranque, porque el servidor todavía no registra conexiones ni sentencias; eso se configura en la Actividad 4.

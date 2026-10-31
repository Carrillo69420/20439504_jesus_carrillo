# Evidencia 09 — Sesiones activas con `pg_stat_activity`

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 9 (sección 15 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 29 de octubre de 2026

## Objetivo

Ver una sesión mientras está abierta, con `pg_stat_activity`, y relacionarla con lo que la bitácora registró de ella. Después, comprobar qué queda de esa sesión cuando termina.

## Pasos y resultados

### 1. Intentos previos

Antes de la corrida que se documenta en los pasos 2 a 5 hubo varios intentos que también quedaron en la bitácora:

| Hora | Líneas | Qué pasó |
| --- | --- | --- |
| 12:10:55 | 110 a 112 | El reporte no se conectó: `FATAL:  password authentication failed for user "soporte_ana"`. La contraseña tecleada no era la que se le asignó a `soporte_ana` en la Actividad 8. |
| 12:18:50 y 12:19:05 | 113 y 114 | Se asignaron de nuevo las contraseñas de `soporte_ana` y `app_ventas` con `\password`. Quedaron como `ALTER USER … PASSWORD 'SCRAM-SHA-256$<resumen>'`. |
| 12:19:20 a 12:20:50 | 115 a 118 | El reporte se conectó (PID 761) y duró 1 minuto 30 segundos, pero `pg_stat_activity` se consultó cuando ya había terminado y solo mostró la sesión del administrador. |
| 12:21:11 | 119 y 120 | Error de sintaxis en la búsqueda por PID: la variable `:reporte` no existía, porque el `\gset` del paso 3 no encontró el reporte, que ya había terminado. |

### 2. El reporte

En una segunda terminal se simuló un reporte largo como `soporte_ana`, con el nombre de aplicación `reporte-mensual`:

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://soporte_ana@127.0.0.1/comercial?application_name=reporte-mensual" -c "SELECT pg_sleep(90)"
```

```text
Password:
 pg_sleep
----------

(1 row)
```

`pg_sleep(90)` espera 90 segundos sin hacer nada, así que la sesión queda abierta y ocupada ese tiempo. Como en las evidencias 07 y 08, la contraseña se pidió con `-W` en lugar de ir escrita en la cadena de conexión, como en la guía.

### 3. La sesión, mientras el reporte corre

En la sesión de administrador:

```sql
SELECT pid, usename, application_name, client_addr, backend_start, state, left(query, 30) AS query
FROM pg_stat_activity
WHERE backend_type = 'client backend';
SELECT pid AS reporte FROM pg_stat_activity WHERE application_name = 'reporte-mensual' \gset
```

```text
 pid |   usename   | application_name | client_addr |         backend_start         | state  |             query
-----+-------------+------------------+-------------+-------------------------------+--------+--------------------------------
 619 | postgres    | psql             |             | 2026-10-29 11:59:22.460433-07 | active | SELECT pid, usename, applicati
 843 | soporte_ana | reporte-mensual  | 127.0.0.1   | 2026-10-29 12:32:23.190883-07 | active | SELECT pg_sleep(90)
(2 rows)
```

- `pg_stat_activity` tiene una fila por cada proceso vivo del servidor. `backend_type = 'client backend'` deja solo las sesiones de clientes, sin los procesos internos del servidor, como el checkpointer.
- La fila 843 es el reporte: `soporte_ana`, desde `127.0.0.1`, con `reporte-mensual`, ejecutando `SELECT pg_sleep(90)` (`active`).
- La fila 619 es la sesión de administrador. También sale `active`, porque en ese momento está ejecutando esta misma consulta.
- La guía muestra las horas en UTC (`+00`). Aquí salen en la hora del Pacífico (`-07`), por el `TZ=America/Mazatlan` del contenedor.
- `\gset` guarda el resultado de la segunda consulta en la variable `reporte` de psql (aquí, 843). La guía pide escribir el PID a mano en la búsqueda (`LIKE '%[189]%'`); con la variable se hace lo mismo sin copiarlo.
- En la terminal que se usó, un bloque pegado llega completo como una sola línea, y un comando con `\` toma como argumentos todo lo que sigue en esa línea. Por eso `\gset` va al final de su bloque y la búsqueda del paso 4 se pegó aparte.

### 4. La misma sesión en la bitácora

```sql
SELECT linea FROM dba.bitacora WHERE linea LIKE '%[' || :reporte || ']%' ORDER BY num;
```

psql reemplaza `:reporte` por 843, así que la condición queda `LIKE '%[843]%'`: la consulta de la guía con el PID de esta corrida.

Resultado, sin la fila del encabezado:

```text
 2026-10-29 12:32:23.191 MST [843] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=35000
 2026-10-29 12:32:23.207 MST [843] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="soporte_ana" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
 2026-10-29 12:32:23.207 MST [843] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=soporte_ana database=comercial application_name=reporte-mensual
(3 rows)
```

- El `[843]` del prefijo es el `%p` de `log_line_prefix`, el mismo número que la columna `pid` de `pg_stat_activity`.
- La hora de `connection received` (12:32:23.191) coincide con el `backend_start` de la vista (12:32:23.190883): el proceso empieza a existir al recibir la conexión.
- En las tres líneas el prefijo dice `app=[unknown]`, porque cuando se escriben la sesión todavía no tiene asignado el nombre de la aplicación. La línea `connection authorized` sí lo trae en el mensaje: `application_name=reporte-mensual`.
- No aparece `SELECT pg_sleep(90)`: con `log_statement = 'mod'` los SELECT no se registran ([evidencia 07](07-modificaciones.md)).

### 5. Cuando el reporte terminó

Se repitieron las dos consultas después de que el reporte terminó. `pg_stat_activity`:

```text
 pid | usename  | application_name | client_addr |         backend_start         | state  |             query
-----+----------+------------------+-------------+-------------------------------+--------+--------------------------------
 619 | postgres | psql             |             | 2026-10-29 11:59:22.460433-07 | active | SELECT pid, usename, applicati
(1 row)
```

La búsqueda en la bitácora, sin la fila del encabezado:

```text
 2026-10-29 12:32:23.191 MST [843] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=35000
 2026-10-29 12:32:23.207 MST [843] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="soporte_ana" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
 2026-10-29 12:32:23.207 MST [843] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=soporte_ana database=comercial application_name=reporte-mensual
 2026-10-29 12:33:53.255 MST [843] user=soporte_ana db=comercial app=reporte-mensual client=127.0.0.1 LOG:  disconnection: session time: 0:01:30.064 user=soporte_ana database=comercial host=127.0.0.1 port=35000
(4 rows)
```

- La fila 843 desapareció de `pg_stat_activity`: la vista solo muestra lo que existe en ese momento.
- La bitácora conserva las tres líneas de antes y agrega la desconexión, con la duración de la sesión: 1 minuto 30 segundos, lo que tardó `pg_sleep(90)`. La guía solo pide repetir la consulta a `pg_stat_activity`; la búsqueda se repitió para ver esta cuarta línea.
- En la desconexión, el prefijo ya dice `app=reporte-mensual`.

## Análisis

**¿Qué columna permite relacionar una sesión con sus líneas de bitácora?**

`pid`. Es el número del proceso del servidor que atiende la sesión, y es el mismo que la bitácora escribe entre corchetes en cada línea (`%p` en `log_line_prefix`). La fila 843 de `pg_stat_activity` corresponde a las líneas `[843]`, y la 619, la del administrador, a las líneas `[619]` (102 a 107, 113, 114, 119 y 120). `backend_start` sirve para confirmarlo, porque coincide con la hora de `connection received`. El sistema vuelve a usar los números de proceso con el tiempo, así que en una bitácora larga conviene buscar el PID junto con la fecha y la hora.

**Después de que termina el reporte, ¿qué fuente conserva evidencia de que existió?**

La bitácora. `pg_stat_activity` es una foto del presente: cuando la sesión se cierra, su fila desaparece sin dejar nada. La bitácora conserva quién se conectó (`soporte_ana`), desde dónde (`127.0.0.1`), con qué aplicación (`reporte-mensual`), cuándo entró (12:32:23) y cuánto duró (1:30.064). Lo mismo pasó con el primer reporte que sí se conectó (PID 761, líneas 115 a 118): `pg_stat_activity` se consultó cuando ya había terminado y no lo mostró, pero la bitácora lo tiene completo.

Las dos fuentes se complementan. Mientras la sesión vive, `pg_stat_activity` muestra lo que está ejecutando (`SELECT pg_sleep(90)`), y eso no queda en la bitácora con `log_statement = 'mod'`. La bitácora no dice qué consultó el reporte, pero es lo único que demuestra después que existió.

**¿Por qué `client_addr` aparece vacío en la sesión del administrador?**

Porque esa sesión no entró por la red. `docker exec -it dba-u3-pg psql -U postgres -d comercial` se conecta por el socket local, dentro del contenedor, y una conexión por socket no tiene dirección IP, así que `pg_stat_activity` deja `client_addr` vacío. En la bitácora, esa misma sesión aparece como `client=[local]`. Además entra por la regla `local` de `pg_hba.conf`, que está en `trust`. Por eso sus líneas de conexión (102 y 103) no tienen un `connection authenticated`, a diferencia del reporte, que tuvo que demostrar su contraseña con `scram-sha-256`.

## Conclusión

`pg_stat_activity` muestra quién está conectado y qué está haciendo en este momento, pero no guarda nada: cuando una sesión termina, desaparece de la vista. La bitácora registra la misma sesión con el mismo PID y la conserva después, con su hora de entrada, su duración, su usuario, su IP y su aplicación. La vista sirve para vigilar lo que pasa ahora, y la bitácora para demostrar después lo que pasó.

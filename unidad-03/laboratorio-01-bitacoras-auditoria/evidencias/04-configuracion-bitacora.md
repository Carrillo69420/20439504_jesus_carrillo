# Evidencia 04 — Configuración de la bitácora

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 4 (sección 10 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Script: [`sql/02-configuracion-bitacora.sql`](../sql/02-configuracion-bitacora.sql)
- Fecha: 29 de octubre de 2026

## Objetivo

Que la bitácora registre las conexiones, las desconexiones y los cambios de estructura, y que cada línea diga quién la generó, sin reiniciar el servidor.

## Pasos y resultados

### 1. Los cambios

En la sesión de administrador:

```sql
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();
```

```text
ALTER SYSTEM
ALTER SYSTEM
ALTER SYSTEM
ALTER SYSTEM
 pg_reload_conf
----------------
 t
(1 row)
```

| Parámetro | Valor | Qué agrega a la bitácora |
| --- | --- | --- |
| `log_connections` | `on` | Cada conexión que llega y cada una que se autoriza |
| `log_disconnections` | `on` | Cada sesión que termina, con su duración |
| `log_line_prefix` | `%m [%p] user=%u db=%d app=%a client=%h ` | Antes de cada mensaje: hora, proceso, usuario, base, aplicación y cliente |
| `log_statement` | `ddl` | Las sentencias que cambian la estructura, como CREATE, ALTER y DROP |

Los cuatro se aplican con una recarga, sin reiniciar. El prefijo termina con un espacio, para que no quede pegado al mensaje.

### 2. Verificación en la misma sesión

```sql
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections', 'log_line_prefix', 'log_statement');
```

```text
      name       |                 setting                 |       source       |                  sourcefile
-----------------+-----------------------------------------+--------------------+-----------------------------------------------
 log_connections | off                                     | default            |
 log_line_prefix | %m [%p] user=%u db=%d app=%a client=%h  | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
 log_statement   | ddl                                     | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
(3 rows)
```

La consulta se envió aparte, después de la recarga, porque `pg_reload_conf()` solo envía una señal y regresa de inmediato. `log_line_prefix` y `log_statement` ya tienen los valores nuevos, tomados de `postgresql.auto.conf`. `log_connections` sigue en `off`, y no es un error: se fija al abrir cada sesión, y una recarga solo lo cambia para las sesiones que se abren después. Esta sesión se abrió antes. Por eso la guía, que verificó desde una sesión nueva, muestra `on`.

### 3. Verificación en una sesión nueva

Se salió con `\q` y se volvió a entrar desde PowerShell:

```powershell
docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off
```

```sql
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections', 'log_line_prefix', 'log_statement');
```

```text
      name       |                 setting                 |       source       |                  sourcefile
-----------------+-----------------------------------------+--------------------+-----------------------------------------------
 log_connections | on                                      | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
 log_line_prefix | %m [%p] user=%u db=%d app=%a client=%h  | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
 log_statement   | ddl                                     | configuration file | /var/lib/postgresql/data/postgresql.auto.conf
(3 rows)
```

En la sesión nueva, los tres valores vienen de `postgresql.auto.conf`, como en la guía.

### 4. Las últimas líneas de la bitácora

```sql
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 7;
```

La guía usa `LIMIT 6`; con 7 entra también la línea de la recarga. Resultado, sin la fila del encabezado:

```text
  17 | 2026-10-29 10:53:35.341 MST [131] user=postgres db=comercial app=[unknown] client=[local] LOG:  connection authorized: user=postgres database=comercial application_name=psql
  16 | 2026-10-29 10:53:35.341 MST [131] user=[unknown] db=[unknown] app=[unknown] client=[local] LOG:  connection received: host=[local]
  15 | 2026-10-29 10:53:23.997 MST [1] user= db= app= client= LOG:  parameter "log_statement" changed to "ddl"
  14 | 2026-10-29 10:53:23.997 MST [1] user= db= app= client= LOG:  parameter "log_line_prefix" changed to "%m [%p] user=%u db=%d app=%a client=%h "
  13 | 2026-10-29 10:53:23.997 MST [1] LOG:  parameter "log_disconnections" changed to "on"
  12 | 2026-10-29 10:53:23.997 MST [1] LOG:  parameter "log_connections" changed to "on"
  11 | 2026-10-29 10:53:23.996 MST [1] LOG:  received SIGHUP, reloading configuration files
(7 rows)
```

- **Línea 11.** El proceso principal (`[1]`) recibe la señal de la recarga.
- **Líneas 12 a 15.** El mismo proceso deja una línea por cada parámetro que cambió. Es el registro de un cambio de configuración (contenido 3.2.7). Las dos primeras llevan el prefijo viejo. Desde la 14 se usa el nuevo, que se aplica en cuanto cambia: la línea que lo anuncia ya lo trae. Usuario, base, aplicación y cliente salen vacíos porque esas líneas no vienen de ninguna sesión.
- **Las sentencias `ALTER SYSTEM` no aparecen,** porque cuando se ejecutaron `log_statement` todavía valía `none`.
- **Líneas 16 y 17.** La sesión nueva del administrador ya queda registrada: usuario `postgres`, base `comercial`, por el socket (`client=[local]`). En la 16 el usuario y la base salen `[unknown]` porque la conexión apenas llegó. Quien entra a consultar la bitácora también deja rastro, aunque la consulta en sí no, porque un SELECT no es una sentencia de estructura.
- **La desconexión de la sesión anterior no aparece,** porque esa sesión empezó con `log_disconnections` apagado.
- **Las líneas 9 y 10,** fuera del `LIMIT 7`, son otro checkpoint, de las 10:52:55. Probablemente lo provocó el UPDATE de la Actividad 3, que fue el único cambio de datos desde el checkpoint anterior. No dicen qué cambió ni quién.

## Análisis

**¿Por qué el proceso que registra el cambio es el principal y no tu sesión?** Porque la sesión no aplica la configuración. `ALTER SYSTEM` solo escribe el valor en `postgresql.auto.conf`, y `pg_reload_conf()` solo le manda una señal (SIGHUP) al proceso principal, el `[1]`. Ese proceso es el que relee los archivos de configuración, aplica los cambios y deja una línea por cada uno. Después les pasa el aviso a los demás procesos. Por eso esas líneas tienen vacíos el usuario, la base, la aplicación y el cliente: no las escribe ninguna sesión. Y por lo mismo dicen qué cambió y cuándo, pero no quién lo pidió. Para saberlo hace falta la línea de la sentencia `ALTER SYSTEM`, que aquí no quedó porque `log_statement` todavía valía `none`.

**¿Qué pasaría si alguien ejecutara `ALTER SYSTEM SET log_statement = 'none'`? ¿Quedaría rastro?** Sí, pero sería el último. Con `log_statement = 'ddl'`, `ALTER SYSTEM` cuenta como sentencia de estructura, así que quedaría registrada con el prefijo nuevo: quién la ejecutó, en qué base, con qué aplicación y desde dónde. Al recargar, el proceso principal agregaría `parameter "log_statement" changed to "none"`. Desde ahí ya no se registraría ninguna sentencia, ni siquiera la que devolviera el valor a `ddl`; solo quedaría la línea del proceso principal cuando el valor volviera a cambiar.

Hay un caso peor. Un superusuario puede ejecutar `SET log_statement = 'none'` solo para su sesión. `SET` no es una sentencia de estructura, así que no se registra, y lo que haga esa sesión después tampoco: solo quedarían su conexión y su desconexión. La bitácora del servidor no alcanza para vigilar a un superusuario.

**¿Por qué no se recomienda editar `postgresql.auto.conf` a mano?** Porque ese archivo lo administra el propio servidor. Empieza con el aviso «Do not edit this file manually!», y cada `ALTER SYSTEM` lo vuelve a escribir completo, así que lo que se le agregue a mano, como un comentario, desaparece. Además, `ALTER SYSTEM` revisa el valor antes de guardarlo: con un valor inválido responde `invalid value for parameter` y no toca el archivo. En cambio, un error escrito a mano no se detecta hasta que el servidor relee el archivo.

Para la auditoría hay una razón más. Un cambio a mano se hace desde el sistema operativo, sin sesión ni sentencia. En la bitácora solo quedaría la línea del proceso principal al recargar (`parameter ... changed to ...`), sin decir quién hizo el cambio. Con `ALTER SYSTEM`, y `log_statement` en `ddl` o más, la sentencia queda registrada con el usuario que la ejecutó.

## Conclusión

La bitácora ya registra quién se conecta, a qué base, con qué aplicación y desde dónde, y los cambios de estructura con su autor. También registra sus propios cambios de configuración. Lo que todavía no registra son los cambios de datos: del UPDATE de la Actividad 3 solo quedarían la conexión y la desconexión de `app_ventas`, no la sentencia, porque `ddl` no incluye las sentencias que modifican datos. Eso se revisa en la Actividad 7.

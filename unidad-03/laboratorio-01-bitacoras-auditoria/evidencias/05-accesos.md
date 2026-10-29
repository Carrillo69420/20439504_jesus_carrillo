# Evidencia 05 — Accesos exitosos y fallidos

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 5 (sección 11 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 29 de octubre de 2026

## Objetivo

Provocar dos accesos fallidos por red, uno con una contraseña equivocada y otro con un usuario que no existe, y un acceso exitoso, y leer lo que cada uno dejó en la bitácora configurada en la Actividad 4.

## Pasos y resultados

### 1. Los tres intentos

En PowerShell:

```powershell
docker exec dba-u3-pg psql "postgresql://app_ventas:incorrecta@127.0.0.1/comercial" -c "SELECT 1"
docker exec dba-u3-pg psql "postgresql://usuario_inexistente:x@127.0.0.1/comercial" -c "SELECT 1"
docker exec -it dba-u3-pg psql "postgresql://app_ventas@127.0.0.1/comercial?application_name=app-ventas-web" -c "SELECT count(*) FROM clientes"
```

```text
psql: error: connection to server at "127.0.0.1", port 5432 failed: FATAL:  password authentication failed for user "app_ventas"
psql: error: connection to server at "127.0.0.1", port 5432 failed: FATAL:  password authentication failed for user "usuario_inexistente"
Password for user app_ventas:
 count
-------
     5
(1 row)
```

En los dos primeros intentos, la contraseña va en la URI porque es falsa a propósito (`incorrecta` y `x`). En el tercero, a diferencia del comando de la guía, no va escrita: `psql` la pidió. El cliente recibe el mismo mensaje en los dos fallos, aunque en el segundo el usuario no existe.

### 2. Lo que quedó en la bitácora

En la sesión de administrador, primero con el filtro de la guía:

```sql
SELECT linea FROM dba.bitacora WHERE linea LIKE '%client=127.0.0.1%' ORDER BY num;
```

Devolvió 11 filas. Después se corrió la misma consulta con el número de línea y con las líneas que empiezan con un tabulador (el paso 3 explica por qué):

```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%client=127.0.0.1%' OR linea LIKE E'\t%' ORDER BY num;
```

Resultado, sin la fila del encabezado. Son las mismas 11 líneas más la 25:

```text
  19 | 2026-10-29 11:00:33.433 MST [166] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=41218
  20 | 2026-10-29 11:00:33.439 MST [166] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 FATAL:  password authentication failed for user "app_ventas"
  21 | 2026-10-29 11:00:33.439 MST [166] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 DETAIL:  Connection matched file "/var/lib/postgresql/data/pg_hba.conf" line 119: "host    all             all             127.0.0.1/32            scram-sha-256"
  22 | 2026-10-29 11:00:38.187 MST [173] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=41230
  23 | 2026-10-29 11:00:38.191 MST [173] user=usuario_inexistente db=comercial app=[unknown] client=127.0.0.1 FATAL:  password authentication failed for user "usuario_inexistente"
  24 | 2026-10-29 11:00:38.191 MST [173] user=usuario_inexistente db=comercial app=[unknown] client=127.0.0.1 DETAIL:  Role "usuario_inexistente" does not exist.
  25 |         Connection matched file "/var/lib/postgresql/data/pg_hba.conf" line 119: "host    all             all             127.0.0.1/32            scram-sha-256"
  26 | 2026-10-29 11:00:42.430 MST [180] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=41240
  27 | 2026-10-29 11:00:57.740 MST [182] user=[unknown] db=[unknown] app=[unknown] client=127.0.0.1 LOG:  connection received: host=127.0.0.1 port=38866
  28 | 2026-10-29 11:00:57.745 MST [182] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="app_ventas" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
  29 | 2026-10-29 11:00:57.745 MST [182] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=app_ventas database=comercial application_name=app-ventas-web
  30 | 2026-10-29 11:00:57.757 MST [182] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.017 user=app_ventas database=comercial host=127.0.0.1 port=38866
(12 rows)
```

| Líneas | Proceso | Qué pasó |
| --- | --- | --- |
| 19 a 21 | 166 | Contraseña equivocada. Llega la conexión, falla la autenticación y el `DETAIL` dice qué regla de `pg_hba.conf` la atendió: la 119, que exige `scram-sha-256`. |
| 22 a 25 | 173 | Usuario que no existe. Sale el mismo `FATAL`, pero el `DETAIL` dice que el rol no existe, y la línea 25 lo continúa con la regla 119. |
| 26 | 180 | Solo llega una conexión. Es el primer intento de `psql`, sin contraseña. |
| 27 a 30 | 182 | Acceso exitoso. La conexión llega, se autentica con `scram-sha-256`, se autoriza y se cierra 17 milisegundos después. |

**La línea 26.** La guía muestra 10 líneas, y con su filtro aquí salieron 11. La de más es la 26. Como la contraseña no venía en el comando, `psql` primero intentó conectarse sin ella. El servidor se la pidió, `psql` cerró esa conexión, le pidió la contraseña al usuario y se volvió a conectar (línea 27). Entre las dos hay unos 15 segundos, lo que se tardó en escribirla. El servidor no registra un fallo cuando el cliente se va sin mandar contraseña, así que de ese primer intento solo queda el `connection received`. En la guía no aparece porque la contraseña iba en la URI. Con la opción `-W`, `psql` pide la contraseña antes de conectarse, y esa línea ya no aparece.

### 3. La línea que el filtro no muestra

La línea 25 no tiene prefijo: empieza con un tabulador (`psql` lo muestra como espacios) y no dice hora, proceso, usuario ni cliente. Es la continuación del `DETAIL` de la línea 24. Cuando un mensaje trae más de una línea, la bitácora pone el prefijo solo en la primera. Por eso el filtro de la guía, que busca `client=127.0.0.1`, la deja fuera, y tampoco aparece en el resultado de la guía.

Filtrar por un campo del prefijo da un resultado que parece completo y no lo es. `OR linea LIKE E'\t%'` agrega las continuaciones (`E'\t'` es un tabulador escrito en SQL). Como no dicen de qué sesión son, la consulta trae las de todas las sesiones, y el número de línea indica a cuál pertenece cada una: a la de arriba.

### 4. Una línea, campo por campo (sección 11.1)

La línea 20, con la regla que trae su `DETAIL` (línea 21):

| Campo | Valor | Significado |
| --- | --- | --- |
| Fecha y hora | `2026-10-29 11:00:33.439 MST` | Cuándo escribió el servidor la línea, con milisegundos y en su zona horaria (MST, UTC−7) |
| PID | `166` | El proceso del servidor que atendió esta conexión. Cada conexión tiene el suyo, así que el PID une las líneas del mismo intento (19, 20 y 21). Los PID se reutilizan con el tiempo: una sesión se identifica por su PID y su hora |
| Usuario | `app_ventas` | El usuario con el que el cliente pidió entrar. La autenticación falló, así que nadie comprobó que lo fuera |
| Base de datos | `comercial` | La base a la que pidió entrar |
| Aplicación | `[unknown]` | El intento no llegó al punto en que el servidor aplica el nombre de la aplicación |
| Cliente | `127.0.0.1` | La dirección desde la que llegó la conexión. Aquí es el propio contenedor, porque `psql` corre dentro con `docker exec` |
| Severidad | `FATAL` | Un error que terminó la conexión. `LOG` es informativo, y `DETAIL` no es otra severidad: es el detalle del mismo mensaje, en su propia línea |
| Mensaje | `password authentication failed for user "app_ventas"` | La contraseña no coincidió. Es el mismo mensaje que sale cuando el usuario no existe |
| Regla aplicada | `pg_hba.conf`, línea 119 | La regla que atendió la conexión (`host all all 127.0.0.1/32 scram-sha-256`) y, con ella, el método que se exigió |

### 5. La consulta para contar los intentos fallidos

```sql
SELECT substring(linea FROM 'failed for user "([^"]*)"') AS usuario,
       count(*) AS intentos_fallidos,
       min(left(linea, 23)) AS primero,
       max(left(linea, 23)) AS ultimo
FROM dba.bitacora
WHERE linea LIKE '%FATAL:  password authentication failed%'
GROUP BY usuario
ORDER BY intentos_fallidos DESC;
```

```text
       usuario       | intentos_fallidos |         primero         |         ultimo
---------------------+-------------------+-------------------------+-------------------------
 app_ventas          |                 1 | 2026-10-29 11:00:33.439 | 2026-10-29 11:00:33.439
 usuario_inexistente |                 1 | 2026-10-29 11:00:38.191 | 2026-10-29 11:00:38.191
(2 rows)
```

- `substring(linea FROM '...')` saca de cada línea lo que está entre paréntesis en el patrón: el usuario que va entre comillas.
- `left(linea, 23)` toma la fecha y la hora. `min` y `max` funcionan con texto porque la fecha empieza por el año, así que el orden alfabético es el cronológico.
- El `WHERE` lleva dos espacios después de `FATAL:`, como los escribe la bitácora.
- Se cuentan las líneas `FATAL` y no las `connection received`, porque una conexión que llega no siempre es un intento fallido, como la de la línea 26.

## Análisis

**La bitácora registra el usuario `app_ventas` en el intento fallido. ¿Eso prueba que la aplicación de ventas intentó entrar? ¿Qué prueba realmente?** No. `user=app_ventas` es el nombre que el cliente puso en su solicitud de conexión, y como la contraseña no coincidió, el servidor nunca comprobó que fuera cierto. Cualquiera que llegue al servidor puede pedir entrar con el nombre que quiera. En este caso no fue la aplicación de ventas, sino el administrador con `psql`, dentro del contenedor. La línea tampoco dice qué aplicación fue (`app=[unknown]`), y aunque lo dijera, ese nombre también lo pone el cliente: en el acceso exitoso se escribió a mano en la URI.

Lo que sí prueba es que a las 11:00:33.439 llegó una conexión desde 127.0.0.1, puerto 41218, que pidió entrar a `comercial` como `app_ventas`, que la atendió la regla 119 de `pg_hba.conf` y que la contraseña no coincidió. Es decir, alguien intentó entrar con esa cuenta y no pudo. Por la dirección, el intento salió del mismo servidor, en este caso del contenedor, y no de otro equipo.

Incluso el acceso exitoso prueba menos de lo que parece. La línea 28 (`connection authenticated: identity="app_ventas" method=scram-sha-256`) demuestra que quien se conectó conocía la contraseña de `app_ventas`, no que fuera la aplicación. Es el mismo límite de la Actividad 3: si alguien más conoce la contraseña de la aplicación, en la bitácora aparece como la aplicación.

**¿Qué información adicional registra PostgreSQL cuando el rol no existe? ¿Por qué aparece en la bitácora y no en el mensaje que recibe el cliente?** Registra el `DETAIL` `Role "usuario_inexistente" does not exist.` (línea 24), seguido de la regla que se aplicó (línea 25). Con la contraseña equivocada, el `DETAIL` solo trae la regla (línea 21). Con eso, el administrador distingue un intento con una contraseña equivocada de uno con un usuario que no existe.

El cliente recibe el mismo mensaje en los dos casos para no revelarle qué usuarios existen. Si la respuesta dijera que el rol no existe, un atacante podría probar nombres hasta encontrar los reales y después concentrarse en adivinar sus contraseñas. Por eso el detalle solo va a la bitácora, que lee el administrador. Y no es solo el mensaje: el servidor le pide la contraseña también a un usuario que no existe, como si existiera. Si alguien se conecta como `usuario_inexistente` sin contraseña y sin dejar que `psql` la pregunte (`psql -w`), la respuesta es `fe_sendauth: no password supplied`, igual que con un usuario real.

**¿Por qué `app=[unknown]` en el intento fallido, pero `app=app-ventas-web` en la desconexión?** El cliente manda el nombre de la aplicación con su solicitud de conexión, pero el servidor solo lo aplica a la sesión después de autenticarla y autorizarla. El intento fallido terminó en la autenticación, así que nunca llegó a ese punto y su prefijo se quedó en `[unknown]`. En la sesión exitosa pasa lo mismo al principio: las líneas 27 a 29 tienen `app=[unknown]`, aunque el mensaje de la 29 ya trae `application_name=app-ventas-web`. Desde ese momento la sesión tiene nombre, y la desconexión (línea 30) lo lleva en el prefijo.

Para la auditoría, esto significa que de un intento fallido no queda la aplicación, ni en el prefijo ni en el mensaje. Y en uno exitoso, el nombre lo declara el cliente, así que sirve para ordenar la bitácora, no para probar qué programa se conectó.

**¿Qué patrón de varias líneas te haría sospechar de un ataque de fuerza bruta? Escribe la consulta que contaría los intentos fallidos por usuario.**

- Muchos `FATAL:  password authentication failed` seguidos, en poco tiempo, cada uno con su `connection received` desde el mismo cliente y con procesos y puertos distintos. Si el usuario es siempre el mismo, alguien está probando contraseñas para esa cuenta.
- Si el usuario cambia y muchos `DETAIL` dicen `Role "..." does not exist.`, alguien está probando nombres de usuario.
- Lo más grave: una serie de fallos seguida de un `connection authenticated` desde el mismo cliente. Puede significar que el ataque funcionó.

La consulta es la del paso 5. Aquí dio un intento por usuario, así que no hay ningún patrón: un solo fallo puede ser un error al escribir la contraseña. Para usarla como alerta se le agrega un umbral antes del `ORDER BY`, por ejemplo `HAVING count(*) >= 5`, y solo salen los usuarios con cinco o más intentos fallidos. Tiene dos límites. Agrupa por usuario, así que un ataque que pruebe pocas contraseñas contra muchos usuarios no destaca; para verlo habría que agrupar también por cliente. Y solo cuenta lo que hay en el archivo vigente de la bitácora (ver el límite de la vista en la evidencia 02).

## Conclusión

La bitácora ya distingue los accesos exitosos de los fallidos y, en los fallidos, dice qué regla se aplicó y si el usuario existía, aunque al cliente no se lo diga. Pero el usuario de un intento fallido es solo el nombre que dio el cliente, y el nombre de la aplicación también lo declara el cliente. La única identidad comprobada es la de `connection authenticated`, y aun esa prueba que se conocía la contraseña, no quién la usó. Además, un filtro por un campo del prefijo deja fuera las líneas de continuación, así que una consulta a la bitácora puede parecer completa sin serlo.

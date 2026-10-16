# Evidencia 04 — Protección de datos en tránsito con TLS

LAB-02, Actividades 4, 5 y 6 (secciones 10 a 13 de la guía). Las consultas de la Actividad 5 están en `sql/03-verificacion-tls.sql`.

## Objetivo

Comprobar si la información viaja cifrada con TLS entre el cliente y PostgreSQL. Para eso se revisa la configuración del servidor y la sesión actual en el servidor de la FIC (Actividad 5), y se compara cómo se conecta psql con cada `sslmode` cuando el servidor tiene TLS apagado y cuando lo tiene encendido (Actividad 6 y sección 13).

## Comando o procedimiento

**Servidor de la FIC (Actividad 5).** El 15/10/2026 se entró a `pgadmin.ficlabs.com.mx` con la cuenta del alumno. Primero se revisó en Properties del servidor `db_a_carrillo` la configuración de conexión que usa pgAdmin (pestañas Connection y Parameters). Después, en el Query Tool de la base `db_20439504_jesus_carrillo`, se ejecutaron una por una las consultas del script, para ver el resultado de cada una por separado:

```sql
SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

SHOW ssl;
SHOW ssl_min_protocol_version;
SHOW port;
SHOW listen_addresses;

SELECT
    inet_client_addr(),
    inet_client_port();

SELECT
    ssl,
    version,
    cipher
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();
```

**¿Hay acceso con psql al servidor de la FIC? (Actividad 6).** La guía pide la conexión con psql «si tienes acceso a psql». El pgAdmin de la FIC no ofrece el PSQL Tool: en la barra lateral, además del explorador de objetos, solo aparecen los espacios de Query Tool y Schema Diff, y la documentación de pgAdmin indica que esa herramienta viene desactivada por omisión cuando pgAdmin funciona como servidor web. Por eso se probó si la PC llega al host que usa pgAdmin:

```powershell
ping -n 1 postgres-server
```

**Docker local con TLS apagado (Actividad 6).** El 16/10/2026, a las 10:33, se hizo la conexión de la sección 12 contra el contenedor `dba-practica`, primero exigiendo TLS y luego con el mismo modo que usa pgAdmin:

```powershell
docker exec dba-practica psql "host=localhost port=5432 dbname=comercializadora user=postgres sslmode=require" -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
docker exec dba-practica psql "host=localhost port=5432 dbname=comercializadora user=postgres sslmode=prefer" -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
```

**Docker local con TLS encendido (Actividad 6 y sección 13).** Para tener una conexión que sí use TLS, a las 10:37 se creó un contenedor desechable, `dba-tls`, con `ssl=on` y el certificado de prueba que trae la imagen de PostgreSQL. Se configuró sin contraseña (`trust`), lo cual solo es aceptable en este caso: el contenedor no publica ningún puerto, así que no queda expuesto fuera de Docker, y se borra solo al detenerlo (`--rm`). Así tampoco hubo que escribir ninguna contraseña en los comandos. Después se conectó con `require` y con `verify-full`, se revisó el certificado y se apagó el contenedor:

```powershell
docker run -d --rm --name dba-tls -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=comercializadora postgres:16 -c ssl=on -c ssl_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem -c ssl_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
docker exec dba-tls psql "host=localhost port=5432 dbname=comercializadora user=postgres sslmode=require" -c "SHOW ssl;" -c "SHOW ssl_min_protocol_version;" -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
docker exec dba-tls psql "host=localhost port=5432 dbname=comercializadora user=postgres sslmode=verify-full" -c "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"
docker exec dba-tls openssl x509 -in /etc/ssl/certs/ssl-cert-snakeoil.pem -noout -subject -issuer -dates
docker stop dba-tls
```

## Resultado obtenido

**Configuración de conexión de pgAdmin en la FIC** (Properties del servidor `db_a_carrillo`):

| Pestaña | Campo | Valor |
|---|---|---|
| Connection | Host name/address | `postgres-server` |
| Connection | Port | `5432` |
| Connection | Maintenance database | `db_20439504_jesus_carrillo` |
| Connection | Username | `u_20439504_jesus_carrillo` |
| Parameters | SSL mode (`sslmode`) | `prefer` |
| Parameters | Client certificate y Client certificate key | vacíos |

**Consultas en el Query Tool de la FIC:**

| Consulta | Resultado |
|---|---|
| Identificación | `usuario` = `u_20439504_jesus_carrillo`, `base_de_datos` = `db_20439504_jesus_carrillo`, `fecha_ejecucion` = `2026-10-16 06:34:05.018612+00` |
| `SHOW ssl;` | `off` |
| `SHOW ssl_min_protocol_version;` | error de permisos (abajo) |
| `SHOW port;` | `5432` |
| `SHOW listen_addresses;` | `*` |
| `inet_client_addr()` e `inet_client_port()` | `172.18.0.3` y `53646` |
| `ssl`, `version` y `cipher` de `pg_stat_ssl` | `false`, `[null]` y `[null]` |

La fecha sale en UTC (`+00`); en hora local eran las 23:34 del 15/10/2026. La consulta de `ssl_min_protocol_version` no devolvió datos, y pgAdmin mostró en la pestaña Messages:

```text
ERROR:  must be superuser or have privileges of pg_read_all_settings to examine "ssl_min_protocol_version"

SQL state: 42501
```

**Desde la PC, el host del servidor de la FIC no existe:**

```text
La solicitud de ping no pudo encontrar el host postgres-server. Compruebe el nombre y
vuelva a intentarlo.
```

**`dba-practica`, con TLS apagado.** Con `require`, psql se negó a conectarse:

```text
psql: error: connection to server at "localhost" (::1), port 5432 failed: server does not support SSL, but SSL was required
```

Con `prefer` sí se conectó, pero sin TLS:

```text
 ssl | version | cipher
-----+---------+--------
 f   |         |
(1 row)
```

**`dba-tls`, con TLS encendido.** El `docker run` respondió con el identificador del contenedor (`45653c835f62…`). Con `require` se conectó:

```text
 ssl
-----
 on
(1 row)

 ssl_min_protocol_version
--------------------------
 TLSv1.2
(1 row)

 ssl | version |         cipher
-----+---------+------------------------
 t   | TLSv1.3 | TLS_AES_256_GCM_SHA384
(1 row)
```

Con `verify-full`, psql se negó a conectarse:

```text
psql: error: connection to server at "localhost" (::1), port 5432 failed: root certificate file "/root/.postgresql/root.crt" does not exist
Either provide the file, use the system's trusted roots with sslrootcert=system, or change sslmode to disable server certificate verification.
```

El certificado del servidor:

```text
subject=CN=localhost
issuer=CN=localhost
notBefore=Oct  6 01:33:10 2026 GMT
notAfter=Oct  3 01:33:10 2036 GMT
```

`docker stop dba-tls` respondió `dba-tls`, y el contenedor se borró solo.

## Análisis

**¿La conexión actual utiliza TLS?** No. En el servidor de la FIC, `pg_stat_ssl` marca `ssl = false` para la sesión de pgAdmin, y la causa está en `SHOW ssl`: el servidor tiene TLS apagado, así que no acepta conexiones cifradas de nadie. pgAdmin se conecta con `sslmode=prefer`: intenta TLS, el servidor no lo ofrece y la conexión sigue sin cifrar, sin ningún aviso. `dba-practica` se comportó igual con `prefer`.

**¿Qué versión de TLS se está utilizando?** En la FIC, ninguna: `version` sale vacío. En `dba-tls`, la sesión usó `TLSv1.3`, la versión más reciente, por encima del mínimo que acepta ese servidor (`TLSv1.2`). En la FIC no se pudo ver ese mínimo: PostgreSQL solo muestra `ssl_min_protocol_version` a los superusuarios y a quien tenga el rol `pg_read_all_settings`, y la cuenta del alumno no tiene ninguno de los dos. Es un ejemplo de privilegio mínimo: un usuario normal no ve la configuración de seguridad del servidor.

**¿Qué algoritmo de cifrado aparece?** En la FIC, ninguno: `cipher` sale vacío. En `dba-tls` aparece `TLS_AES_256_GCM_SHA384`. Los datos se cifran con AES de 256 bits en modo GCM, que además de cifrar detecta si alguien modificó un mensaje, y SHA-384 es el hash que TLS 1.3 usa para derivar las llaves de la sesión.

**¿Qué diferencia existe entre una conexión protegida con TLS y una conexión sin TLS?** Esto responde también la pregunta de la Actividad 4, sobre qué pasa con la información mientras viaja. Sin TLS, las consultas y sus resultados viajan legibles por la red: si alguien ejecuta `SELECT * FROM clientes;`, quien pueda observar ese tráfico ve la consulta y todos los datos que regresa, y además podría alterarlos en el camino. Con TLS, el tráfico va cifrado (confidencialidad) y cualquier cambio se detecta (integridad). Con `verify-ca`, el cliente comprueba además que el certificado del servidor lo firmó una autoridad de confianza, y con `verify-full`, que es el servidor al que quería conectarse (autenticación).

En la FIC, la página de pgAdmin abre por HTTPS, pero ese cifrado es del lado web, del navegador al sitio, y no cubre la conexión de pgAdmin con PostgreSQL, que es la que mide `pg_stat_ssl`. Esa conexión viaja sin cifrar. El cliente es `172.18.0.3`, una dirección privada de la red interna de la FIC, y el nombre `postgres-server` no existe fuera de esa red, porque el `ping` desde la PC no lo encuentra. Eso limita quién puede observar el tráfico, pero dentro de esa red, quien pueda observarlo lo leería completo, y el servidor escucha en todas sus direcciones (`listen_addresses = *`).

**Los modos de `sslmode` (sección 13), con lo que se observó:**

| Modo | Qué hace | Lo que pasó en la práctica |
|---|---|---|
| `disable` | Nunca usa TLS. | No se probó. |
| `prefer` | Intenta TLS y, si el servidor no lo ofrece, se conecta sin cifrar. No revisa el certificado. Es el valor por omisión. | pgAdmin en la FIC y `dba-practica`: se conectó sin TLS y sin avisar. |
| `require` | Exige TLS, pero no comprueba quién es el servidor. | `dba-practica`: no se conectó. `dba-tls`: se conectó con TLSv1.3. |
| `verify-ca` | Exige TLS y que el certificado esté firmado por una autoridad de confianza. | No se probó. |
| `verify-full` | Lo mismo que `verify-ca`, y además que el nombre del servidor coincida con el certificado. | `dba-tls`: no se conectó, porque el cliente no tiene certificado raíz. |

La tabla 34.1 de la documentación de PostgreSQL 16 le da a `prefer` protección contra espionaje «Maybe» y contra un intermediario «No». También aclara que es el valor por omisión solo por compatibilidad y que no se recomienda en instalaciones seguras.

`require` sí garantiza el cifrado, pero no verifica la identidad del servidor: un servidor falso con cualquier certificado también sería aceptado. La excepción es cuando el cliente tiene un certificado raíz instalado; entonces se comporta como `verify-ca`, aunque la documentación desaconseja depender de eso.

`verify-full` es el único modo que comprueba las dos cosas, y por eso falló en `dba-tls`: el cliente no tiene ningún certificado raíz contra el cual comprobar el del servidor (`root.crt` no existe). Además, ese certificado es autofirmado (`subject` e `issuer` son el mismo, `CN=localhost`), así que ninguna autoridad certificadora responde por él. Para que `verify-full` aceptara la conexión, el cliente tendría que confiar en ese certificado, indicándolo con `sslrootcert`, y conectarse con el nombre que trae el certificado (`localhost`). Este certificado de prueba y su llave privada vienen dentro de la imagen de Docker, así que cualquiera que tenga la imagen tiene la misma llave: sirve para practicar, no para un servidor real. En un entorno real, el servidor usaría un certificado firmado por una autoridad, interna o pública, y los clientes se conectarían con `verify-full`.

**Lo que haría falta en el servidor de la FIC.** Tres cambios:

1. Encender TLS en el servidor: `ssl = on`, con un certificado y su llave.
2. Cambiar el SSL mode de pgAdmin a `verify-full`, o al menos a `require`, para que la conexión falle en lugar de seguir sin cifrar.
3. En `pg_hba.conf`, usar reglas `hostssl` en lugar de `host`, para que el servidor rechace las conexiones TCP que no usen TLS.

## Conclusión

La conexión entre pgAdmin y PostgreSQL en la FIC no usa TLS: el servidor lo tiene apagado, y pgAdmin, con `prefer`, se conecta sin cifrar y sin avisar. Lo mismo pasó en `dba-practica`. Solo con TLS encendido, en `dba-tls`, la sesión salió cifrada, con TLSv1.3 y AES de 256 bits. La práctica y la documentación muestran que no basta con pedir TLS:

- `prefer` puede quedarse sin cifrar.
- `require` cifra, pero no verifica la identidad del servidor.
- Solo `verify-full` comprueba las dos cosas, siempre que el servidor tenga un certificado en el que el cliente pueda confiar.

El cifrado de la Actividad 2 protege los datos guardados, y TLS los protege mientras viajan. La Actividad 7 compara las dos protecciones.

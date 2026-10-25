# Línea base de seguridad para PostgreSQL 16

LAB-04, Actividad 19 (sección 25 de la guía). Es la configuración mínima que debe cumplir un servidor PostgreSQL 16 de la empresa antes de entrar en operación, y contra la que se revisa después. Cada control dice cómo se comprueba y si `dba-practica` lo cumple al terminar el laboratorio.

La línea base sale de lo que se encontró y se cambió en este laboratorio ([cambios.md](cambios.md)). Una excepción a cualquier control se permite solo si queda escrita en `cambios.md`, con su justificación y su responsable.

## Red

| Control | Línea base | Cómo se comprueba | `dba-practica` |
| --- | --- | --- | --- |
| Interfaces autorizadas | `listen_addresses` solo con las interfaces por las que llegan los clientes. En un servidor sin clientes remotos, `localhost`. Nunca `*` sin justificación escrita. | `SHOW listen_addresses;` y `ss -lnt` (o `netstat -lnt`) | Cumple: `localhost`, escucha en `127.0.0.1` y `::1` |
| Puerto | Puerto documentado; 5432 si no hay una razón para otro. Cambiarlo no cuenta como control de seguridad. | `SHOW port;` | Cumple: 5432 |
| Firewall | Solo los equipos autorizados llegan al puerto, y todo lo demás se niega por omisión. El firewall no reemplaza a `pg_hba.conf`: se usan los dos. | Reglas del firewall del servidor y de la red | No aplica: el puerto no está publicado fuera de Docker |
| Redes permitidas | En `pg_hba.conf`, direcciones o redes concretas (`/32` para un solo servidor). Nunca `0.0.0.0/0`, `::/0` ni `all`. | `SELECT * FROM pg_hba_file_rules;` | Cumple: solo `127.0.0.1/32` y `::1/128` |

## Autenticación

| Control | Línea base | Cómo se comprueba | `dba-practica` |
| --- | --- | --- | --- |
| Método | `scram-sha-256` para contraseñas y `peer` para el administrador local. Nunca `trust`, `password` ni `md5`. | `SHOW password_encryption;` y la columna `auth_method` de `pg_hba_file_rules` | Cumple |
| Políticas de credenciales | Una contraseña distinta por cuenta, larga y generada al azar, guardada en un gestor de secretos y nunca en el código ni en un repositorio. Se asigna con `\password`, que no deja la contraseña en pantalla ni en el historial. Se cambia al menos una vez al año y cada vez que alguien que la conocía deja de necesitarla. | `rolpassword` en `pg_authid` debe empezar con `SCRAM-SHA-256$` | Parcial: SCRAM y `\password`. PostgreSQL no revisa la complejidad sin el módulo `passwordcheck`, y ni con él puede revisar de verdad una contraseña que llega ya cifrada, como las que manda `\password`. La caducidad tendría que fijarse con `VALID UNTIL` |
| Cuentas administrativas | Un solo superusuario, que solo entra de forma local (`peer`), y ningún superusuario por red. El trabajo diario de los DBA, con cuentas personales sin `SUPERUSER`. | `rolsuper` en `pg_roles` y las reglas de `pg_hba_file_rules` | Parcial: `postgres` es el único superusuario y solo entra por el socket, pero no hay cuentas personales |

## Autorización

| Control | Línea base | Cómo se comprueba | `dba-practica` |
| --- | --- | --- | --- |
| Roles | Roles de grupo `NOLOGIN` por función y cuentas con `LOGIN` que reciben esos roles. | `SELECT rolname, rolcanlogin FROM pg_roles;` | Cumple: `analista` y `soporte` son `NOLOGIN` |
| Privilegios | Mínimo privilegio: se retira a PUBLIC el `CONNECT` de cada base y se dan `GRANT` explícitos, por tabla o por vista. | `datacl` en `pg_database` e `information_schema.role_table_grants` | Cumple: solo `postgres` y `app_comercializadora` tienen `CONNECT` |
| Cuentas de aplicación | Una por aplicación, sin `SUPERUSER`, `CREATEDB`, `CREATEROLE`, `REPLICATION` ni `BYPASSRLS`, con su propio `CONNECTION LIMIT` y `statement_timeout`. | `pg_roles` (`rolconnlimit` y `rolconfig`) | Cumple: `app_comercializadora` |

## Configuración

| Control | Línea base | Cómo se comprueba | `dba-practica` |
| --- | --- | --- | --- |
| Parámetros relevantes | `ssl = on`, `password_encryption = scram-sha-256`, y `log_connections` y `log_disconnections` en `on`. Los cambios se hacen con `ALTER SYSTEM` y se documentan. | `pg_settings` y `pg_file_settings` | Cumple |
| Extensiones | Solo las que se usan, cada una con su razón documentada. Ninguna con acceso a archivos o a la red, ni lenguajes no confiables (`plpython3u` y similares), sin aprobación. | `SELECT extname, extversion FROM pg_extension;` | Cumple: `plpgsql` y `pgcrypto`, las dos en uso |
| Conexiones | `max_connections` según la capacidad del servidor; `superuser_reserved_connections` para que el DBA entre aunque el servidor esté lleno; `idle_in_transaction_session_timeout` activo; y límites propios para cada cuenta de aplicación. | `pg_settings` y `pg_roles` | Cumple: 100 y 3; `5min`; 10 conexiones y `30s` para la aplicación |

## Sistema operativo

| Control | Línea base | Cómo se comprueba | `dba-practica` |
| --- | --- | --- | --- |
| Propietario de archivos | El directorio de datos y la configuración son del usuario del servicio, `postgres`, que no es root. | `ls -l` | Cumple |
| Permisos | Configuración en `600`. La llave privada de TLS, legible solo por root y por el grupo del servicio. | `ls -l` | Cumple: `600`, y la llave en `640` de `root:ssl-cert` |
| Directorio de datos | `700` (o `750` si un grupo de administración necesita leerlo); con permisos más abiertos, PostgreSQL no arranca. Solo los administradores entran al servidor; aquí, quien puede usar `docker exec` tiene el mismo poder que root. | `ls -ld` | Cumple: `700` |

## Cifrado

| Control | Línea base | Cómo se comprueba | `dba-practica` |
| --- | --- | --- | --- |
| TLS | `ssl = on`, `ssl_min_protocol_version` de al menos `TLSv1.2`, reglas `hostssl` para toda conexión por red y clientes con `sslmode=verify-full`. El certificado lo emite una autoridad de certificación de confianza para la empresa, y su vencimiento se vigila. | `SHOW ssl;`, `pg_stat_ssl` y la fecha del certificado | Parcial: TLS 1.3 verificado con `verify-full`, pero con el certificado de prueba de la imagen |
| Protección de credenciales | SCRAM en el servidor. Las contraseñas no se escriben en sentencias (`ALTER ROLE … PASSWORD '…'` puede quedar en el log y en el historial), en scripts ni en repositorios. | Revisión de scripts, historial y log | Cumple en este laboratorio, con `\password`. En el LAB-02, una clave de prueba sí quedó en el log y en el historial |
| Protección de información sensible | Los datos personales se cifran o se enmascaran según su clasificación (LAB-01 y LAB-02), y la clave queda fuera de la base. | Revisión de columnas, vistas y permisos | Parcial: el RFC está cifrado con `pgcrypto` desde el LAB-02 |

## Mantenimiento

| Control | Línea base | Cómo se comprueba | `dba-practica` |
| --- | --- | --- | --- |
| Actualización | Cada versión menor de PostgreSQL 16 se aplica en cuanto sale (hay al menos una cada tres meses), después de probarla en un ambiente de ensayo. El cambio de versión mayor se planea antes del fin de soporte de la 16, el 9 de noviembre de 2028. | `SELECT version();` contra la lista de postgresql.org | Cumple: 16.15, la versión menor más reciente al 25 de octubre de 2026 |
| Revisión periódica | Cada trimestre y después de cualquier cambio se repite el checklist del README: reglas, roles, privilegios, extensiones, interfaces, certificado y conexiones rechazadas en el log. | `sql/01-inspeccion.sql` y `sql/04-verificacion.sql` | Propuesto |
| Documentación | Cada cambio queda en `cambios.md` con fecha, antes y después, justificación y cómo deshacerlo, y la configuración vigente se guarda en el repositorio. | La carpeta `configuracion/` | Cumple |

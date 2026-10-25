# LAB-04 — Hardening y configuración segura de PostgreSQL

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad II, tema 2.6 — Hardening de bases de datos
- Entorno: PostgreSQL 16.15 en Docker (contenedor `dba-practica`, con la base `comercializadora`). Todos los cambios se ensayaron antes en `dba-ensayo`, un contenedor desechable creado para eso.
- Fecha: 25 de octubre de 2026

Este README sigue la estructura de la sección 28 de la guía. Las preguntas del informe (sección 30), el caso integral (Actividad 18) y la reflexión (sección 31) están en [informe.md](informe.md). En `configuracion/` están la tabla de antes y después de la Actividad 16, con los comandos exactos y la forma de deshacer cada cambio ([cambios.md](configuracion/cambios.md)); la línea base de la Actividad 19 ([baseline.md](configuracion/baseline.md)); y el `pg_hba.conf` que quedó en el servidor ([pg_hba.conf](configuracion/pg_hba.conf)). Las capturas están en `evidencias/`; la [07](evidencias/07-cambios-configuracion.png) no la pide la guía, pero muestra la salida completa del script 03. Las siete capturas también están juntas en [evidencias-lab-04.pdf](evidencias/evidencias-lab-04.pdf), en el orden en que se tomaron.

| Actividad | Script | Evidencia | Apartado |
| --- | --- | --- | --- |
| 1. Superficie de ataque | [01-inspeccion.sql](sql/01-inspeccion.sql) | [01-superficie-ataque.png](evidencias/01-superficie-ataque.png) | Superficie de ataque inicial |
| 2. Archivos de configuración | [01-inspeccion.sql](sql/01-inspeccion.sql) | Este README | Superficie de ataque inicial |
| 3. listen_addresses | [01-inspeccion.sql](sql/01-inspeccion.sql) y [03-configuracion.sql](sql/03-configuracion.sql) | [02-listen-addresses.png](evidencias/02-listen-addresses.png) | Hallazgos |
| 4. pg_hba.conf | [01-inspeccion.sql](sql/01-inspeccion.sql) | [03-pg-hba.png](evidencias/03-pg-hba.png) | Hallazgos |
| 5. Regla permisiva | — | Este README | Hallazgos |
| 6. Mínimo privilegio en las conexiones | — | [pg_hba.conf](configuracion/pg_hba.conf) y [06-verificacion.png](evidencias/06-verificacion.png) | Hallazgos |
| 7. Autenticación | [01-inspeccion.sql](sql/01-inspeccion.sql) | [01-superficie-ataque.png](evidencias/01-superficie-ataque.png) | Hallazgos |
| 8. Usuarios y privilegios | [01-inspeccion.sql](sql/01-inspeccion.sql) y [02-roles.sql](sql/02-roles.sql) | [04-roles.png](evidencias/04-roles.png) | Hallazgos |
| 9. Cuentas administrativas y de aplicación | [02-roles.sql](sql/02-roles.sql) | [04-roles.png](evidencias/04-roles.png) | Hallazgos |
| 10. Extensiones | [01-inspeccion.sql](sql/01-inspeccion.sql) | Este README | Hallazgos |
| 11. Parámetros de conexión | [01-inspeccion.sql](sql/01-inspeccion.sql) y [03-configuracion.sql](sql/03-configuracion.sql) | [06-verificacion.png](evidencias/06-verificacion.png) | Hallazgos |
| 12. Permisos del sistema operativo | — | [cambios.md](configuracion/cambios.md), «Comprobaciones» | Hallazgos |
| 13. Exposición de red | — | [02-listen-addresses.png](evidencias/02-listen-addresses.png) | Hallazgos |
| 14. Política de firewall | — | Este README | Hallazgos |
| 15. TLS | [01-inspeccion.sql](sql/01-inspeccion.sql), [03-configuracion.sql](sql/03-configuracion.sql) y [04-verificacion.sql](sql/04-verificacion.sql) | [05-tls.png](evidencias/05-tls.png) | Hallazgos |
| 16. Antes y después | [04-verificacion.sql](sql/04-verificacion.sql) | [cambios.md](configuracion/cambios.md) | Cambios realizados |
| 17. Checklist de hardening | — | Este README | Checklist de hardening |
| 18. Caso integral | — | [informe.md](informe.md) | — |
| 19. Línea base | — | [baseline.md](configuracion/baseline.md) | — |

## Objetivo

Aplicar un hardening básico al servidor PostgreSQL de los laboratorios anteriores: identificar su superficie de ataque, encontrar las configuraciones inseguras, reducir su exposición y dejar controles de acceso, autenticación y configuración segura (sección 2 de la guía). El resultado se comprueba comparando el estado inicial con el final y justificando cada cambio.

En los LAB-01 a LAB-03 se protegieron los datos de la tabla `clientes`; este laboratorio protege el entorno por el que se llega a ellos (sección 35).

## Entorno

- **Servidor:** contenedor `dba-practica`, imagen `postgres:16` (PostgreSQL 16.15 sobre Debian), con la base `comercializadora` de la empresa ficticia Comercializadora Norte S.A. de C.V.
- **Red:** el contenedor está en la red `bridge` de Docker, con la dirección `172.17.0.2`, y no publica ningún puerto en Windows, así que desde fuera de la computadora no se llega a él.
- **Ensayo:** `dba-ensayo`, un contenedor desechable de la misma imagen, con las tablas que usan los scripts (`clientes`, `pii.mapa_cliente` y `analitica.clientes`). Ahí se probaron los cuatro scripts, el reinicio y la forma de deshacer los cambios antes de tocar `dba-practica`.
- **Terminal:** Windows PowerShell, con `docker exec`. Antes del hardening el administrador entraba con `docker exec -it dba-practica psql -U postgres -d comercializadora`; después, la única forma es `docker exec -it -u postgres dba-practica psql -d comercializadora`.
- **Puertos en escucha:** el contenedor no trae `ss` ni `netstat`, así que se usó un contenedor temporal `postgres:15-alpine` que comparte la red de `dba-practica` y se borra al terminar.

## Superficie de ataque inicial

### Actividad 1 — Superficie de ataque

Evidencia: [01-superficie-ataque.png](evidencias/01-superficie-ataque.png), con [sql/01-inspeccion.sql](sql/01-inspeccion.sql) a las 10:15.

| Elemento | Estado actual | ¿Es necesario? | Riesgo |
| --- | --- | --- | --- |
| Puerto PostgreSQL | 5432/TCP, el valor por omisión | Sí: es el puerto del servicio | Bajo por sí solo: es el primero que prueba un escaneo, pero cambiarlo no protege nada |
| Interfaces de escucha | `listen_addresses = '*'`: todas las interfaces del contenedor | No: nadie se conecta desde fuera del contenedor | Medio: cualquier contenedor de la red `bridge` puede llegar a `172.17.0.2:5432` |
| Conexiones remotas | Ninguna: las dos sesiones de psql llegaban por el socket local (`client_addr` vacío) | No | Medio: la regla 128 de `pg_hba.conf` las aceptaría desde cualquier dirección, con contraseña |
| Usuarios administrativos | `postgres`, el único superusuario y el único rol que inicia sesión; todo se hacía con él | Uno sí, pero no para todo | Alto: entraba sin contraseña desde dentro del contenedor |
| SSL/TLS | `ssl = off` | Sí, para cualquier conexión por red | Medio: SCRAM protege la contraseña, pero las consultas y los resultados viajarían sin cifrar |
| Métodos de autenticación | `trust` en 6 reglas y `scram-sha-256` en 1; `password_encryption = scram-sha-256` | `trust`, no | Alto: `trust` deja entrar sin comprobar nada |

`pg_stat_activity` mostró siete renglones: las dos sesiones de psql y cinco procesos internos del servidor. Una de las sesiones era una primera ejecución del script que se quedó en pausa en otra terminal (ver «Problemas encontrados»).

**¿Por qué conocer la superficie de ataque debe preceder al hardening?** Porque no se puede proteger lo que no se conoce, y un cambio a ciegas puede dejar abierto lo importante o cortar algo que sí se usa. La inspección dio tres datos que decidieron el resto del laboratorio: el problema más grave no era el puerto, sino las reglas `trust` de `pg_hba.conf`; nadie se conectaba por red, así que cambiar `listen_addresses` a `localhost` no iba a dejar fuera a ningún cliente; y no había cuenta de aplicación, así que había que crearla antes de quitar las reglas `trust`. Además, la inspección es el «antes» contra el que se compara el «después» de la Actividad 16.

### Actividad 2 — Archivos de configuración

| Tipo | Parámetro | Valor |
| --- | --- | --- |
| Datos | `data_directory` | `/var/lib/postgresql/data` |
| Configuración | `config_file` | `/var/lib/postgresql/data/postgresql.conf` |
| Autenticación | `hba_file` | `/var/lib/postgresql/data/pg_hba.conf` |
| Autenticación | `ident_file` | `/var/lib/postgresql/data/pg_ident.conf` |
| Logs | `log_directory` | `log`, dentro del directorio de datos, pero sin uso porque `logging_collector = off` |
| Logs | `log_connections` y `log_disconnections` | `off` los dos |

Los tres archivos de configuración están dentro del directorio de datos, que es donde los crea `initdb`. Junto a ellos está `postgresql.auto.conf`, donde escribe `ALTER SYSTEM`: se lee después de `postgresql.conf`, así que sus valores ganan. Como `logging_collector` está apagado, el log sale por la salida de error del proceso (`log_destination = stderr`) y lo guarda Docker: se lee con `docker logs dba-practica`, no en el directorio `log`.

**¿Por qué es importante conocer la ubicación física de estos archivos?** Porque cada uno se protege, se respalda y se revisa de forma distinta. Los datos y la configuración deben ser legibles solo por `postgres` (Actividad 12). `pg_hba.conf` hay que respaldarlo antes de cambiarlo, y hay que saber qué archivo manda: un valor en `postgresql.auto.conf` le gana a `postgresql.conf`, y editar el archivo equivocado no cambia nada. Los logs son la evidencia de quién se conectó, y aquí no están donde dice `log_directory`: quien los buscara ahí concluiría que el servidor no registra nada. Por último, como la configuración vive dentro del directorio de datos, cualquier copia de ese directorio (un respaldo o un volumen copiado) también se lleva `pg_hba.conf`.

## Hallazgos

### Actividad 3 — listen_addresses

PostgreSQL estaba escuchando **en todas las interfaces**.

```text
Configuración encontrada:
listen_addresses = '*', en la línea 60 de postgresql.conf. El valor por omisión de
PostgreSQL es 'localhost'; este lo puso la imagen de Docker.

Interfaces necesarias:
Solo la local (127.0.0.1 y ::1): el administrador y la cuenta de aplicación se
conectan desde dentro del contenedor.

Interfaces innecesarias:
La del contenedor en la red bridge de Docker (172.17.0.2) y cualquier otra red a la
que se conecte después, porque '*' también las incluiría.
```

**¿Cuál arquitectura reduce mejor la exposición?** La segunda. En la primera, entre Internet y el puerto 5432 solo está el firewall: el servidor se puede alcanzar desde Internet, y todo depende de que las reglas del firewall estén bien. Si una se equivoca, cualquiera en Internet puede intentar conectarse. En la segunda, el firewall bloquea Internet y el servidor está en una red privada: aunque el firewall fallara, el servidor no tiene una dirección a la que se llegue desde Internet, y un atacante tendría que entrar primero a la red privada. Son dos barreras en lugar de una. `dba-practica` se parece a la segunda: está en la red privada de Docker y no publica su puerto. Con `listen_addresses = 'localhost'` se fue un paso más allá, porque ahora tampoco la red privada llega al puerto ([evidencia 02](evidencias/02-listen-addresses.png)).

### Actividad 4 — pg_hba.conf

Evidencia: [03-pg-hba.png](evidencias/03-pg-hba.png)

| Línea | Tipo | Base | Usuario | Origen | Método | Conexión |
| --- | --- | --- | --- | --- | --- | --- |
| 117 | local | all | all | Socket local | trust | Local |
| 119 | host | all | all | 127.0.0.1 | trust | IPv4 |
| 121 | host | all | all | ::1 | trust | IPv6 |
| 124 | local | replication | all | Socket local | trust | Local |
| 125 | host | replication | all | 127.0.0.1 | trust | IPv4 |
| 126 | host | replication | all | ::1 | trust | IPv6 |
| 128 | host | all | all | all | scram-sha-256 | IPv4 e IPv6 |

- **Reglas locales:** la 117 y la 124, por el socket. Con `trust`, cualquier usuario del sistema operativo del contenedor entraba como cualquier usuario de PostgreSQL, incluido `postgres`, sin contraseña.
- **IPv4 e IPv6:** la 119 y la 121 hacen lo mismo por TCP desde el propio servidor; la 125 y la 126, para replicación.
- **Bases afectadas:** `all` (todas) en cuatro reglas. `replication` no es una base, sino las conexiones de replicación física, con las que se puede copiar el servidor completo (por ejemplo, con `pg_basebackup`); este servidor no tiene réplicas, así que no se necesitan.
- **Usuarios afectados:** `all` en las siete.
- **Redes permitidas:** solo el propio servidor, menos en la 128, donde `all` acepta cualquier dirección IPv4 o IPv6. Equivale a `0.0.0.0/0` y `::/0` juntos, y es más amplia que el ejemplo de la guía.
- **Métodos:** `trust` en seis reglas y `scram-sha-256` en una.

PostgreSQL usa la primera regla que coincide con la conexión. Por eso, desde el propio servidor nunca se pedía contraseña: las reglas 119 y 121 están antes que la 128. Las seis reglas `trust` son las que escribe `initdb` cuando no se le indica un método, y la 128 la agrega la imagen de Docker al crear el servidor.

### Actividad 5 — Una regla permisiva

La regla de la guía, `host all all 0.0.0.0/0 scram-sha-256`, es casi la 128 de este servidor.

- **¿Qué bases de datos permite?** Todas: aquí, `comercializadora`, `postgres` y `template1` (`template0` no acepta conexiones).
- **¿Qué usuarios permite?** Todos, incluido el superusuario `postgres`.
- **¿Qué direcciones de origen permite?** Cualquier dirección IPv4. La 128, con `all`, también cualquier IPv6.
- **¿Qué método de autenticación utiliza?** `scram-sha-256`: pide la contraseña y la comprueba sin que viaje por la red.
- **¿Por qué puede representar una exposición innecesaria?** Porque cualquier equipo que llegue al puerto puede intentar la contraseña de cualquier usuario en cualquier base, y la única barrera es la contraseña. PostgreSQL no bloquea una cuenta después de varios intentos fallidos, así que nada detiene un ataque de fuerza bruta contra `postgres`. Además, la regla no dice quién debería conectarse, así que no hay forma de saber si una conexión es legítima.
- **¿Qué información necesitarías para restringirla?** Qué sistemas se conectan de verdad y desde qué dirección; a qué base y con qué usuario; si la conexión cruza una red en la que no se confía, para exigir TLS; y quién responde por cada acceso. Se obtiene preguntando a los responsables de cada aplicación y activando `log_connections` para ver las conexiones reales.

```text
Regla actual:
host  all  all  all  scram-sha-256   (línea 128)

Problema:
Cualquier usuario, incluido postgres, puede intentar entrar a cualquier base desde
cualquier dirección IPv4 o IPv6. Y desde el propio servidor ni siquiera se pide
contraseña (reglas trust de las líneas 117 a 126).

Origen que realmente necesita acceso:
Solo el propio servidor (127.0.0.1 y ::1). En el laboratorio no hay una aplicación
real, así que se supuso que corre en el mismo servidor.

Base de datos:
comercializadora

Usuario:
app_comercializadora, la cuenta de aplicación de la Actividad 9

Regla propuesta:
hostssl  comercializadora  app_comercializadora  127.0.0.1/32  scram-sha-256
hostssl  comercializadora  app_comercializadora  ::1/128       scram-sha-256
```

### Actividad 6 — Mínimo privilegio en las conexiones

Evidencias: [pg_hba.conf](configuracion/pg_hba.conf) y [06-verificacion.png](evidencias/06-verificacion.png)

El archivo nuevo tiene tres reglas, y cada una fija las cuatro piezas que pide la guía:

| Regla | Base de datos | Usuario | Origen | Método |
| --- | --- | --- | --- | --- |
| Administración | `all` | `postgres` | Socket local | `peer`: el sistema operativo confirma que quien se conecta es el usuario `postgres` |
| Aplicación (IPv4) | `comercializadora` | `app_comercializadora` | `127.0.0.1/32` | `scram-sha-256`, solo con TLS (`hostssl`) |
| Aplicación (IPv6) | `comercializadora` | `app_comercializadora` | `::1/128` | `scram-sha-256`, solo con TLS (`hostssl`) |

No hace falta una regla final de «denegar todo»: si ninguna regla coincide, PostgreSQL rechaza la conexión, y si una coincide y la autenticación falla, no prueba las siguientes. Si la aplicación estuviera en otro servidor, por ejemplo en `10.10.10.30`, su regla sería `hostssl comercializadora app_comercializadora 10.10.10.30/32 scram-sha-256`, con `/32` para esa sola máquina y no `/24` para toda su red, y `listen_addresses` tendría que incluir la dirección privada del servidor (`'localhost,10.10.10.20'`), no `*`.

### Actividad 7 — Autenticación

`password_encryption` ya era `scram-sha-256`, el valor por omisión de PostgreSQL 16, así que las contraseñas nuevas ya se guardaban con SCRAM y no hubo que cambiarlo. La de `app_comercializadora` se guardó así: su verificador en `pg_authid` empieza con `SCRAM-SHA-256$4096:`, es decir, con 4096 iteraciones.

- **¿Qué diferencia existe entre autenticación y autorización?** La autenticación comprueba quién eres; la autorización decide qué puedes hacer ya adentro. En este laboratorio se ven por separado: `app_comercializadora` se autentica bien, con SCRAM y TLS ([evidencia 05](evidencias/05-tls.png)), y aun así no puede borrar clientes, porque no tiene el permiso `DELETE` ([evidencia 04](evidencias/04-roles.png)). En cambio, root ya no pasa la autenticación como `postgres`, así que no llega a hacer nada.
- **¿Qué protege scram-sha-256?** La contraseña, en dos lugares. En la red, porque el cliente demuestra que la conoce respondiendo a un reto, sin mandarla: quien escuche la conexión no la obtiene ni puede reutilizar la respuesta en otra sesión. Y en el servidor, porque no se guarda la contraseña sino un verificador con sal y 4096 iteraciones, del que no se puede sacar la contraseña sin probar una por una. Lo que no protege son los datos de la sesión: eso le toca a TLS.
- **¿Por qué una contraseña almacenada mediante un mecanismo de autenticación no debe confundirse con cifrado reversible?** Porque el verificador es de un solo sentido: el servidor puede comprobar una contraseña, pero no recuperarla, y nadie, ni el DBA, puede «descifrarla». El cifrado reversible, como el `pgp_sym_encrypt` con el que se cifró el RFC en el LAB-02, se deshace con la clave, y quien tiene la clave tiene todos los datos. Para las contraseñas se usa lo primero porque nadie necesita leerlas, solo comprobarlas; para el RFC, lo segundo, porque Facturación sí necesita leerlo.
- **¿Qué sucede si una cuenta tiene permisos excesivos aunque utilice una contraseña fuerte?** Que la contraseña solo cuida la entrada. Quien llegue a usar la cuenta tiene todos sus permisos: quien la robe de un archivo de configuración, o quien encuentre una inyección SQL en la aplicación, que ni siquiera necesita la contraseña porque usa la sesión que la aplicación ya abrió. Una contraseña fuerte no reduce lo que la cuenta puede hacer; eso lo hace el mínimo privilegio (Actividades 8 y 9).

### Actividad 8 — Usuarios y privilegios

Evidencia: [04-roles.png](evidencias/04-roles.png). Se excluyen los roles predefinidos `pg_*`, que no inician sesión.

| Rol | LOGIN | SUPERUSER | CREATEROLE | CREATEDB | Función |
| --- | --- | --- | --- | --- | --- |
| `postgres` | Sí | Sí | Sí | Sí | Superusuario creado al instalar el servidor; antes de este laboratorio se usaba para todo |
| `analista` | No | No | No | No | Rol de grupo de Analítica, con `SELECT` sobre `v_analitica_clientes` y `analitica.clientes` |
| `soporte` | No | No | No | No | Rol de grupo de Soporte, con `SELECT` sobre `v_clientes_soporte` |
| `app_comercializadora` | Sí | No | No | No | Cuenta de la aplicación, creada en este laboratorio |

- **Superusuarios:** solo `postgres`.
- **Usuarios que pueden iniciar sesión:** al inicio, solo `postgres`; ahora también `app_comercializadora`.
- **CREATEROLE y CREATEDB:** solo `postgres`.
- **Roles utilizados por aplicaciones:** ninguno al inicio, así que una aplicación habría tenido que usar `postgres`.
- **Cuentas que podrían ser innecesarias:** `analista` y `soporte` vienen de los laboratorios anteriores, no inician sesión y hoy no tienen miembros, así que nadie usa sus permisos. Se conservan porque son el diseño de acceso por área, pero la revisión periódica debe confirmar que alguien los necesita.

**¿Por qué no debería utilizarse una cuenta SUPERUSER como cuenta normal de una aplicación?** Porque un superusuario se salta todas las revisiones de permisos, menos la de iniciar sesión. Si la aplicación fuera `postgres`, una inyección SQL o una contraseña filtrada darían todo: leer y borrar cualquier tabla de cualquier base, crear usuarios, cambiar la configuración con `ALTER SYSTEM` y hasta ejecutar comandos del sistema operativo con `COPY ... PROGRAM`. También podría deshacer este hardening desde SQL. Y como ningún `GRANT` ni `REVOKE` lo limita, el mínimo privilegio no se le puede aplicar.

### Actividad 9 — Cuentas administrativas y de aplicación

| Cuenta | Propósito | LOGIN | Privilegios |
| --- | --- | --- | --- |
| DBA: `postgres` | Administración | Sí, solo por el socket y como el usuario `postgres` del sistema (`peer`) | Administrativos (superusuario) |
| APP: `app_comercializadora` | Aplicación | Sí, solo desde el propio servidor, con TLS y `scram-sha-256` | Mínimos: `SELECT`, `INSERT` y `UPDATE` sobre `clientes` y uso de su secuencia; máximo 10 conexiones y 30 segundos por consulta |
| CONSULTA: `consulta_comercializadora` (solo diseño) | Consulta | Sí | Solo lectura: miembro de `analista`, con sus `SELECT` sobre las vistas de Analítica |

La cuenta de aplicación se creó con [sql/02-roles.sql](sql/02-roles.sql) y se probó: puede contar los clientes, pero recibe «permission denied» al intentar borrarlos, leer `pii.mapa_cliente` o crear una tabla. El script también le quitó a PUBLIC el permiso de conectarse a `comercializadora`; ahora `pg_database` dice `{postgres=CTc/postgres,app_comercializadora=c/postgres}`, es decir, solo esas dos cuentas pueden conectarse. La cuenta de consulta quedó solo en el diseño. Se crearía así, con su contraseña puesta con `\password` y su regla en `pg_hba.conf`, como la de la aplicación:

```sql
CREATE ROLE consulta_comercializadora LOGIN CONNECTION LIMIT 5 IN ROLE analista;
GRANT CONNECT ON DATABASE comercializadora TO analista;
```

En una empresa con varios DBA, cada uno tendría su propia cuenta, sin `SUPERUSER` para el trabajo diario, y `postgres` quedaría para emergencias; así el log dice quién hizo cada cambio.

**¿Qué riesgo existe si la aplicación se conecta utilizando una cuenta administrativa?** Que cualquier falla de la aplicación se vuelve una falla de toda la base. La contraseña administrativa quedaría en la configuración de la aplicación, en cada servidor donde se instale y al alcance de sus desarrolladores; una inyección SQL tendría permisos de administrador; un error de programación, como un `DELETE` sin `WHERE`, no encontraría ningún permiso que lo detuviera; y en el log no se distinguiría lo que hizo la aplicación de lo que hizo el DBA. También hay un riesgo de disponibilidad: un superusuario puede usar las 3 conexiones reservadas para el administrador, así que si la aplicación las agota, el DBA ya no puede entrar a resolver el problema.

### Actividad 10 — Extensiones

| Extensión | Versión | ¿Se usa? | Origen |
| --- | --- | --- | --- |
| `plpgsql` | 1.0 | Sí: es el lenguaje de los bloques `DO`, como los de los scripts 02 y 03 | Viene instalada en toda base nueva |
| `pgcrypto` | 1.3 | Sí: los hash bcrypt de `usuarios_segura` y el RFC cifrado de `clientes_protegidos`, del LAB-02 | La instaló el LAB-01, para prácticas |

- **Necesarias:** las dos.
- **Instaladas para prácticas:** `pgcrypto`. El LAB-01 la instaló para la seudonimización, aunque la función que usó, `gen_random_uuid()`, ya es propia de PostgreSQL; la que de verdad la necesita es el LAB-02.
- **Funcionalidad que podría sobrar en otro entorno:** `pgcrypto`, en un servidor que no cifre datos dentro de la base. Lo que más sobra aquí no son extensiones, sino las tablas de práctica del LAB-02: `usuarios_insegura`, que guarda contraseñas en texto plano a propósito, y `usuarios_segura`.
- No hay extensiones que den acceso a archivos o a otros servidores, como `file_fdw`, `dblink` o `postgres_fdw`, ni lenguajes no confiables, que serían las primeras en revisar.

### Actividad 11 — Parámetros de conexión

| Parámetro | Antes | Después | Qué hace |
| --- | --- | --- | --- |
| `max_connections` | 100 | 100 | Máximo de conexiones simultáneas. Cada una es un proceso del servidor con su propia memoria, y cambiarlo requiere reiniciar. |
| `superuser_reserved_connections` | 3 | 3 | De esas 100, reserva 3 para superusuarios, para que el DBA pueda entrar aunque el servidor esté lleno. Los demás usuarios tienen 97. |
| `statement_timeout` | 0 (desactivado) | 0 en general y 30 segundos para `app_comercializadora` | Cancela cualquier sentencia que tarde más que el límite. |
| `idle_in_transaction_session_timeout` | 0 (desactivado) | 5 minutos | Cierra la sesión que abrió una transacción y se quedó esperando, sin hacer nada, más tiempo que el límite. |

`statement_timeout` se puso solo a la cuenta de la aplicación porque la documentación de PostgreSQL desaconseja ponerlo en `postgresql.conf`: afectaría a todas las sesiones, incluidas las tareas largas del administrador.

**¿Por qué mantener conexiones indefinidamente abiertas puede representar un problema de disponibilidad o consumo de recursos?** Porque cada conexión ocupa uno de los 100 lugares y un proceso con su memoria, aunque no haga nada. Si una aplicación abre conexiones y no las cierra, los lugares se acaban y el servidor empieza a rechazar a los clientes nuevos: sigue encendido, pero nadie lo puede usar. Es peor si la sesión se queda con una transacción abierta. Conserva sus bloqueos, y cualquier cambio a esas tablas espera detrás de ella; además, VACUUM no puede limpiar los renglones muertos que esa transacción todavía podría ver, así que las tablas crecen y las consultas se vuelven más lentas. Para eso es el límite de 5 minutos: en esta materia, el mismo parámetro cuida la seguridad y el desempeño.

### Actividad 12 — Permisos del sistema operativo

Evidencia: «Comprobaciones» en [cambios.md](configuracion/cambios.md), con la salida completa de `ls -ld`.

| Archivo | Propietario y grupo | Permisos | ¿Lo pueden leer otros usuarios? |
| --- | --- | --- | --- |
| Directorio de datos | `postgres:postgres` | `drwx------` (700) | No |
| `postgresql.conf` y `postgresql.auto.conf` | `postgres:postgres` | `-rw-------` (600) | No |
| `pg_hba.conf`, su respaldo y `pg_ident.conf` | `postgres:postgres` | `-rw-------` (600) | No |
| Llave privada del certificado | `root:ssl-cert` | `-rw-r-----` (640) | Solo el grupo `ssl-cert`, al que pertenece `postgres` |

Los permisos ya eran correctos antes del laboratorio y no se cambiaron: fuera de root, solo `postgres` puede leer estos archivos.

**¿Por qué no es suficiente proteger PostgreSQL mediante GRANT y REVOKE si cualquier usuario del sistema operativo puede leer archivos sensibles?** Porque `GRANT` y `REVOKE` solo controlan lo que se pide a través de PostgreSQL, y los archivos se pueden leer sin pasar por él. Quien pueda leer el directorio de datos puede copiarlo y arrancar su propio PostgreSQL con esa copia: tendría todas las tablas sin importar ningún permiso, y también `pg_authid`, con los verificadores de las contraseñas. Quien lea `pg_hba.conf` sabe qué reglas atacar, y quien lea la llave privada puede hacerse pasar por el servidor. En Docker hay que agregar algo: quien puede usar `docker exec` entra como root al contenedor y puede actuar como cualquier usuario, incluido `postgres` (`-u postgres`). Por eso, en la práctica, tener acceso a Docker en la computadora es tener acceso de administrador a la base, y ese acceso se protege en Windows.

### Actividad 13 — Exposición de red

Evidencia: [02-listen-addresses.png](evidencias/02-listen-addresses.png). El comando está en «Comprobaciones», en [cambios.md](configuracion/cambios.md).

```text
Dirección de escucha:
Antes, 0.0.0.0 y :: (todas las interfaces del contenedor); después, 127.0.0.1 y ::1.

Puerto:
5432/TCP

¿Está expuesto fuera de la interfaz necesaria?
Antes, sí: también escuchaba en 172.17.0.2, donde lo alcanzaba cualquier contenedor
de la red bridge de Docker. Después, no. En ningún momento estuvo publicado en Windows.
```

**Un hallazgo fuera del laboratorio.** Si en Windows se buscan los puertos en escucha, el 5432 sí aparece en `0.0.0.0` y `::`, pero no es `dba-practica`: es un PostgreSQL 18 instalado directamente en Windows (servicio `postgresql-x64-18`). El firewall de Windows está activo en sus tres perfiles, no se encontró ninguna regla para el 5432 ni para PostgreSQL, y lo que no tiene regla de entrada se bloquea por omisión. No se modificó porque no es parte del laboratorio, pero tiene el mismo problema que se corrigió en el contenedor: si no se usa desde otras máquinas, debería escuchar solo en `localhost`.

### Actividad 14 — Política de firewall

No se modificó ningún firewall. La política conceptual para el escenario de la guía, con PostgreSQL en `10.10.10.20:5432` y acceso solo para la red DBA, es:

| Origen | Destino | Puerto | Acción |
| --- | --- | --- | --- |
| 10.10.10.0/24 (red DBA) | PostgreSQL (10.10.10.20) | 5432/TCP | Permitir |
| Cualquier otro origen | PostgreSQL (10.10.10.20) | 5432/TCP | Denegar |

Lo importante de la segunda regla es que todo lo que no está permitido de forma explícita queda negado; lo ideal es que sea la acción por omisión del firewall. En un caso real, el servidor de la aplicación también tendría su propia regla, con su dirección exacta (`/32`), y `pg_hba.conf` y `listen_addresses` deberían permitir exactamente lo mismo que el firewall. En `dba-practica` no aplica, porque el puerto no está publicado y ahora solo escucha dentro del contenedor.

**¿Por qué pg_hba.conf y el firewall no son controles equivalentes?** Porque actúan en momentos distintos y con información distinta. El firewall decide antes de que la conexión llegue a PostgreSQL, y solo con la dirección y el puerto: lo que bloquea nunca llega al servidor, así que no puede intentar contraseñas ni aprovechar una falla del software. Pero no sabe nada de usuarios ni de bases. `pg_hba.conf` decide cuando la conexión ya llegó: el servidor la aceptó, creó un proceso para atenderla y le responde con un error si no hay regla. A cambio, sabe a qué base y con qué usuario se quiere entrar, si la conexión viene con TLS y qué método de autenticación exigir. Por ejemplo, el firewall puede dejar pasar a toda la red DBA, pero solo `pg_hba.conf` puede decir que desde esa red el superusuario no entra. Además, los administran equipos distintos (redes y el DBA), así que si uno se equivoca, el otro sigue protegiendo. Por eso se usan los dos.

### Actividad 15 — TLS

Evidencia: [05-tls.png](evidencias/05-tls.png)

| Elemento | Antes | Después |
| --- | --- | --- |
| `ssl` | `off` | `on`, con el certificado de prueba que trae la imagen |
| `ssl_min_protocol_version` | `TLSv1.2` | `TLSv1.2`, sin cambio |
| Sesión del administrador | Socket local, sin TLS | Igual: el socket no pasa por la red |
| Sesión de la aplicación | No existía | TCP con TLS obligatorio y el certificado del servidor comprobado |

```text
¿La conexión actual utiliza TLS?
Antes, no: ssl estaba apagado y la sesión llegaba por el socket. Después, la de la
aplicación sí.

Versión:
TLSv1.3

Cipher:
TLS_AES_256_GCM_SHA384
```

La consulta de la guía no funciona tal cual: `pg_stat_ssl` no tiene las columnas `usename` ni `client_addr`, así que los scripts la unen con `pg_stat_activity` por el `pid`. En el LAB-02, TLS se probó en un contenedor desechable y `dba-practica` siguió con `ssl = off`; en este laboratorio quedó encendido y es obligatorio para la aplicación.

**¿Está TLS correctamente integrado en el servidor y en los clientes?** En el servidor, sí: las reglas de la aplicación son `hostssl`, así que una conexión sin TLS no tiene regla, y la evidencia 05 lo muestra: la misma cuenta con `sslmode=disable` se rechaza («no encryption»). En el cliente también, porque la aplicación se conectó con `sslmode=verify-full`, que exige TLS, comprueba que el certificado esté firmado por alguien de confianza y que el nombre del servidor (`localhost`) coincida con el del certificado. El valor por omisión de libpq es `prefer`, que intenta TLS sin comprobar el certificado y, si no lo consigue, se conecta sin cifrar; con él, otro servidor podría hacerse pasar por este. El punto débil es el certificado: es el de prueba de la imagen, y todos los contenedores de esa imagen tienen la misma llave privada, así que `verify-full` solo demuestra que el servidor tiene esa llave, no que sea este servidor. En producción hace falta un certificado propio, emitido por una autoridad de certificación de confianza para la empresa.

## Cambios realizados

Se hicieron cinco cambios, en este orden. La tabla de antes y después de la Actividad 16, las horas, los comandos exactos y la forma de deshacerlos están en [cambios.md](configuracion/cambios.md).

1. **Cuenta de aplicación** ([sql/02-roles.sql](sql/02-roles.sql)): `app_comercializadora`, sin atributos administrativos y con permisos solo sobre `clientes`. El script también le quitó a PUBLIC el `CONNECT` de la base.
2. **`pg_hba.conf` nuevo** ([configuracion/pg_hba.conf](configuracion/pg_hba.conf)): de 7 reglas a 3 y sin ninguna `trust`. El original quedó respaldado como `pg_hba.conf.antes`.
3. **TLS** encendido, con el certificado de prueba de la imagen.
4. **Registro de conexiones y límite a las transacciones inactivas:** `log_connections`, `log_disconnections` e `idle_in_transaction_session_timeout = 5min`.
5. **`listen_addresses = 'localhost'`**, el único que necesitó reiniciar.

Los cambios 3 a 5 los hizo [sql/03-configuracion.sql](sql/03-configuracion.sql) con `ALTER SYSTEM`, y la misma recarga aplicó el `pg_hba.conf` nuevo; `listen_addresses` se activó con `docker restart -t 60 dba-practica`. No se cambiaron el puerto, `password_encryption`, las extensiones, los permisos de los archivos ni los límites globales de conexiones; la razón de cada uno está en «Lo que no se cambió», en cambios.md.

## Justificación de los cambios

- **El orden.** La cuenta de aplicación se creó primero, porque el `pg_hba.conf` nuevo solo deja entrar por red a esa cuenta, y antes de quitar las reglas `trust` tenía que existir con su contraseña. Después se aplicaron juntos el `pg_hba.conf` nuevo y los parámetros, porque las reglas `hostssl` solo funcionan con `ssl = on`. El reinicio quedó al final por ser el único cambio que interrumpe el servicio.
- **`pg_hba.conf`, el cambio más importante.** Las reglas `trust` no comprobaban nada: cualquier proceso dentro del contenedor podía ser superusuario. La regla 128 dejaba intentar contraseñas a cualquier usuario desde cualquier dirección. Ahora cada regla dice qué base, qué usuario, desde dónde y con qué método, y todo lo demás se rechaza. Se aplicó con una recarga, sin cortar las sesiones abiertas, y antes de recargar, el script revisó en `pg_hba_file_rules` que el archivo no tuviera errores, porque con un `pg_hba.conf` inválido el servidor no volvería a arrancar.
- **El administrador, solo con `peer`.** El superusuario es la cuenta más valiosa, y ahora tiene un solo camino de entrada: el socket local, y solo si el sistema operativo confirma que quien se conecta es el usuario `postgres`. No usa una contraseña que se pueda filtrar y no tiene ninguna regla por red.
- **La cuenta de aplicación.** Separa lo que hace la aplicación de lo que hace el DBA, y limita el daño si la aplicación se ve comprometida: sin `DELETE`, sin crear objetos y sin acceso a `pii` ([evidencia 04](evidencias/04-roles.png)). Quitarle el `CONNECT` a PUBLIC hace que una cuenta nueva no pueda ni conectarse hasta que alguien se lo dé.
- **TLS.** Sin TLS, las consultas y sus resultados viajan sin cifrar, aunque SCRAM proteja la contraseña. `hostssl` lo hace obligatorio del lado del servidor, y `verify-full`, del lado del cliente.
- **El registro de conexiones.** Sin `log_connections`, el log no dice quién se conecta con éxito; los rechazos sí aparecían, porque son errores. Con el registro encendido, cada prueba de la verificación quedó en el log, aceptada o rechazada.
- **Los límites de tiempo y de conexiones.** Protegen la disponibilidad: una transacción olvidada ya no retiene bloqueos ni frena el VACUUM más de 5 minutos, y la aplicación no puede ocupar más de 10 conexiones ni correr consultas de más de 30 segundos.
- **`listen_addresses`.** Cierra el puerto en la red de Docker. Con el `pg_hba.conf` nuevo, otro contenedor ya no podía autenticarse, pero el servidor todavía tenía que recibir sus conexiones y contestarles; ahora ni siquiera le llegan.
- **Todo es reversible.** Los cambios se ensayaron completos en `dba-ensayo`, incluida la forma de deshacerlos, y en `dba-practica` quedó el respaldo del `pg_hba.conf` original.

## Verificación

Después del reinicio se corrió [sql/04-verificacion.sql](sql/04-verificacion.sql) como el usuario `postgres` del sistema, a las 10:31.

- **Configuración** ([evidencia 06](evidencias/06-verificacion.png)): `listen_addresses = localhost`, `ssl = on`, `log_connections` y `log_disconnections` en `on`, e `idle_in_transaction_session_timeout = 300000` (milisegundos, es decir, 5 minutos), todos con origen `configuration file`; y en `pg_hba_file_rules`, solo las 3 reglas nuevas.
- **TLS** ([evidencia 05](evidencias/05-tls.png)): la aplicación entró con `sslmode=verify-full`, y `pg_stat_ssl` confirma TLSv1.3 con `TLS_AES_256_GCM_SHA384`. La misma cuenta sin TLS y el superusuario por TCP, aunque usara TLS, se rechazaron por no tener regla.
- **Red** ([evidencia 02](evidencias/02-listen-addresses.png)): `netstat` pasó de `0.0.0.0:5432` y `:::5432` a `127.0.0.1:5432` y `::1:5432`.
- **El administrador:** root ya no entra como `postgres` («Peer authentication failed for user "postgres"»), y solo funciona `docker exec -u postgres`.
- **El log del servidor** registró cada conexión aceptada y rechazada, con su usuario y su cifrado; las líneas están en «Comprobaciones», en cambios.md.
- **Los permisos de los archivos** siguieron en `600` y `700` después de los cambios.

### Verificación final (sección 26)

- [x] Identifiqué la superficie de ataque (Actividad 1).
- [x] Identifiqué las interfaces de escucha (Actividades 3 y 13).
- [x] Identifiqué el puerto PostgreSQL (Actividad 1).
- [x] Revisé pg_hba.conf (Actividad 4).
- [x] Analicé las reglas de autenticación (Actividades 5 a 7).
- [x] Identifiqué cuentas administrativas (Actividad 8).
- [x] Revisé privilegios de los roles (Actividad 8).
- [x] Separé conceptualmente cuentas administrativas y de aplicación (Actividad 9; la de aplicación además se creó).
- [x] Revisé extensiones (Actividad 10).
- [x] Revisé parámetros de conexión (Actividad 11).
- [x] Revisé permisos del sistema operativo (Actividad 12).
- [x] Verifiqué exposición de red (Actividad 13).
- [x] Analicé el uso de TLS (Actividad 15).
- [x] Documenté cambios ([cambios.md](configuracion/cambios.md)).
- [x] Elaboré una checklist (siguiente apartado).
- [x] Construí una línea base ([baseline.md](configuracion/baseline.md)).

## Checklist de hardening

Actividad 17. «Parcial» quiere decir que el control está documentado o aplicado solo en parte; lo que falta está explicado en la evidencia.

| # | Control | Verificado | Evidencia |
| --- | --- | --- | --- |
| 1 | Puerto documentado | Sí | 5432/TCP ([01](evidencias/01-superficie-ataque.png)); no se cambió porque eso no reduce la exposición |
| 2 | Interfaces de escucha justificadas | Sí | `localhost`, porque todos los clientes están en el servidor ([02](evidencias/02-listen-addresses.png) y [06](evidencias/06-verificacion.png)) |
| 3 | pg_hba.conf revisado | Sí | Las 7 reglas originales, analizadas en la Actividad 4 ([03](evidencias/03-pg-hba.png)) |
| 4 | Redes autorizadas restringidas | Sí | Solo `127.0.0.1/32` y `::1/128` ([06](evidencias/06-verificacion.png)) |
| 5 | Autenticación segura | Sí | Ninguna regla `trust`: `peer` y `scram-sha-256` ([06](evidencias/06-verificacion.png)) |
| 6 | Superusuarios identificados | Sí | Solo `postgres` ([04](evidencias/04-roles.png)) |
| 7 | Cuentas de aplicación separadas | Sí | `app_comercializadora` ([04](evidencias/04-roles.png)) |
| 8 | Privilegios mínimos | Sí | `SELECT`, `INSERT` y `UPDATE` sobre `clientes`, y tres «permission denied» ([04](evidencias/04-roles.png)) |
| 9 | Extensiones revisadas | Sí | `plpgsql` y `pgcrypto`, las dos en uso (Actividad 10) |
| 10 | TLS verificado | Sí | TLSv1.3 con `verify-full` ([05](evidencias/05-tls.png)) |
| 11 | Configuración protegida | Sí | `600`, de `postgres:postgres` ([cambios.md](configuracion/cambios.md)) |
| 12 | Directorio de datos protegido | Sí | `700`, de `postgres:postgres` ([cambios.md](configuracion/cambios.md)) |
| 13 | Firewall documentado | Parcial | Política propuesta en la Actividad 14; en Docker no aplica porque el puerto no está publicado |
| 14 | Actualizaciones documentadas | Parcial | 16.15 es la versión menor más reciente y la política está en [baseline.md](configuracion/baseline.md), pero todavía no existe un proceso de actualización |
| 15 | Configuración registrada | Sí | [cambios.md](configuracion/cambios.md), [pg_hba.conf](configuracion/pg_hba.conf) y el contenido de `postgresql.auto.conf` |
| 16 | Superusuario sin acceso por red | Sí | Rechazado por TCP aunque use TLS ([05](evidencias/05-tls.png)) |
| 17 | Conexiones sin TLS rechazadas | Sí | `sslmode=disable` rechazado con «no encryption» ([05](evidencias/05-tls.png)) |
| 18 | Solo las cuentas autorizadas se conectan a la base | Sí | `CONNECT` retirado a PUBLIC; solo `postgres` y `app_comercializadora` (Actividad 9) |
| 19 | Límites de la cuenta de aplicación | Sí | 10 conexiones y 30 segundos por consulta ([04](evidencias/04-roles.png)) |
| 20 | Límite a las transacciones inactivas | Sí | 5 minutos ([06](evidencias/06-verificacion.png)) |
| 21 | Registro de conexiones activo | Sí | `log_connections` y `log_disconnections` en `on` ([06](evidencias/06-verificacion.png)) y las líneas del log en [cambios.md](configuracion/cambios.md) |
| 22 | Cambios ensayados y reversibles | Sí | Ensayo en `dba-ensayo` y «Cómo deshacer los cambios», en [cambios.md](configuracion/cambios.md) |
| 23 | Certificado emitido por una autoridad de certificación | No | Se usa el certificado de prueba de la imagen; queda pendiente |

## Conclusiones

El servidor no tenía un problema de contraseñas: tenía reglas que no las pedían. Las seis reglas `trust`, la regla abierta a cualquier dirección y `listen_addresses = '*'` son lo que deja la instalación, y eso es lo contrario de «seguro por omisión» (sección 4.4 de la guía): todo funcionaba desde el primer día porque casi nada se comprobaba. El hardening consistió sobre todo en quitar: de siete reglas quedaron tres, de todas las interfaces quedó la local, y de un superusuario que servía para todo quedaron un superusuario que solo entra de forma local y una cuenta de aplicación con tres permisos sobre una tabla.

También quedó claro que cada capa cubre algo que las otras no cubren. `listen_addresses` decide qué interfaces aceptan conexiones; el firewall, quién llega al puerto; `pg_hba.conf`, quién se autentica, cómo y a qué base; los privilegios, qué puede hacer cada cuenta; y el sistema operativo protege los archivos que están debajo de todo. Ninguna sustituye a otra, y Docker lo muestra bien: quien puede usar `docker exec` puede actuar como cualquier usuario del contenedor, así que la seguridad de la base empieza por quién tiene acceso a la computadora.

Por último, un hardening solo sirve si se puede comprobar y repetir. Cada cambio quedó documentado con su antes y su después, se ensayó primero en `dba-ensayo`, tiene su forma de deshacerse y se verificó en el log del servidor. Quedan pendientes el certificado propio, la cuenta de consulta y retirar las tablas de práctica, que ya están anotados en cambios.md y en la línea base.

## Problemas encontrados

1. **La consulta de TLS de la guía falla.** `pg_stat_ssl` no tiene las columnas `usename` ni `client_addr`. Los scripts la unen con `pg_stat_activity` por el `pid`.
2. **El paginador de psql detenía los scripts.** En el ensayo, el script 01 se quedó esperando en el paginador a mitad de un resultado. Se agregó `\pset pager off` a los cuatro scripts.
3. **Un `\connect` fallido cierra la sesión del script.** psql solo conserva la sesión anterior en modo interactivo; en un script, un `\connect` rechazado la cierra. Por eso, en el script 04, las dos conexiones que debían rechazarse se prueban con un psql aparte (`\!`).
4. **El aviso de las reglas `hostssl`.** Mientras `ssl` seguía apagado, `pg_hba_file_rules` marcaba las reglas nuevas con «hostssl record cannot match because SSL is disabled», y la revisión de errores del script 03 se detenía. Se dejó pasar solo ese aviso, porque el mismo script enciende `ssl`.
5. **`log_connections` no cambia en una sesión abierta.** Solo aplica a las sesiones nuevas, así que un `SHOW` en la misma sesión no muestra el valor nuevo. El script 03 revisa `pg_file_settings` en su lugar.
6. **El contenedor no trae `ss` ni `netstat`.** Se usó un contenedor temporal que comparte la red de `dba-practica`.
7. **`docker cp` copió la carpeta dentro de otra en el ensayo.** Una copia con la ruta terminada en `/.`, que debía copiar solo el contenido a `/tmp/lab04`, copió la carpeta completa dentro (`/tmp/lab04/lab04`) y los archivos viejos siguieron ahí. En `dba-practica` se copió una sola vez, a un destino que todavía no existía.
8. **Dos sesiones de psql en la evidencia 01.** Una era una primera ejecución del script 01 que se quedó en pausa en otra terminal al cambiar de terminal para las capturas; después se cerró.
9. **Diferencias con la guía.** La guía nombra la carpeta `lab-04-hardening` (sección 27); se conservó el nombre del esqueleto del repositorio, `laboratorio-04-hardening`. Se agregaron tres archivos que la guía no pide: la evidencia 07, con la salida del script 03; `configuracion/pg_hba.conf`, con el archivo que quedó en el servidor; y `evidencias/evidencias-lab-04.pdf`, con las siete capturas juntas. La guía dice que no hacen falta ramas (sección 29), pero se usó una rama y un pull request, como en los laboratorios anteriores. La entrega sigue en GitHub porque el GitLab de la FIC dejó de funcionar.

## Referencias

- Guía del LAB-04, «Hardening y configuración segura de PostgreSQL»: https://academy.ficlabs.com.mx/materias/dba/unidad-02/laboratorios/laboratorio-4-hardening/
- Manual de PostgreSQL 16, «The pg_hba.conf File»: https://www.postgresql.org/docs/16/auth-pg-hba-conf.html
- Manual de PostgreSQL 16, «Trust Authentication», «Password Authentication» y «Peer Authentication»: https://www.postgresql.org/docs/16/auth-trust.html, https://www.postgresql.org/docs/16/auth-password.html y https://www.postgresql.org/docs/16/auth-peer.html
- Manual de PostgreSQL 16, «Connections and Authentication» (`listen_addresses`, `max_connections`, `superuser_reserved_connections` y `ssl`): https://www.postgresql.org/docs/16/runtime-config-connection.html
- Manual de PostgreSQL 16, «Client Connection Defaults» (`statement_timeout` e `idle_in_transaction_session_timeout`): https://www.postgresql.org/docs/16/runtime-config-client.html
- Manual de PostgreSQL 16, «Error Reporting and Logging» (`log_connections`): https://www.postgresql.org/docs/16/runtime-config-logging.html
- Manual de PostgreSQL 16, «Secure TCP/IP Connections with SSL»: https://www.postgresql.org/docs/16/ssl-tcp.html
- Manual de PostgreSQL 16, libpq, «Database Connection Control Functions» (`sslmode`) y «SSL Support»: https://www.postgresql.org/docs/16/libpq-connect.html y https://www.postgresql.org/docs/16/libpq-ssl.html
- Manual de PostgreSQL 16, «The Cumulative Statistics System» (`pg_stat_ssl`): https://www.postgresql.org/docs/16/monitoring-stats.html
- Manual de PostgreSQL 16, «Role Attributes», «CREATE ROLE» y «ALTER ROLE»: https://www.postgresql.org/docs/16/role-attributes.html, https://www.postgresql.org/docs/16/sql-createrole.html y https://www.postgresql.org/docs/16/sql-alterrole.html
- Manual de PostgreSQL 16, «ALTER SYSTEM», «pg_file_settings» y «pg_hba_file_rules»: https://www.postgresql.org/docs/16/sql-altersystem.html, https://www.postgresql.org/docs/16/view-pg-file-settings.html y https://www.postgresql.org/docs/16/view-pg-hba-file-rules.html
- Manual de PostgreSQL 16, «COPY» (`COPY ... PROGRAM`): https://www.postgresql.org/docs/16/sql-copy.html
- Manual de PostgreSQL 16, «psql» (`\connect` dentro de un script): https://www.postgresql.org/docs/16/app-psql.html
- Política de versiones de PostgreSQL: https://www.postgresql.org/support/versioning/

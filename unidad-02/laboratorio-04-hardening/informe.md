# Informe del LAB-04 — Hardening y configuración segura de PostgreSQL

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad II, tema 2.6 — Hardening de bases de datos
- Fecha: 25 de octubre de 2026

Este informe responde las preguntas de la sección 30 de la guía, el caso integral de la Actividad 18 (sección 24) y la reflexión de la sección 31. Las respuestas se apoyan en lo que se encontró y se cambió en `dba-practica`: el detalle de cada actividad está en el [README](README.md), y los comandos y la tabla de antes y después, en [cambios.md](configuracion/cambios.md).

## Preguntas del informe

### 1. ¿Cuál era la principal superficie de ataque?

El acceso a la cuenta `postgres`. Era el único rol que podía iniciar sesión, y se llegaba a ella por tres lados: desde dentro del contenedor y sin contraseña, por las reglas `trust`; desde cualquier contenedor de la red de Docker, porque el servidor escuchaba en todas las interfaces y la regla 128 aceptaba cualquier dirección; y sin cifrado, porque `ssl` estaba apagado. El puerto 5432 era lo de menos, porque cualquier escaneo lo encuentra. Lo que hacía grande la superficie es que todos los caminos llevaban a la cuenta más poderosa del servidor.

### 2. ¿Qué configuración representaba el mayor riesgo?

Las reglas `trust` de `pg_hba.conf` (líneas 117 a 126). `trust` no comprueba nada: la documentación advierte que, con ese método, quien pueda conectarse entra con el usuario que indique, incluso uno de superusuario. Así, cualquier proceso dentro del contenedor, o cualquiera con acceso a `docker exec`, era `postgres` sin escribir una contraseña. En segundo lugar estaba la regla 128 (`host all all all scram-sha-256`), que dejaba intentar la entrada a cualquier base, con cualquier usuario y desde cualquier dirección. Con las dos juntas, la seguridad del servidor dependía solo de que nadie llegara al contenedor.

### 3. ¿Qué cambio produjo la mayor reducción de exposición?

El `pg_hba.conf` nuevo. Pasó de 7 reglas a 3, quitó todas las `trust` y dejó un solo camino para cada cuenta: el superusuario, solo por el socket y con `peer`; la aplicación, solo a su base, desde el propio servidor y con TLS. Todo lo demás quedó negado. En la red, el cambio con más efecto fue `listen_addresses = 'localhost'`, que cerró el puerto para el resto de la red de Docker, pero por sí solo no habría bastado: las reglas `trust` seguían dejando entrar sin contraseña desde el propio servidor, que es justo desde donde se conectaba todo.

### 4. ¿Qué diferencia existe entre firewall y pg_hba.conf?

El firewall decide antes de que la conexión llegue a PostgreSQL y solo con la dirección y el puerto: lo que bloquea nunca llega al servidor. `pg_hba.conf` decide cuando la conexión ya llegó, pero sabe más: a qué base y con qué usuario se quiere entrar, si la conexión viene con TLS y qué método de autenticación exigir. Por ejemplo, el firewall puede dejar pasar a toda la red DBA, y solo `pg_hba.conf` puede impedir que el superusuario entre desde esa red. Además, los administran equipos distintos, así que si uno se equivoca, el otro sigue protegiendo. No son equivalentes y se usan juntos; la explicación completa está en la Actividad 14 del [README](README.md).

### 5. ¿Qué diferencia existe entre autenticación y autorización?

La autenticación comprueba quién se conecta; la autorización decide qué puede hacer ya adentro. En este laboratorio se ven por separado. En la [evidencia 05](evidencias/05-tls.png), `app_comercializadora` pasa la autenticación con SCRAM y TLS; en la [evidencia 04](evidencias/04-roles.png), con sus permisos, cuenta los clientes, pero al intentar un `DELETE`, leer `pii.mapa_cliente` o crear una tabla recibe «permission denied». Está autenticada, pero no autorizada para eso. Al revés, root ya no pasa la autenticación como `postgres` («Peer authentication failed»), así que ni siquiera llega a pedir permisos. La contraseña verifica la identidad; los privilegios deciden qué puede hacer esa identidad.

### 6. ¿Por qué una cuenta de aplicación no debe ser SUPERUSER?

Porque una aplicación comprometida tiene todo lo que tiene su cuenta, y un superusuario se salta todas las revisiones de permisos: ningún `REVOKE` lo limita. Con una inyección SQL, o con la contraseña copiada de la configuración de la aplicación, un atacante podría leer y borrar cualquier tabla de cualquier base, crear roles, ejecutar comandos del sistema operativo con `COPY ... PROGRAM` y deshacer el hardening desde SQL, ya sea cambiando parámetros con `ALTER SYSTEM` o reescribiendo `pg_hba.conf` con `COPY` y recargándolo. La aplicación también podría ocupar las conexiones reservadas para el administrador, así que si las agotara, el DBA no tendría por dónde entrar. Y en el log no se distinguiría lo que hizo la aplicación de lo que hizo el DBA. Por eso `app_comercializadora` no tiene ningún atributo administrativo y solo puede leer, insertar y actualizar en `clientes`.

### 7. ¿Por qué cambiar el puerto de PostgreSQL no constituye hardening suficiente?

Porque no cambia quién puede conectarse ni cómo se autentica: solo cambia el número de la puerta. Un escaneo de puertos encuentra el servicio en cualquier número y lo reconoce como PostgreSQL por la forma en que responde. Si en `dba-practica` solo se hubiera cambiado el 5432 por el 5433, las reglas `trust`, la regla 128 y el superusuario para todo habrían seguido igual. Cambiarlo puede quitar algo del ruido de los escaneos automáticos que solo prueban el 5432, pero obliga a que todos los clientes y las reglas del firewall conozcan el puerto nuevo, y no detiene a nadie que busque de verdad. Por eso se dejó el 5432 y se documentó (control 1 de la checklist del README).

### 8. ¿Por qué listen_addresses='*' puede ser innecesario?

Porque abre el puerto en todas las interfaces del servidor, las que tiene hoy y las que tenga después, aunque los clientes lleguen solo por una. En `dba-practica` todos los clientes estaban dentro del contenedor, así que bastaba `localhost`; con `*` también escuchaba en `172.17.0.2`, donde lo alcanzaba cualquier contenedor de la red de Docker. Ese `*` no venía de PostgreSQL, cuyo valor por omisión es `localhost`, sino de la imagen de Docker, que lo cambia para que se pueda llegar al contenedor desde fuera. El problema es que entonces basta un descuido para exponerlo: si el contenedor se hubiera creado con `-p 5432:5432`, Docker habría publicado el puerto en todas las interfaces de Windows, y PostgreSQL habría aceptado esas conexiones. `listen_addresses` debe tener solo las interfaces necesarias.

### 9. ¿Qué papel tiene el sistema operativo en la seguridad de PostgreSQL?

Es la capa sobre la que están todas las demás, y si falla, las otras no alcanzan. Primero, guarda los archivos: el directorio de datos, `pg_hba.conf` y la llave privada se protegen con los permisos del sistema (`700` y `600`), no con `GRANT`, y quien pueda leerlos se lleva los datos y los verificadores de las contraseñas sin pasar por PostgreSQL. Segundo, confirma identidades: la regla `peer` le pregunta al sistema operativo qué usuario abrió la conexión por el socket, y por eso root ya no entra como `postgres`. Tercero, el servidor corre como el usuario `postgres`, no como root, así que una falla de PostgreSQL no da el control de todo el sistema. Y cuarto, decide quién llega al servidor: en Docker, quien puede usar `docker exec` es root dentro del contenedor y puede actuar como `postgres`, así que proteger ese acceso en Windows también es parte del hardening de la base.

### 10. ¿Qué controles deberían revisarse periódicamente?

Los que pueden cambiar sin que nadie lo note: una regla agregada «para probar», un rol nuevo con más permisos de los necesarios, un certificado que vence o una versión que deja de recibir correcciones.

| Control | Cómo se revisa | Cada cuándo |
| --- | --- | --- |
| Reglas de `pg_hba.conf` | `pg_hba_file_rules`: ninguna regla `trust`, ninguna dirección `all`, `0.0.0.0/0` o `::/0`, y el superusuario solo por el socket | Cada trimestre y después de cualquier cambio |
| Interfaces y puerto | `SHOW listen_addresses;` y `netstat -lnt` | Cada trimestre y después de cambiar la red |
| Roles y atributos | `pg_roles`: superusuarios, cuentas con `LOGIN`, `CREATEROLE` o `CREATEDB`, y roles sin miembros | Cada trimestre y cuando alguien entra o sale del equipo |
| Privilegios | `datacl` de cada base e `information_schema.role_table_grants` | Cada trimestre |
| Conexiones e intentos fallidos | Las líneas `connection authorized` y los `FATAL` de autenticación en el log | Cada semana |
| Certificado TLS | Su fecha de vencimiento y `ssl_min_protocol_version` | Cada mes, y con tiempo antes de que venza |
| Versión de PostgreSQL | `SELECT version();` contra la lista de versiones de postgresql.org | Cada mes |
| Extensiones | `pg_extension` | Cada trimestre |
| Permisos de los archivos | `ls -l` del directorio de datos y de la configuración | Cada trimestre y después de restaurar un respaldo |
| Parámetros | `pg_settings` y `pg_file_settings`, contra la línea base | Cada trimestre y después de cualquier cambio |

La forma práctica de hacerlo es volver a correr [sql/01-inspeccion.sql](sql/01-inspeccion.sql) y [sql/04-verificacion.sql](sql/04-verificacion.sql) y comparar el resultado con la [línea base](configuracion/baseline.md). Cualquier diferencia es un cambio que debería estar en `cambios.md`; si no está, hay que averiguar quién lo hizo y por qué.

## Caso integral (Actividad 18)

En el escenario, PostgreSQL acepta conexiones de cualquier dirección IPv4 y escucha en todas las interfaces, el firewall permite el 5432 desde cualquier origen, `pg_hba.conf` permite all/all desde `0.0.0.0/0` y la aplicación web se conecta con un usuario administrativo. El administrador dice que no hay problema porque todas las contraseñas son fuertes.

| # | Problema | Riesgo | Control propuesto |
| --- | --- | --- | --- |
| 1 | El firewall permite el 5432 desde cualquier origen | Cualquier equipo de Internet puede intentar conectarse, y nada filtra antes de PostgreSQL | Permitir el 5432 solo desde el servidor de la aplicación y la red DBA, y negar todo lo demás por omisión (Actividad 14) |
| 2 | El servidor escucha en todas las interfaces | Si el servidor tiene una interfaz pública, el puerto queda abierto en ella, y también en cualquier interfaz que se agregue después | `listen_addresses` solo con la dirección privada por la que llega la aplicación, o `localhost` si está en el mismo servidor |
| 3 | `pg_hba.conf` permite all/all desde `0.0.0.0/0` | Cualquier usuario puede intentar entrar a cualquier base desde cualquier dirección, y no hay forma de saber qué conexión es legítima | Una regla por cliente, con su base, su usuario, su dirección `/32` y su método (Actividad 6) |
| 4 | El superusuario puede entrar por la red | La cuenta más valiosa queda expuesta a Internet; con su contraseña se tiene todo el servidor | Superusuario solo por el socket local con `peer`, sin ninguna regla de red |
| 5 | La aplicación usa un usuario con privilegios administrativos | Una inyección SQL o un error de la aplicación tiene los permisos del administrador: borrar tablas, crear roles o ejecutar comandos del sistema | Una cuenta de aplicación sin atributos administrativos y con permisos solo sobre las tablas que usa (Actividad 9) |
| 6 | La contraseña administrativa está en la configuración de la aplicación | Quien lea ese archivo, en el servidor, en un respaldo o en un repositorio, obtiene el control de la base | Una credencial propia de la aplicación, guardada en un gestor de secretos y nunca en el código |
| 7 | La aplicación y los administradores no tienen cuentas separadas | No se sabe quién hizo cada cambio, y cambiar la contraseña obliga a cambiarla en la aplicación | Cuentas personales para los DBA y una cuenta por aplicación |
| 8 | El escenario no menciona TLS | Las consultas y los resultados, con datos de clientes, viajarían por Internet sin cifrar, y un servidor falso podría hacerse pasar por el real | `ssl = on`, reglas `hostssl` y clientes con `sslmode=verify-full`, con un certificado de una autoridad de confianza (Actividad 15) |
| 9 | No hay límite de intentos | PostgreSQL no bloquea una cuenta después de varios intentos fallidos, así que se pueden probar contraseñas sin parar; una contraseña fuerte solo hace que tarde más | Cerrar el puerto a quien no lo necesita y, como apoyo, el módulo `auth_delay`, que hace esperar al servidor antes de responder a un intento fallido |
| 10 | No se menciona el monitoreo | Un ataque de fuerza bruta o un acceso indebido pasaría sin que nadie se entere | `log_connections` y `log_disconnections` en `on`, y revisar los rechazos del log (pregunta 10) |
| 11 | No se mencionan límites de conexiones ni de tiempo | Una falla de la aplicación o un ataque puede agotar las conexiones y dejar sin servicio a todos, incluso al DBA si la aplicación es superusuario | `CONNECTION LIMIT` y `statement_timeout` para la cuenta de la aplicación, e `idle_in_transaction_session_timeout` (Actividad 11) |
| 12 | Toda la seguridad depende de una sola capa, las contraseñas | Si una contraseña se filtra, se adivina o no hace falta, como en una inyección SQL, no queda ninguna otra barrera | Defensa en profundidad: red, autenticación, autorización, configuración, sistema operativo y monitoreo (siguiente apartado) |

### ¿Es suficiente tener contraseñas fuertes?

No. Una contraseña fuerte solo resuelve una parte de la autenticación: hace más difícil adivinarla. No sirve si la contraseña se roba, no limita lo que hace quien la tiene y no evita que el ataque llegue al servidor. Cada capa cubre algo distinto:

- **Autenticación:** además de contraseñas fuertes, el método correcto (`scram-sha-256`, nunca `trust`), un solo camino de entrada para cada cuenta y el superusuario solo por el socket, con `peer`.
- **Autorización:** una cuenta por aplicación, con el mínimo privilegio. Una inyección SQL usa la sesión que la aplicación ya abrió, así que no necesita la contraseña; lo único que la frena son los permisos de la cuenta.
- **Red:** el firewall y `listen_addresses` hacen que el ataque ni siquiera llegue al puerto, y `pg_hba.conf` limita desde dónde entra cada cuenta. Sin esto, cualquiera en Internet puede probar contraseñas sin límite.
- **Configuración:** TLS obligatorio, para que nadie lea el tráfico; límites de conexiones y de tiempo, para proteger la disponibilidad; y cada cambio documentado.
- **Sistema operativo:** quien lea el directorio de datos se lleva las tablas y los verificadores de las contraseñas sin pasar por la autenticación. Por eso importan los permisos `700` y `600` y el control de quién entra al servidor.
- **Monitoreo:** el registro de conexiones muestra los intentos fallidos y los accesos raros. Sin él, nadie se entera de que la contraseña está siendo atacada, ni de cuándo cedió.

En este laboratorio se ve con `app_comercializadora`. Su contraseña está guardada como SCRAM, pero además la cuenta solo entra a una base, solo desde el propio servidor y solo con TLS, tiene 10 conexiones como máximo y no puede borrar. Aunque alguien obtuviera la contraseña, tendría que estar dentro del servidor para usarla, lo más que podría hacer es leer, insertar y actualizar clientes, y cada conexión quedaría en el log.

## Reflexión

**¿Qué cambiarías primero si recibieras la responsabilidad de asegurar un servidor PostgreSQL que ya se encuentra funcionando en producción?**

Lo primero que cambiaría es `pg_hba.conf`, para quitar las reglas `trust` y las que aceptan cualquier dirección. Pero no lo haría a ciegas: antes encendería `log_connections` unos días para saber quién se conecta de verdad, desde dónde, a qué base y con qué usuario. Ese paso previo no tiene riesgo, porque se aplica con una recarga y no le cambia nada a nadie.

- **Riesgo y exposición.** En este laboratorio, el mayor riesgo estaba en `pg_hba.conf`: las reglas `trust` dejaban entrar sin contraseña, y la regla abierta exponía todas las cuentas a cualquier dirección. Es el cambio que más reduce la exposición de una sola vez.
- **Autenticación.** Quitar `trust` obliga a que toda conexión demuestre quién es. Mientras se pueda entrar sin contraseña, ningún otro control sirve de mucho.
- **Privilegios.** La cuenta más expuesta es el superusuario. Con las reglas nuevas, `postgres` solo entraría por el socket local o desde los orígenes que aparecieron en el log, mientras se crea la cuenta propia de la aplicación.
- **Impacto, disponibilidad y continuidad.** `pg_hba.conf` se aplica con una recarga, sin reiniciar el servidor y sin cortar las sesiones abiertas: solo afecta a las conexiones nuevas. Antes de recargar se revisa `pg_hba_file_rules` para confirmar que el archivo no tiene errores, y se guarda una copia del original. Si un cliente legítimo se queda fuera, el log lo dice («no pg_hba.conf entry for host…») y se corrige en segundos, agregando su regla o restaurando la copia. Además, se ensaya primero en un servidor de prueba, como se hizo con `dba-ensayo`.
- **Red.** Los cambios de red reducen la exposición, pero no arreglan la autenticación y cuestan más: `listen_addresses` requiere reiniciar, así que necesita una ventana de mantenimiento, y el firewall normalmente lo administra otro equipo. Los dejaría para después, cuando el log ya diga qué orígenes hay que permitir.

Los demás cambios irían después porque dependen de este o tienen más impacto. La cuenta de aplicación obliga a cambiar la configuración de la aplicación y a probarla. Encender `ssl` se puede hacer con una recarga, pero hacerlo obligatorio requiere un certificado real y que todos los clientes estén listos para usarlo. `listen_addresses` necesita un reinicio, y el firewall, a otro equipo. Cambiar el puerto no estaría en la lista.

En el laboratorio el orden fue otro: la cuenta de aplicación se creó primero, porque no había una aplicación real que migrar y el `pg_hba.conf` nuevo solo dejaba entrar a esa cuenta. En producción, primero se cierra la puerta con reglas de transición que no rompan lo que ya funciona, y después se mueve la aplicación a su propia cuenta.

## Referencias

- Guía del LAB-04, secciones 24, 30 y 31: https://academy.ficlabs.com.mx/materias/dba/unidad-02/laboratorios/laboratorio-4-hardening/
- Manual de PostgreSQL 16, «The pg_hba.conf File» y «Trust Authentication»: https://www.postgresql.org/docs/16/auth-pg-hba-conf.html y https://www.postgresql.org/docs/16/auth-trust.html
- Manual de PostgreSQL 16, «Role Attributes» y «COPY»: https://www.postgresql.org/docs/16/role-attributes.html y https://www.postgresql.org/docs/16/sql-copy.html
- Manual de PostgreSQL 16, «Connections and Authentication» (`listen_addresses` y `ssl`): https://www.postgresql.org/docs/16/runtime-config-connection.html
- Manual de PostgreSQL 16, «Error Reporting and Logging» (`log_connections`): https://www.postgresql.org/docs/16/runtime-config-logging.html
- Manual de PostgreSQL 16, «auth_delay»: https://www.postgresql.org/docs/16/auth-delay.html
- Manual de PostgreSQL 16, «The PostgreSQL User Account»: https://www.postgresql.org/docs/16/postgres-user.html
- Manual de PostgreSQL 16, «pg_hba_file_rules»: https://www.postgresql.org/docs/16/view-pg-hba-file-rules.html
- Política de versiones de PostgreSQL: https://www.postgresql.org/support/versioning/

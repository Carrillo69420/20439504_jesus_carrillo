# Laboratorio 02 — Cifrado y credenciales

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad II, tema 2.4 — Cifrado, credenciales y protección de las comunicaciones
- Entorno: PostgreSQL 16.15 en Docker (contenedor `dba-practica` con la base `comercializadora`, y el contenedor desechable `dba-tls`) y el servidor PostgreSQL de la FIC, a través de pgAdmin
- Fechas: 15 y 16 de octubre de 2026

Este README es el informe final del laboratorio (sección 22 de la guía), con las preguntas de reflexión de la sección 23 al final. Los comandos y los resultados completos de cada actividad están en `evidencias/`.

## 1. Introducción

Después del LAB-01, la empresa ficticia Comercializadora Norte S.A. de C.V. ya controla quién ve qué en la base `comercializadora`: soporte consulta datos enmascarados, analítica trabaja con datos seudonimizados y ninguno de los dos puede leer la tabla `clientes`. Sin embargo, como plantea la sección 1 de la guía, una base de datos con el control de acceso bien configurado todavía puede exponer información sensible si guarda mal las contraseñas, si guarda los datos sensibles sin protección, si sus conexiones no usan cifrado, si sus respaldos no están protegidos o si las claves y las credenciales quedan junto a los datos, en scripts o en repositorios.

Este laboratorio atiende las tres necesidades del escenario de la sección 5: que una contraseña no se pueda recuperar desde la base, que los datos sensibles no queden en texto claro y que la información viaje protegida por la red. Para cada una se probó en PostgreSQL el mecanismo que le corresponde (hash, cifrado y TLS). Además, se revisó dónde quedan copiadas las claves de cifrado, se analizaron un escenario de riesgo y una política para proteger las claves y, antes del commit final, se buscaron secretos en todo el repositorio.

## 2. Protección de credenciales

Script: [sql/01-credenciales.sql](sql/01-credenciales.sql) · Evidencia: [evidencias/01-credenciales.md](evidencias/01-credenciales.md), con capturas en [evidencias/01-credenciales.pdf](evidencias/01-credenciales.pdf)

Un dato se puede guardar de tres formas, y cada una sirve para algo distinto:

| Forma | Qué se guarda | ¿Se recupera el original? | Cuándo se usa | En el laboratorio |
|---|---|---|---|---|
| Texto claro | El dato tal cual. | No hace falta: lo lee cualquiera que consulte la tabla. | Nunca para contraseñas ni datos sensibles. | `usuarios_insegura` devolvió `Password123`. |
| Hash | Un valor calculado a partir del dato. | No, solo se puede comparar. | Cuando solo hay que verificar el dato, como una contraseña. | `crypt()` con `gen_salt('bf')` (bcrypt) en `usuarios_segura`. |
| Cifrado | El dato transformado con una clave. | Sí, con la clave correcta. | Cuando hay que volver a leer el dato, como el RFC. | `pgp_sym_encrypt()` en la Actividad 2. |

En la Actividad 1 se vio la diferencia. En `usuarios_insegura`, un `SELECT` devolvió la contraseña tal cual. En `usuarios_segura` solo quedó un hash de 60 caracteres que empieza con `$2a$06$`: `$2a$` indica bcrypt, `06` es el costo y los 22 caracteres siguientes son una sal aleatoria. Por esa sal, la misma contraseña dio un hash distinto cada vez, así que dos usuarios con la misma contraseña no tienen el mismo hash. Aun así, la contraseña se pudo verificar sin recuperarla: `crypt()` con el hash guardado devolvió `t` con `Password123` y `f` con `OtraPassword`.

Por eso una contraseña no se cifra, sino que se protege con un mecanismo de derivación de claves para contraseñas, como bcrypt, Argon2id o scrypt. Si se cifrara, quien obtuviera la clave las recuperaría todas. Aquí se usó pgcrypto con fines didácticos; en una aplicación real el algoritmo se elige según las recomendaciones actuales y lo que ofrezca el framework, sin implementar uno propio (sección 7.6 de la guía).

## 3. Protección de datos sensibles

Script: [sql/02-cifrado-datos.sql](sql/02-cifrado-datos.sql) · Evidencia: [evidencias/02-cifrado-datos.md](evidencias/02-cifrado-datos.md), con capturas en [evidencias/02-cifrado-datos.pdf](evidencias/02-cifrado-datos.pdf)

Se protegió el RFC de Ana López en la tabla de demostración `clientes_protegidos`. El RFC es un identificador fiscal único y además revela datos de la persona, porque se arma con letras de los apellidos y el nombre, más la fecha de nacimiento; en la clasificación del LAB-01 quedó en nivel alto. A diferencia de una contraseña, el RFC sí hay que volver a leerlo, por ejemplo para facturar, así que un hash no sirve. Por eso se cifró con `pgp_sym_encrypt()` y la clave de laboratorio `'CLAVE-DE-PRUEBA'`, que es ficticia.

Lo que se comprobó:

- En la tabla, el RFC ya no se puede leer: la columna `rfc_cifrado` solo muestra 79 bytes en hexadecimal.
- Con la clave correcta, `pgp_sym_decrypt()` regresó `LOPA900101ABC`.
- Con `'CLAVE-INCORRECTA'`, la consulta falló con `Wrong key or corrupt data` y no mostró ni una parte del RFC.

El cifrado es distinto de las técnicas del LAB-01. El enmascaramiento oculta parte del dato al mostrarlo, pero en la tabla sigue completo. La seudonimización cambia el identificador por un token y guarda aparte el mapa que permite volver a la persona. El cifrado, en cambio, transforma el dato guardado, y solo quien tenga la clave lo puede leer.

Este cifrado tiene dos límites. Primero, protege el dato guardado, pero no su viaje: pgcrypto cifra dentro del servidor, así que el RFC y la clave viajan dentro de la consulta, y la conexión necesita TLS (apartado 4). Segundo, depende por completo de la clave: si la clave se expone, el cifrado deja de proteger (apartado 5).

## 4. TLS

Script: [sql/03-verificacion-tls.sql](sql/03-verificacion-tls.sql) · Evidencia: [evidencias/04-tls.md](evidencias/04-tls.md)

**Qué problema resuelve.** Sin TLS, las consultas y sus resultados viajan legibles por la red: quien pueda observar el tráfico ve los datos que regresa un `SELECT`, y podría modificarlos en el camino. TLS cifra la conexión (confidencialidad) y detecta cualquier cambio (integridad). Si además el cliente verifica el certificado del servidor, comprueba que se está conectando al servidor correcto y no a un intermediario (autenticación).

**Qué se verificó.** En el servidor de la FIC se revisaron, desde el Query Tool de pgAdmin, la configuración del servidor y la sesión actual (Actividad 5). Después se probó con psql cómo se conecta cada `sslmode` cuando el servidor tiene TLS apagado y cuando lo tiene encendido (Actividad 6 y sección 13):

| Servidor | `ssl` | Cliente | Resultado |
|---|---|---|---|
| PostgreSQL de la FIC | `off` | pgAdmin, con `prefer` | Se conectó sin TLS y sin avisar: `pg_stat_ssl` marcó `ssl = false`, sin versión ni algoritmo. |
| `dba-practica` | `off` | psql, con `require` | No se conectó: `server does not support SSL, but SSL was required`. |
| `dba-practica` | `off` | psql, con `prefer` | Se conectó sin TLS (`f`), igual que pgAdmin en la FIC. |
| `dba-tls` | `on` | psql, con `require` | Se conectó cifrado, con `TLSv1.3` y `TLS_AES_256_GCM_SHA384`. |
| `dba-tls` | `on` | psql, con `verify-full` | No se conectó: el cliente no tenía un certificado raíz (`root.crt`) para validar el del servidor. |

En la FIC también se vio que el servidor escucha en el puerto 5432 y en todas sus direcciones (`listen_addresses = *`), y que la sesión llega desde `172.18.0.3`, una dirección privada de la red interna de la FIC. La página de pgAdmin abre por HTTPS, pero ese cifrado es del navegador al sitio web y no cubre la conexión de pgAdmin con PostgreSQL, que es la que mide `pg_stat_ssl`. El valor de `ssl_min_protocol_version` no se pudo ver, porque la cuenta del alumno no tiene el privilegio necesario (error 42501); en `dba-tls` es `TLSv1.2`.

**Conclusión.** Pedir TLS no basta. `prefer` puede quedarse sin cifrar sin avisar, `require` cifra pero acepta el certificado sin validarlo, y solo `verify-full` comprueba el cifrado y la identidad del servidor, siempre que el cliente confíe en el certificado. El de `dba-tls` es un certificado de prueba autofirmado (`CN=localhost`) que viene en la imagen de Docker, junto con su llave privada, así que lo tiene cualquiera que use esa imagen: sirve para practicar, no para un servidor real. Para proteger la conexión de la FIC haría falta encender TLS en el servidor (`ssl = on`), conectar pgAdmin con `verify-full`, o al menos con `require`, y usar reglas `hostssl` en `pg_hba.conf` para que el servidor rechace las conexiones sin TLS.

## 5. Gestión de claves

Evidencias: [evidencias/03-gestion-claves.md](evidencias/03-gestion-claves.md) y [evidencias/10-politica-claves.md](evidencias/10-politica-claves.md)

Un dato cifrado está tan seguro como su clave. Quien tenga la clave y una copia de la tabla o de un respaldo puede descifrarlo todo, sin importar qué tan bueno sea el algoritmo. Por eso las claves no deben guardarse junto con los scripts que las usan:

- **Los scripts se copian.** Se suben a Git, se comparten y se respaldan. En la Actividad 3, Git ya mostraba el archivo de mala práctica como nuevo (`??`), y como la sección 21 de la guía usa `git add .`, un commit más lo habría subido al historial. Una vez en el historial, borrar el archivo después ya no lo quita, y cada clon tiene su copia.
- **La clave no se queda en el script.** Al ejecutar las consultas de la Actividad 2, la clave quedó en el registro de psql (`-L`) y en su historial, y el log del servidor guardó completa la consulta que falló, con la clave que llevaba. Son archivos que nadie pensó para guardar secretos y que pueden leer administradores, respaldos y herramientas de monitoreo.
- **Se pierde la separación de funciones.** Si la clave está en el código, quien tenga acceso al código o a la base ya tiene todo lo necesario para descifrar los datos. Separarla permite aplicar lo mismo que en el LAB-01: quien administra la base no necesita conocer las claves.

En un entorno real, la clave se guarda en un gestor de secretos o en un servicio de administración de claves, separada de los datos, y solo la obtiene la aplicación que la usa. La política de la Actividad 10 lo define en nueve reglas: generación, almacenamiento, acceso, uso y transmisión, rotación, respaldo, revocación, exposición accidental y eliminación. Si una clave real llega a exponerse, se da por comprometida: se genera otra, se vuelven a cifrar los datos y se revoca la anterior.

En este laboratorio, las únicas claves de cifrado son las ficticias de la guía, `'CLAVE-DE-PRUEBA'` y `'CLAVE-INCORRECTA'`, porque la Actividad 2 las pide así y la sección 25 lo permite solo con claves exclusivamente de laboratorio. El archivo de mala práctica se borró antes de cualquier commit, y `git log --all` confirma que no está en el historial.

### Revisión de secretos antes del commit (Actividad 9)

Antes del commit final se revisaron todos los archivos del repositorio, como piden la sección 16 de la guía y la sección «Seguridad del repositorio» del README de la raíz. En lugar del `grep -R` que sugiere la guía se usó `git grep`, que busca en los archivos del repositorio sin entrar a la carpeta `.git` y que, con `--untracked`, incluye los que todavía no tienen commit, como la 07, la 08 y la 10. Las dos búsquedas se hicieron sin distinguir mayúsculas (`-i`) y saltando los archivos binarios (`-I`). El repositorio no tiene archivos ignorados ni archivos `.env`, así que ningún archivo de texto quedó fuera de la revisión.

**Primera búsqueda: las expresiones de la sección 16.** Se buscó cualquiera de las palabras password, passwd, secret, token, api_key o clave seguida de un signo igual (o de dos puntos, en el caso de password), aunque hubiera espacios antes del signo, y también las cadenas de conexión de PostgreSQL. No encontró nada: ningún archivo tiene una de esas asignaciones ni una cadena de conexión.

**Segunda búsqueda: la búsqueda amplia de la guía**, solo con las palabras. Encontró 175 renglones en 12 archivos, antes de que existiera este apartado. Se revisaron las palabras que encontró, y ninguna corresponde a un secreto real:

- palabras de las explicaciones, como «clave», «secretos» o «token»;
- nombres de columnas: `password` y `password_hash` en `sql/01-credenciales.sql`, y `token` en la seudonimización del LAB-01;
- los valores ficticios de la guía: las contraseñas `Password123` y `OtraPassword` y las claves `'CLAVE-DE-PRUEBA'` y `'CLAVE-INCORRECTA'`, que la sección 25 permite porque son exclusivamente de laboratorio;
- la sección «Seguridad del repositorio» del README de la raíz, que enumera lo que nunca debe subirse, como tokens, claves privadas y archivos `.env`.

**Lo que la búsqueda no cubre.** Por `-I`, no revisó los siete PDF de capturas, que son del LAB-01 y de las Actividades 1 y 2 y ya estaban en el historial. Todo lo que agrega el commit final es texto, así que eso sí quedó revisado completo. Tampoco encuentra un secreto que no lleve ninguna de esas palabras. En `sql/02-cifrado-datos.sql`, la búsqueda amplia encontró la clave solo porque se llama `'CLAVE-DE-PRUEBA'`: una clave real escrita en `pgp_sym_encrypt()` no llevaría ninguna de esas palabras, y ninguna de las dos búsquedas la encontraría. Como dice la guía, el objetivo no es detectar todos los secretos, sino tener el hábito de revisar antes de publicar. En un proyecto real, esta revisión se complementa con herramientas que reconocen los secretos por su formato y revisan cada commit de forma automática.

## 6. Resultados

| Actividad | Resultado principal | Archivos |
|---|---|---|
| 1. Credenciales | `usuarios_insegura` mostró `Password123` tal cual. Con bcrypt, la misma contraseña dio un hash distinto cada vez, y la verificación devolvió `t` con la correcta y `f` con la incorrecta. | [01-credenciales.sql](sql/01-credenciales.sql), [01-credenciales.md](evidencias/01-credenciales.md) |
| 2. Cifrado del RFC | El RFC quedó como 79 bytes ilegibles. Con la clave correcta se recuperó, y con la incorrecta el descifrado falló sin mostrar nada. | [02-cifrado-datos.sql](sql/02-cifrado-datos.sql), [02-cifrado-datos.md](evidencias/02-cifrado-datos.md) |
| 3. Gestión de claves | Una clave escrita en las consultas quedó copiada en el script, en el registro y el historial de psql y, en la consulta que falló, en el log del servidor. El archivo de mala práctica se borró antes de cualquier commit. | [03-gestion-claves.md](evidencias/03-gestion-claves.md) |
| 4 a 6. TLS | La conexión de pgAdmin con el servidor de la FIC no usa TLS (`ssl = off` y `prefer`). En Docker, `require` cifró con TLSv1.3 cuando el servidor tenía TLS encendido, y `verify-full` no se conectó sin un certificado raíz. | [03-verificacion-tls.sql](sql/03-verificacion-tls.sql), [04-tls.md](evidencias/04-tls.md) |
| 7. Comparación | La contraseña, el RFC y el respaldo se protegen en reposo, la consulta en tránsito y la clave en ambos. Una protección no cubre a la otra. | [07-comparacion.md](evidencias/07-comparacion.md) |
| 8. Escenario | Los cinco problemas del escenario ya habían aparecido en el laboratorio. El más crítico es guardar contraseñas en texto claro, y tener bien configurados los permisos no elimina esos riesgos. | [08-analisis-escenario.md](evidencias/08-analisis-escenario.md) |
| 9. Revisión de secretos | Las expresiones de la sección 16 no aparecen en ningún archivo. La búsqueda amplia dio 175 renglones en 12 archivos, todos de explicaciones, nombres de columnas, valores ficticios de la guía y la lista de lo que no se sube. | Apartado 5, «Revisión de secretos antes del commit» |
| 10. Política de claves | Nueve reglas, cada una ligada a algo que se observó en el laboratorio. | [10-politica-claves.md](evidencias/10-politica-claves.md) |

## 7. Problemas encontrados

1. **Una consulta que no se ejecutó.** En la Actividad 1, `SELECT * FROM clientes;` iba en el mismo bloque, justo después de `\d clientes`, y psql tomó sus palabras como argumentos de `\d` (`\d: extra argument "SELECT" ignored`). La estructura de la tabla sí se verificó, y esa consulta era opcional. Desde entonces, cada comando de psql que empieza con `\` se pegó solo, en su propio bloque.
2. **El RFC cifrado no cabía en la ventana.** En hexadecimal ocupa 160 caracteres, así que antes de consultarlo se activó `\pset format wrapped`, que lo parte dentro de su columna.
3. **El registro de psql no guarda los errores.** `psql -L` guarda las consultas y sus resultados, pero no los mensajes de error. Errores como `Wrong key or corrupt data` se comprobaron en el log del servidor, con `docker logs`.
4. **Un permiso que la cuenta de la FIC no tiene.** `SHOW ssl_min_protocol_version` falló con el error 42501, porque la cuenta del alumno no es superusuario ni tiene el rol `pg_read_all_settings`. Ese valor solo se pudo ver en Docker.
5. **Detalles de pgAdmin.** Al principio se abrieron las Properties de la base en lugar de las del servidor. Las dos tienen una pestaña Parameters, pero el SSL mode solo está en la del servidor. Además, el Query Tool solo muestra el resultado de la última consulta, así que las consultas se ejecutaron una por una. Cuando una falla, pgAdmin cambia a la pestaña Messages y la barra de estado conserva el «Total rows» de la consulta anterior, lo que puede confundir.
6. **Sin psql hacia el servidor de la FIC.** La Actividad 6 pide conectarse con psql «si tienes acceso a psql». El pgAdmin de la FIC no ofrece el PSQL Tool, que viene desactivado por omisión cuando pgAdmin funciona como servidor web, y el host que usa, `postgres-server`, es un nombre interno que la PC no encuentra (`ping`). Por eso la Actividad 6 se hizo en Docker.
7. **Docker no tenía TLS.** `dba-practica` tiene `ssl = off`, así que con `require` no había conexión cifrada que analizar. Para verla se creó `dba-tls`, un contenedor desechable con el certificado de prueba que trae la imagen, que se borró solo al detenerlo. Ahí `verify-full` falló porque el cliente no tenía ningún certificado raíz con el cual validar el del servidor; para que conectara habría que indicarle en cuál confiar con `sslrootcert`.
8. **El GitLab de la FIC dejó de funcionar.** El 14/10/2026 respondía con el error 502, así que, por indicación del profesor, la entrega se hace en un repositorio de GitHub.

## 8. Conclusiones

**Lo que se aprendió.** Cada mecanismo protege algo distinto, y ninguno sustituye a otro: el hash protege las contraseñas, el cifrado protege los datos que hay que volver a leer, TLS protege la información mientras viaja y la gestión de claves sostiene al cifrado. Tampoco sustituyen al control de acceso del LAB-01, ni el control de acceso los sustituye a ellos. Además, muchos riesgos no están en las tablas, sino alrededor de la base: en los logs, en el historial de psql, en Git y en la conexión. La sesión de la FIC es un ejemplo: la cuenta del alumno tiene permisos limitados y, aun así, su conexión viaja sin cifrar.

**Medidas para un entorno productivo.**

1. Proteger las contraseñas con un mecanismo de derivación de claves (bcrypt, Argon2id o scrypt), con el que ofrezca el framework de la aplicación, y nunca guardarlas en texto claro ni cifradas.
2. Cifrar las columnas sensibles que haya que volver a leer, de preferencia desde la aplicación y guardando en cada fila la versión de la clave con que se cifró. Por ejemplo, el RFC de la tabla `clientes` del LAB-01, que todavía está legible.
3. Guardar las claves en un gestor de secretos, con acceso solo para la aplicación que las usa, y con rotación, respaldo y revocación definidos, como en la política de la Actividad 10.
4. Encender TLS en todos los servidores, con un certificado firmado por una autoridad de confianza, conectar los clientes con `sslmode=verify-full` y usar solo reglas `hostssl` en `pg_hba.conf` para las conexiones por red.
5. No escribir claves ni contraseñas dentro de las consultas, y proteger el historial de psql y los logs del servidor como información sensible.
6. Buscar secretos antes de cada commit, agregar los archivos por nombre y revocar de inmediato cualquier clave que se exponga.
7. Cifrar los respaldos con su propia clave, guardada aparte, y probar periódicamente que se pueden restaurar.

## 9. Preguntas de reflexión

1. **¿Por qué una contraseña no debe almacenarse como texto claro?** Porque cualquiera que lea la tabla, un respaldo o un log la ve tal cual y puede entrar como ese usuario de inmediato. En la Actividad 1 bastó un `SELECT` a `usuarios_insegura` para ver `Password123`. Como mucha gente repite sus contraseñas, el daño llega también a otros servicios, y ni siquiera hace falta guardarla: para verificarla basta su hash.
2. **¿Por qué un hash no es equivalente a un cifrado?** Porque el cifrado se revierte con la clave y el hash no: no existe una clave ni una función para regresar de `$2a$06$…` a `Password123`. El hash sirve para comprobar un dato, como una contraseña, y el cifrado para volver a leerlo, como el RFC. Si las contraseñas se cifraran, quien obtuviera la clave las recuperaría todas.
3. **¿Por qué el cifrado de una columna no sustituye al control de acceso?** Porque el cifrado protege el dato cuando alguien obtiene la tabla o un respaldo sin la clave, pero no decide quién puede consultar, modificar o borrar las filas. Quien tenga la clave y acceso a la tabla ve el RFC completo, así que los permisos tienen que limitar quién llega a la tabla y quién recibe la clave. Además, el cifrado solo cubre esa columna: en `clientes_protegidos`, el nombre de Ana López sigue legible.
4. **¿Por qué TLS no sustituye a los mecanismos de autorización de PostgreSQL?** Porque TLS protege el camino, no lo que el usuario puede hacer al llegar: un usuario con demasiados permisos lee todo a través de una conexión cifrada. Lo que puede consultar cada quien lo deciden los roles y los permisos, como los «permission denied» que recibieron `soporte` y `analista` en el LAB-01. En la FIC se vio el caso contrario: la cuenta del alumno tiene permisos limitados (error 42501), pero su sesión viaja sin TLS. Se necesitan los dos.
5. **¿Qué ocurriría si una organización pierde una clave utilizada para cifrar información?** Perdería los datos cifrados con ella, también los de los respaldos, porque no hay otra forma de descifrarlos. En la Actividad 2, con `'CLAVE-INCORRECTA'` PostgreSQL respondió `Wrong key or corrupt data` y no entregó ni una parte del RFC; sin la clave, todos los RFC quedarían así. Por eso las claves se respaldan cifradas, en un lugar distinto de los respaldos de la base, y se prueba que se pueden recuperar.
6. **¿Qué ocurriría si una clave criptográfica se publica accidentalmente en GitLab?** Cualquiera con acceso al repositorio podría descifrar todo lo que esa clave protege, en la base y en cualquier respaldo. Borrar el archivo en otro commit no lo arregla, porque el historial lo conserva y cada clon ya tiene una copia. Hay que dar la clave por comprometida: generar otra, volver a cifrar los datos, revocar la anterior y documentar el incidente.
7. **¿Por qué un repositorio privado no debe considerarse un almacén de secretos?** Porque privado solo significa que lo ven menos personas: todas las que tienen acceso ven el secreto, y cada clon lo copia a otra computadora con todo su historial. Git no limita el acceso por archivo ni sabe rotar o revocar una clave, y si el repositorio se vuelve público o una cuenta se compromete, el secreto se filtra. Este mismo repositorio pasó del GitLab de la FIC a GitHub, así que un secreto que hubiera tenido antes de la mudanza ahora estaría en los dos servidores. Como dice la sección 18 de la guía, un repositorio privado reduce la exposición, pero no vuelve apropiado guardar un secreto en el código.
8. **¿Qué diferencia existe entre proteger información almacenada y proteger información durante su transmisión?** La información almacenada se protege mientras está guardada en tablas, archivos o respaldos, con hash para las contraseñas y cifrado para datos como el RFC. La información en transmisión se protege mientras viaja entre el cliente y el servidor, con TLS. Una protección no cubre a la otra: TLS solo cifra la conexión, y al llegar los datos se guardan como vengan; y pgcrypto cifra dentro del servidor, así que en la FIC, con `ssl = off`, el RFC y la clave viajarían legibles dentro de la consulta (Actividad 7).
9. **¿Por qué la gestión de claves es tan importante como el algoritmo criptográfico?** Porque un algoritmo fuerte no sirve si la clave se expone o se pierde: quien la tenga descifra todo, y quien la pierda pierde los datos. En la Actividad 3, sin romper ningún algoritmo, una clave escrita en las consultas quedó copiada en el script, en el registro y el historial de psql y en el log del servidor. Un dato cifrado solo está tan seguro como su clave.
10. **¿Qué mecanismo adicional implementarías en una organización para proteger los respaldos de las bases de datos?** Cifrar cada respaldo antes de guardarlo o copiarlo, con una clave propia guardada en un gestor de secretos y nunca junto al respaldo. Además, limitar quién puede leerlo y restaurarlo, guardar una copia en otro lugar y probar periódicamente que se puede restaurar. También conviene darle un plazo de conservación, porque un respaldo guardado para siempre conserva datos que ya se debieron eliminar, como se vio con la retención en el LAB-01.

## Referencias

- PostgreSQL 16, «F.28. pgcrypto — cryptographic functions», sección F.28.6.3 «Security Limitations»: https://www.postgresql.org/docs/16/pgcrypto.html
- PostgreSQL 16, «34.19. SSL Support», sección 34.19.3 «Protection Provided in Different Modes»: https://www.postgresql.org/docs/16/libpq-ssl.html
- pgAdmin 4, «PSQL Tool»: https://www.pgadmin.org/docs/pgadmin4/latest/psql_tool.html

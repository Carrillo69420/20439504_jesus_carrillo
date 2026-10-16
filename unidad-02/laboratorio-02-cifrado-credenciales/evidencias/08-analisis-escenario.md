# Evidencia 08 — Análisis de un escenario de seguridad

LAB-02, Actividad 8 (sección 15 de la guía). No tiene script: el análisis se apoya en lo que se comprobó en las Actividades 1 a 7 y en el LAB-01.

## Objetivo

Identificar los riesgos de una base de datos que tiene bien configurados sus usuarios y roles, pero que tiene estos problemas:

- guarda contraseñas y datos sensibles en texto claro;
- se conecta sin validar al servidor;
- deja las claves en archivos SQL;
- no protege sus respaldos.

Además, proponer un mecanismo para cada elemento que guarda y explicar por qué los permisos no bastan.

## Comando o procedimiento

No se ejecutaron comandos nuevos. Cada problema del escenario de la sección 15 se comparó con lo que ya se había comprobado en este laboratorio. Para la pregunta 4 se usaron también los roles y permisos del LAB-01.

## Resultado obtenido

Los cinco problemas del escenario ya aparecieron durante el laboratorio:

| Problema del escenario | Lo que se comprobó |
|---|---|
| Contraseñas en texto claro | Actividad 1: un `SELECT` a `usuarios_insegura` devolvió `Password123` tal cual. Con `crypt()` solo queda un hash de 60 caracteres, y aun así la verificación funciona: `t` con la contraseña correcta y `f` con la incorrecta. |
| RFC en texto claro | Actividad 2: cifrado con `pgp_sym_encrypt()`, el RFC solo se ve como 79 bytes en hexadecimal y únicamente se recupera con la clave correcta. En cambio, la tabla `clientes` del LAB-01 todavía guarda el RFC legible: la vista `v_clientes_soporte` lo enmascara con `RIGHT(rfc, 4)`. |
| Conexiones sin validación adecuada del servidor | Actividades 5 y 6: con `prefer`, pgAdmin se conectó a la FIC sin TLS y sin avisar (`ssl = off` y `pg_stat_ssl` en `false`). Con `require`, la conexión se cifró con TLSv1.3, pero el cliente aceptó el certificado autofirmado sin validarlo. Solo `verify-full` exigió validarlo, y se negó a conectarse porque no había un certificado raíz. |
| Claves en archivos SQL | Actividad 3: la clave de prueba quedó en el script, en el registro y el historial de psql y en el log del servidor. |
| Respaldos sin protección adicional | Actividad 7, solo como análisis: un respaldo copia la base tal como está guardada, así que todo lo que esté en texto claro queda legible en el archivo. |

## Análisis

### Pregunta 1. ¿Cuáles son los principales riesgos?

- **Robo de cuentas.** Las contraseñas quedan al alcance de quien lea la tabla de usuarios, sea con permiso o por una falla, y de quien obtenga un respaldo. Con ellas puede entrar como cualquier usuario. Como mucha gente repite sus contraseñas, el daño llega a otros servicios, como el correo o el banco, y la empresa ya no puede contenerlo.
- **Exposición de datos personales.** El nombre, el correo y el RFC en texto claro permiten suplantar la identidad de los clientes y cometer fraudes con sus datos. Su filtración es un incidente con datos personales, con consecuencias legales y de reputación para la empresa.
- **Información financiera sin protección real.** Si esa información está cifrada, las claves en los archivos SQL anulan el cifrado. Si no lo está, queda igual de expuesta que el RFC.
- **Intermediario en la red.** Si el cliente no valida el certificado, un atacante en la red puede hacerse pasar por el servidor (con `require`) o hacer que la conexión se quede sin TLS (con `prefer`). Así puede leer o modificar las consultas y sus resultados, incluidos el RFC, la información financiera y las claves, que con pgcrypto viajan dentro de las consultas (Actividad 7).
- **Claves expuestas.** Las claves escritas en archivos SQL se copian a repositorios, respaldos, registros y logs (Actividad 3). Quien tenga cualquiera de esas copias puede descifrar todo lo que esa clave protege, incluso fuera del servidor, donde la base no registra nada. Retirar una clave expuesta obliga a generar otra y volver a cifrar los datos.
- **Respaldos como copia completa.** Un respaldo sin protección reúne en un solo archivo las contraseñas, el RFC y la información financiera. Si los archivos SQL con las claves se respaldan junto con él, también lo cifrado queda expuesto. Además, los respaldos suelen guardarse más tiempo y en más lugares que la base, y ahí ya no aplican los permisos de los usuarios.

Los problemas se suman: un solo respaldo filtrado expone todo a la vez.

### Pregunta 2. ¿Qué mecanismo utilizarías para cada elemento?

| Elemento | Mecanismo |
|---|---|
| Nombre | Normalmente no se cifra por columna, porque se consulta todo el tiempo para atender al cliente. Se protege con control de acceso por rol, con enmascaramiento o seudonimización donde no haga falta verlo (el conjunto de analítica del LAB-01 ya no lo lleva), con TLS en la conexión y con respaldos cifrados. |
| Correo electrónico | Igual que el nombre. Para quien no lo necesita completo, se enmascara, como en `v_clientes_soporte` del LAB-01. |
| Contraseña | Derivación de claves para contraseñas (bcrypt, Argon2id o scrypt), nunca cifrado. Como hoy están en texto claro, hay que calcular de inmediato el hash de todas y pedir a los usuarios que las cambien, porque las actuales pudieron filtrarse en algún respaldo. |
| RFC | Cifrado de la columna, con `pgp_sym_encrypt()` o un mecanismo equivalente, si existe una razón para guardarlo y recuperarlo. Solo el rol que lo necesita puede descifrarlo; para los demás se muestra enmascarado. |
| Información financiera | Cifrado de la columna, igual que el RFC pero con su propia clave, y acceso solo para el rol que la necesita, aplicando la separación de funciones del LAB-01. |
| Claves criptográficas | Fuera de los archivos SQL y del repositorio, en un gestor de secretos o en un servicio de administración de claves, y que la aplicación las reciba solo al momento de usarlas. Como ya aparecieron en archivos, hay que darlas por comprometidas: generar claves nuevas, volver a cifrar los datos y revocar las anteriores (Actividad 3). |

Además, dos medidas cubren a todos los elementos a la vez:

- **Conexiones:** TLS, con `ssl = on`, un certificado firmado por una autoridad en la que confíe el cliente y `sslmode=verify-full`. En `pg_hba.conf`, las conexiones por red deben tener solo reglas `hostssl`, para que el servidor rechace las que no usen TLS.
- **Respaldos:** cifrar cada respaldo con una clave guardada aparte, limitar quién puede leerlo y no guardarlo junto con las claves de los datos.

### Pregunta 3. ¿Cuál de los problemas consideras más crítico y por qué?

Las contraseñas en texto claro, por tres razones:

1. **El daño es inmediato.** Quien las lea entra como cualquier usuario sin descifrar nada. Y como se repiten, también entra a cuentas fuera de la empresa, donde la empresa ya no puede hacer nada.
2. **Casi todo lo demás las expone:** un respaldo sin cifrar, una conexión interceptada o cualquier rol que pueda leer la tabla de usuarios.
3. **No tiene justificación.** A diferencia del RFC, una contraseña nunca necesita recuperarse. En la Actividad 1, `crypt()` verificó la contraseña usando solo el hash.

Muy cerca están los respaldos sin protección, porque juntan en un solo archivo todo lo demás. Aun así, con los respaldos cifrados, una contraseña en texto claro seguiría expuesta a cualquiera que pueda leer la tabla.

### Pregunta 4. ¿Tener correctamente configurados los usuarios y permisos elimina estos riesgos?

No. Los permisos deciden quién puede consultar cada objeto a través del servidor PostgreSQL, pero no cambian cómo están guardados los datos ni protegen lo que está fuera del servidor:

- **Quien sí tiene permiso ve el dato completo.** La aplicación, el DBA y cualquier rol autorizado a leer la tabla de usuarios ven las contraseñas tal cual; con un hash, ni siquiera ellos podrían conocerlas. Además, si una de esas cuentas se compromete, por ejemplo por una inyección SQL en la aplicación, el atacante obtiene sus mismos permisos.
- **Los permisos no viajan con los datos.** Un respaldo se puede restaurar en otro servidor, donde quien lo restaura es superusuario. Los archivos SQL, el registro y el historial de psql y el log del servidor (Actividad 3) son simples archivos, y ningún `GRANT` los cubre.
- **Los permisos no cifran la red.** En la FIC, el usuario `u_20439504_jesus_carrillo` tiene permisos limitados: ni siquiera puede leer `ssl_min_protocol_version` (error 42501). Aun así, su sesión viajó sin TLS (Actividad 5).

La base `comercializadora` es un ejemplo de esto:

- En el LAB-01 los roles `soporte` y `analista` quedaron bien limitados: PostgreSQL les rechazó la tabla `clientes` con «permission denied».
- Pero esa tabla sigue guardando el correo, el teléfono y el RFC legibles. En cualquier respaldo de la base esos datos quedan completos, y `postgres` los ve tal cual.

En el LAB-01 se concluyó que el enmascaramiento y la seudonimización no sustituyen al control de acceso. Este escenario muestra lo contrario: el control de acceso tampoco sustituye a la derivación de contraseñas, al cifrado ni a TLS. Es justo lo que plantea la guía en su sección 1, «Contexto».

## Conclusión

La empresa del escenario resolvió quién puede entrar a la base, pero no qué pasa con los datos cuando alguien los lee, los copia o los intercepta. Cada problema tiene su mecanismo:

- derivación de claves para las contraseñas;
- cifrado, con claves bien guardadas, para el RFC y la información financiera;
- TLS con `verify-full` para las conexiones;
- cifrado para los respaldos.

Los permisos y estos mecanismos se complementan, y ninguno elimina por sí solo los riesgos del escenario.

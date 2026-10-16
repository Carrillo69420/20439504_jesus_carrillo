# Evidencia 07 — Protección en reposo y protección en tránsito

LAB-02, Actividad 7 (sección 14 de la guía). No tiene script: la tabla se completó con lo que se hizo en las Actividades 1 a 6.

## Objetivo

Elegir el mecanismo apropiado para cada situación de la tabla de la guía, explicar qué protege y distinguir si se trata de protección en reposo (mientras el dato está guardado) o en tránsito (mientras viaja entre el cliente y el servidor).

## Comando o procedimiento

No se ejecutaron comandos nuevos. Cada renglón de la tabla de la sección 14 se resolvió con la distinción de la sección 4.1 de la guía:

- lo que solo hay que verificar, como una contraseña, se protege con derivación de claves para contraseñas;
- lo que hay que volver a leer, como el RFC, se cifra;
- lo que viaja por la red se protege con TLS.

Cada mecanismo se tomó de lo que ya se había probado en el laboratorio:

- `crypt()` con `gen_salt('bf')` en la Actividad 1;
- `pgp_sym_encrypt()` en la Actividad 2;
- las copias de la clave que se encontraron en la Actividad 3;
- TLS y `sslmode` en las Actividades 4 a 6.

El respaldo no se practicó, así que ese renglón se basa en la sección 4.1.

## Resultado obtenido

| Situación | Mecanismo apropiado | ¿Qué protege? |
|---|---|---|
| Contraseña de usuario | Derivación de claves para contraseñas: un hash lento y con sal, como bcrypt (`crypt()` con `gen_salt('bf')` en la Actividad 1), Argon2id o scrypt. | **En reposo.** Impide que quien lea la tabla o un respaldo obtenga la contraseña original. También evita que dos contraseñas iguales tengan el mismo hash y hace costoso adivinarlas por fuerza bruta. |
| RFC almacenado en una tabla | Cifrado simétrico de la columna, como `pgp_sym_encrypt()` en la Actividad 2, con la clave guardada fuera de la base y del código. | **En reposo.** Protege la confidencialidad del RFC dentro de la tabla y en sus copias: sin la clave solo se ven bytes, y con la clave correcta se recupera cuando hay una necesidad legítima. |
| Consulta enviada desde un cliente al servidor | TLS: `ssl = on` en el servidor, con un certificado que el cliente pueda validar, y `sslmode=verify-full` en el cliente (Actividades 4 a 6). | **En tránsito.** Protege la confidencialidad y la integridad de la consulta y de sus resultados mientras viajan, incluidas las contraseñas o claves que vayan dentro. Con `verify-full` además se comprueba la identidad del servidor, para no conectarse a un intermediario. |
| Respaldo de una base de datos | Cifrado del respaldo: cifrar el archivo, por ejemplo el que genera `pg_dump`, antes de guardarlo o copiarlo, con una clave propia que se guarde separada del respaldo. También hay que limitar quién puede leerlo. | **En reposo**, y también mientras se copia a otro lugar. Protege todo lo que contiene, que es una copia completa de la base, incluidos los datos que no se cifraron por columna, como nombres y correos. |
| Clave criptográfica | Gestión segura de claves: guardarla en un gestor de secretos o en un servicio de administración de claves, fuera del código y del repositorio, con acceso mínimo, rotación y revocación (Actividades 3 y 10). | **En reposo y en tránsito.** Protege la clave misma, guardada y cuando se le entrega a la aplicación que la usa, y con ella todo lo que cifra: si se expone, el cifrado del RFC y de los respaldos deja de proteger. |

## Análisis

**¿Qué cubre cada tipo de protección?** La contraseña, el RFC y el respaldo se protegen en reposo, y la consulta en tránsito. La clave necesita las dos protecciones, porque se guarda en un lugar y viaja a la aplicación cada vez que se usa. El respaldo también viaja cuando se copia a otro sitio, y si va cifrado, sigue protegido en ese trayecto.

**La protección en tránsito no cubre lo guardado.** TLS cifra solo la conexión: al llegar al servidor, los datos se descifran y se guardan como vengan. Si el RFC estuviera en texto claro, lo leería cualquiera con acceso a la tabla, a un respaldo o a los logs, aunque todas las conexiones usaran `verify-full`.

**La protección en reposo no cubre el viaje.** pgcrypto cifra dentro del servidor. Por eso, en `pgp_sym_encrypt('LOPA900101ABC', 'CLAVE-DE-PRUEBA')`, el RFC y la clave viajan en texto claro dentro de la consulta. La documentación de pgcrypto lo advierte en la sección F.28.6.3 «Security Limitations» ([PostgreSQL 16](https://www.postgresql.org/docs/16/pgcrypto.html)): hay que conectarse de forma local o con SSL.

En el laboratorio la consulta no salió del contenedor `dba-practica`. En el servidor de la FIC, en cambio, que tiene `ssl = off` (Actividad 5), la misma consulta viajaría sin cifrar entre pgAdmin y PostgreSQL, porque el HTTPS del navegador no cubre ese tramo. Lo mismo pasa con cualquier contraseña escrita dentro de una consulta.

**Cada mecanismo depende de otro.**

- El cifrado del RFC y el del respaldo protegen lo mismo que proteja su clave. La Actividad 3 mostró que una clave escrita en las consultas acaba en scripts, en el registro y el historial de psql y en el log del servidor.
- TLS solo evita a un intermediario si el cliente verifica el certificado. Con `prefer`, pgAdmin se conectó a la FIC sin TLS y sin avisar. Con `verify-full`, psql se negó a conectarse porque no tenía con qué validar el certificado del servidor (Actividad 6).

**El respaldo copia la base tal como está guardada.** En un respaldo de `comercializadora`, los hashes de `usuarios_segura` seguirían siendo hashes y el RFC de `clientes_protegidos` seguiría cifrado. En cambio, el nombre de Ana López, la contraseña de `usuarios_insegura` y cualquier otra columna sin cifrar quedarían legibles para quien obtenga el archivo, si el respaldo no se cifra. Y si la clave del RFC se guarda junto con el respaldo, el cifrado de la columna tampoco sirve.

## Conclusión

La protección en reposo y la protección en tránsito resuelven problemas distintos y se necesitan las dos:

- La derivación de claves y el cifrado protegen lo que está guardado en tablas y respaldos.
- TLS protege lo que viaja entre el cliente y el servidor.
- La gestión de claves sostiene a ambas, porque una clave expuesta anula el cifrado sin importar cómo viaje la información.

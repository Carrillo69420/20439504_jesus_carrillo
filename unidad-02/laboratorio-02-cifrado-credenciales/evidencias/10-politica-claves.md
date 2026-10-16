# Evidencia 10 — Política mínima de protección de claves

LAB-02, Actividad 10 (sección 17 de la guía). No tiene script: la política se redactó a partir de lo que se observó en las Actividades 2 a 7 y en el LAB-01.

## Objetivo

Definir una política propia, de entre 5 y 10 reglas, para gestionar claves criptográficas. Debe cubrir su generación, almacenamiento, acceso, rotación, respaldo, revocación, exposición accidental y eliminación.

## Comando o procedimiento

No se ejecutaron comandos. La política parte de dos listas de la guía:

- los ocho aspectos que pide la sección 17;
- el ciclo de vida de una clave que la guía define en su tabla de conceptos (sección 4): generar, almacenar, distribuir, utilizar, rotar, revocar, respaldar y eliminar.

A los ocho aspectos se agregó uno más, el uso y la transmisión de la clave, porque ahí fue donde el laboratorio encontró más copias de la clave (Actividad 3). Cada regla responde a algo que se observó en el laboratorio; esa relación se explica en el «Análisis».

## Resultado obtenido

### Política de protección de claves criptográficas — Comercializadora Norte S.A. de C.V.

**Alcance:** las claves que cifran datos de la base `comercializadora` o de sus respaldos, como la del RFC, y las llaves privadas de los certificados TLS de sus servidores.

1. **Generación.** Toda clave se genera con un generador aleatorio criptográficamente seguro, como `gen_random_bytes()` de pgcrypto o el propio gestor de secretos, y con la longitud que exige el algoritmo. No se aceptan palabras o frases inventadas por una persona, ni claves que vengan en ejemplos, documentación o imágenes de instalación.
2. **Almacenamiento.** Las claves que cifran datos se guardan solo en un gestor de secretos o en un servicio de administración de claves, separadas de los datos que protegen. Nunca se guardan en el repositorio, en scripts SQL, en archivos de configuración, en tablas de la misma base ni dentro de sus respaldos. La llave privada de un certificado TLS solo existe en el servidor que la usa, con permisos que únicamente le permitan leerla al servicio.
3. **Acceso.** Cada clave solo la puede obtener la aplicación o el rol que necesita cifrar o descifrar con ella, y el gestor registra cada vez que alguien la pide. Administrar la base no da acceso a las claves: el DBA no necesita conocerlas para hacer su trabajo.
4. **Uso y transmisión.** La aplicación obtiene la clave del gestor en el momento de usarla, por una conexión cifrada, y no la escribe en ningún archivo. De preferencia, el cifrado se hace en la aplicación, para que la clave no llegue al servidor de base de datos. Si se usa pgcrypto, la conexión debe usar TLS con `sslmode=verify-full`, y el historial de psql y los logs del servidor se protegen como información sensible, porque pueden guardar las sentencias con la clave.
5. **Rotación.** Cada clave tiene un periodo de uso definido, por ejemplo un año, y se cambia antes si sale de la organización alguien que tuvo acceso a ella. Cada dato cifrado guarda el identificador de la versión de clave con la que se cifró, para poder volver a cifrarlo con la nueva sin perder nada.
6. **Respaldo.** Las claves que cifran datos se respaldan cifradas, en un lugar distinto de los respaldos de la base, y periódicamente se prueba que se pueden recuperar. Sin la clave, los datos que cifra ya no se pueden recuperar.
7. **Revocación.** Existe un procedimiento escrito para revocar una clave. Indica quién lo autoriza, cómo se bloquea la clave en el gestor, cómo se vuelven a cifrar los datos con una clave nueva y cómo se documenta el incidente. Se aplica en cuanto una clave se expone o se sospecha que se expuso.
8. **Exposición accidental.** Antes de cada commit se buscan contraseñas, claves y tokens en los archivos (Actividad 9). Una clave real que aparezca en un repositorio, aunque sea privado, o en un log, una captura o un mensaje, se da por comprometida y se revoca, aunque después se borre.
9. **Eliminación.** Mientras exista algún dato o respaldo vigente cifrado con una clave, esta se conserva, aunque ya no se use para cifrar. Cuando deja de proteger cualquier cosa vigente, se destruye en el gestor y en sus respaldos, y se registra la fecha y quién lo autorizó.

## Análisis

**¿De dónde sale cada regla?** Cada una responde a algo que se vio durante el laboratorio:

| Regla | Lo que se observó |
|---|---|
| 1. Generación | `'CLAVE-DE-PRUEBA'` es una frase inventada, aceptable solo porque es ficticia (Actividad 2). La llave del certificado de prueba de `postgres:16` (`ssl-cert-snakeoil.key`) viene dentro de la imagen, así que la tiene cualquiera que use esa imagen (Actividad 6). |
| 2. Almacenamiento | La clave está escrita en `sql/02-cifrado-datos.sql` y en `evidencias/02-cifrado-datos.md`, porque la Actividad 2 la pide así. Con una clave real, esos dos archivos ya serían una filtración (Actividad 3). |
| 3. Acceso | En el LAB-01, `analista` no pudo leer `pii.mapa_cliente`, lo único que permite saber a quién pertenece cada token. Las claves necesitan la misma separación de funciones: quien usa los datos no administra las claves. |
| 4. Uso y transmisión | La clave quedó en el registro `-L`, en el historial de psql y en el log del servidor (Actividad 3). Además, pgcrypto cifra dentro del servidor, y la conexión de la FIC no usa TLS (Actividades 5 y 7). La documentación de pgcrypto pide confiar en los administradores del sistema y de la base; si no se puede, recomienda cifrar en la aplicación. |
| 5. Rotación | `clientes_protegidos` no guarda con qué clave se cifró cada RFC. Con una sola clave no importa, pero al rotar habría que probar cada fila con cada clave, hasta que una no diera `Wrong key or corrupt data`. |
| 6. Respaldo | Con `'CLAVE-INCORRECTA'`, el descifrado falló y no entregó ni una parte del RFC (Actividad 2). Si se pierde la clave, todos los RFC quedan así: cifrados para siempre. |
| 7. Revocación | Para una clave publicada, lo único que resuelve el problema es darla por comprometida, generar otra y volver a cifrar todo (Actividad 3). Si ese procedimiento no está escrito de antemano, hay que improvisarlo en pleno incidente. |
| 8. Exposición accidental | Git ya veía el archivo de mala práctica como nuevo (`??`), y la sección 21 de la guía usa `git add .`, así que un commit más lo habría subido al historial (Actividad 3). |
| 9. Eliminación | Destruir una clave es irreversible: lo cifrado con ella ya no se puede leer, ni siquiera en los respaldos. Por eso solo se destruye cuando nada vigente depende de ella. Esto también sirve para la retención del LAB-01: si los registros de cada periodo se cifraran con su propia clave, al cumplirse los cinco años bastaría con destruirla para que esos datos quedaran ilegibles en todas sus copias. |

**La excepción del laboratorio.** Este laboratorio no cumple la regla 2, y es a propósito. La Actividad 2 pide escribir `'CLAVE-DE-PRUEBA'` en el script para demostrar el cifrado, y la sección 25 de la guía lo permite solo con claves exclusivamente de laboratorio. Con esta política, una clave real nunca estaría en `sql/` ni en las evidencias.

## Conclusión

La política cuida la clave durante toda su vida, desde que se crea hasta que se destruye, y cada regla corrige un problema que se vio en el laboratorio. Además, las reglas se necesitan entre sí. Para cambiar una clave o darla de baja, hay que saber qué datos se cifraron con ella y tener una copia guardada. Y revisar los archivos antes de subirlos solo sirve si se sabe qué hacer cuando aparece una clave. Como se vio en la Actividad 3, un dato cifrado solo está tan seguro como su clave.
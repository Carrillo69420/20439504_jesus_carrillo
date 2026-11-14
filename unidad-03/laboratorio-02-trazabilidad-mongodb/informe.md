# Informe del LAB-02 — Trazabilidad en MongoDB Community

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad III, temas 3.1 Auditoría de bases de datos y 3.2 Bitácoras y trazabilidad
- Fechas: 5 y 13 de noviembre de 2026

Este informe sigue los puntos de la sección 19 de la guía y agrega la verificación final (sección 17) y las preguntas de reflexión (sección 20). Los comandos y resultados completos están en las [evidencias](evidencias/), y los comandos de mongosh, ordenados por actividad, en [comandos-mongosh.js](scripts/comandos-mongosh.js). Las horas están en UTC, como las guarda el servidor; la de Culiacán es UTC−7.

## 1. Despliegue, edición y limitación

El servidor se creó en Docker con la imagen oficial `mongo:7`, en el contenedor `dba-u3-mongo`, con el volumen `dba-u3-mongo-data` y con `--auth`, que exige usuario y contraseña. No se publicó el puerto: todas las sesiones se abrieron con `docker exec`, así que las conexiones llegan desde `127.0.0.1`. Tampoco se cambió la zona horaria, para que el perfilador y la bitácora usaran la misma, UTC. El comando, sus diferencias con el Anexo A de la guía y la creación de los usuarios y de los cinco clientes de la sección 6.3 están en el [README](README.md).

La edición se comprobó desde la sesión del DBA ([evidencia 01](evidencias/01-edicion-y-limitacion.md)):

| Comando | Resultado | Qué muestra |
| --- | --- | --- |
| `db.version()` | `7.0.45` | La versión; la guía usó la 7.0.43, de la misma serie |
| `db.adminCommand({ buildInfo: 1 }).modules` | `[]` | Que es Community: en Enterprise incluiría `"enterprise"` |
| `db.serverCmdLineOpts().parsed` | Solo `net` y `security` | Que arrancó sin archivo de configuración y sin `systemLog` |

Lo que no existe en Community es la auditoría nativa. Según la documentación (REF-U3-04), la incluye MongoDB Enterprise, para `mongod` y `mongos`, y Atlas la ofrece en los clústeres M10 o mayores. Registraría cuatro categorías de eventos: cambios de esquema, eventos de conjuntos de réplicas y de clústeres fragmentados, autenticación y autorización, y operaciones CRUD, estas solo con `auditAuthorizationSuccess: true`. En Community quedan dos mecanismos de trazabilidad, y ninguno es auditoría: el perfilador, diseñado para analizar el desempeño (sección 4.2 de la guía), y la bitácora de `mongod`.

## 2. Perfilador

### Configuración

El perfilador se activó en la base `comercial`. Así cambió a lo largo del laboratorio:

| Actividad | Configuración | Qué quedó en `system.profile` |
| --- | --- | --- |
| 2 | Nivel 0, el de fábrica | Nada: el cambio del RFC no dejó rastro |
| 3 | `db.setProfilingLevel(2)` | Todas las operaciones sobre `comercial`, también las consultas |
| 4 | Nivel 1 con `{ filter: { op: { $in: ["insert", "update", "remove"] } } }` | Solo las operaciones que cambian datos |
| 7 | Nivel 2 sin filtro, con `{ filter: "unset" }` | Las operaciones sobre `comercial`, pero no el `grantRolesToUser` |
| 7, al terminar | Otra vez el filtro de la Actividad 4 | Solo las operaciones que cambian datos |
| 8, después del reinicio | Nivel 0 | Nada: la configuración no sobrevive al reinicio |

### Interpretación

Con el nivel 2, los tres documentos de la tienda en la Actividad 3 dicen qué se hizo, quién, desde dónde, con qué aplicación y cuándo ([evidencia 03](evidencias/03-perfilador.md)):

| `ts` (UTC) | `op` | Qué guarda |
| --- | --- | --- |
| 17:52:12.538 | `query` | La consulta de los clientes de Culiacán, con su filtro y `nreturned: 3` |
| 17:52:12.541 | `update` | El cambio del RFC de `_id: 3`: el filtro (`q`) y el valor nuevo (`u`) |
| 17:52:12.545 | `remove` | El borrado de `_id: 2`: el filtro y `ndeleted: 1` |

En los tres, `user` es `app_ventas@comercial`, el nombre del usuario y la base en la que se creó; `client` es `127.0.0.1`, y `appName`, `app-ventas-web` (los campos se describen en REF-U3-16). Hay que leerlos con dos cuidados. `user` lo comprueba el servidor, porque es el usuario autenticado, pero es una cuenta y no una persona. `appName`, en cambio, lo declara el propio cliente en su cadena de conexión, así que sirve para interpretar, pero no prueba qué programa se conectó.

Lo que el perfilador no guarda es el contenido anterior: ni el RFC de antes, `GAMA780912XXX`, ni los datos del cliente borrado, ni lo que devolvió la consulta, solo cuántos documentos. Sirve para reconstruir qué pasó, no para recuperar lo que se perdió.

### Costo

- **Desempeño.** La documentación advierte que el perfilador puede degradar el rendimiento, en especial en nivel 2, en el que registra todas las operaciones (sección 4.2 de la guía, REF-U3-05).
- **Espacio y conservación.** `system.profile` es una colección limitada de 1 MB: su `maxSize` es de 1048576 bytes ([evidencia 08](evidencias/08-conservacion.md)). Cuando se llena, se sobrescriben los documentos más antiguos. El nivel 2 la llena antes, porque las consultas suelen ser la mayoría de las operaciones.
- **Privacidad.** Guarda los filtros y los valores nuevos, como el RFC, así que `system.profile` y sus exportaciones también contienen datos personales.

El filtro de la Actividad 4 reduce el volumen a las operaciones que cambian datos, pero ya no deja rastro de las lecturas: la tienda consultó dos veces a Ana López y no quedó ninguna de las dos consultas ([evidencia 04](evidencias/04-filtro.md)).

## 3. Bitácora de mongod

### Dónde se escribe

A la salida estándar del proceso, que en un contenedor recoge Docker. `serverCmdLineOpts().parsed` no trae `systemLog`, y sin `systemLog.destination: file` la bitácora va a la salida estándar (sección 4.5 de la guía, REF-U3-21). Se lee de dos maneras ([evidencia 01](evidencias/01-edicion-y-limitacion.md)):

- Con `docker logs dba-u3-mongo`, desde PowerShell. Conserva lo que Docker guarda del contenedor, también después de un reinicio, pero se pierde si se elimina el contenedor.
- Con `getLog`, desde mongosh, que es lo que usa `bitacora()`. Devuelve solo los últimos 1024 eventos que `mongod` guarda en memoria, y se vacía al reiniciar (REF-U3-20).

Cada evento es una línea JSON con los campos de la sección 4.5 de la guía (REF-U3-06): el momento (`t`), la severidad (`s`), el componente que lo escribió (`c`), el identificador del tipo de evento (`id`), la conexión o el hilo (`ctx`), el mensaje (`msg`) y los detalles (`attr`).

### Accesos

En la Actividad 5 se hicieron dos intentos fallidos a propósito, y se buscaron junto con el último acceso exitoso de la tienda ([evidencia 05](evidencias/05-accesos-mongod.md)):

| Hora (UTC) | Conexión | Usuario | Resultado |
| --- | --- | --- | --- |
| 18:08:28.873 | `conn29` | `app_ventas` | Acceso exitoso (`result: 0`), desde `app-ventas-web` |
| 18:26:31.941 | `conn32` | `app_ventas` | Contraseña incorrecta: `AuthenticationFailed`, código 18 |
| 18:26:40.683 y 18:26:40.684 | `conn34` | `usuario_inexistente` | Usuario inexistente: `UserNotFound`, código 11, en dos líneas |

El acceso exitoso tiene el `id` 5286306, «Successfully authenticated», y los fallidos, el 5286307, «Failed to authenticate», con la causa exacta. Al cliente, en cambio, le llegó en los dos casos solo `Authentication failed.`, para no revelar si el usuario existe. Al revisar la bitácora hay que contar intentos y no líneas, porque el usuario inexistente dejó dos, y no fiarse del nombre de la aplicación: los fallidos dicen `mongosh 2.14.0` porque su cadena no declaraba otro.

### Cambios de configuración

La bitácora registró los tres cambios del perfilador de las actividades 3 y 4 con el mensaje «Profiler settings changed» ([evidencia 06](evidencias/06-correlacion.md)):

| Hora (UTC) | `ctx` | Cambio |
| --- | --- | --- |
| 17:51:51.745 | `conn13` | Del nivel 0 al 2 (Actividad 3) |
| 18:07:24.336 | `conn13` | Del nivel 2 al 0, para poder borrar `system.profile` (Actividad 4) |
| 18:07:34.039 | `conn13` | Del nivel 0 al 1, con el filtro de las escrituras (Actividad 4) |

Esas líneas no traen el usuario, pero sí la conexión, y `conn13` se autenticó a las 17:18:41.269 como `admin`, de la base `admin`. Por ese `ctx` común se sabe que fue el DBA. La correlación solo vale dentro del mismo arranque del servidor, porque al reiniciar los números de conexión vuelven a empezar desde `conn1`. Que quede registrado el cambio del propio perfilador deja ver sus huecos: entre las 18:07:24 y las 18:07:34 estuvo apagado, y estas líneas dicen quién lo apagó y cuándo lo volvió a encender.

## 4. Privilegios

### Evidencia disponible

Ninguna. En la Actividad 7 se le otorgó a `app_ventas` el rol `dbAdmin` sobre `comercial` con el perfilador en nivel 2 y sin filtro, y el `grantRolesToUser` no quedó en `system.profile` (0 documentos) ni en la bitácora (0 eventos) ([evidencia 07](evidencias/07-privilegios-control-compensatorio.md)). La revocación tampoco aparece en los archivos exportados en la Actividad 8. Es el límite más importante de Community, porque un cambio de privilegios decide qué puede hacer un usuario de ahí en adelante. `dbAdmin`, por ejemplo, incluye `enableProfiler`, `dropCollection` sobre `system.profile` y `dropDatabase`: con ese rol, la tienda podría apagar el perfilador y borrar el registro de sus propias operaciones.

### Control compensatorio

Instantáneas de los privilegios: un documento en `auditoria.instantaneas_privilegios` con el momento, el usuario que la tomó y los usuarios de la base con sus roles. Se tomó una antes del cambio y otra después:

| Dato | Primera | Segunda |
| --- | --- | --- |
| `momento` (UTC) | 18:45:15.552 | 18:46:46.122 |
| `tomada_por` | `admin`, de la base `admin` | `admin`, de la base `admin` |
| Roles de `app_ventas` | `readWrite` sobre `comercial` | `readWrite` y `dbAdmin` sobre `comercial` |

Al compararlas se detecta que `app_ventas` ganó `dbAdmin` y que el cambio ocurrió entre esos dos momentos.

### Su límite

Las instantáneas no son auditoría ni la sustituyen:

- Dicen qué cambió y entre qué momentos, pero no quién lo hizo: `tomada_por` es quien tomó la instantánea, no quien cambió el privilegio.
- No ven un cambio que se deshace entre dos instantáneas. Si el rol se hubiera quitado antes de la segunda, las dos habrían salido iguales.
- Solo cubren la base en la que se toman: `db.getUsers()` listó a `app_ventas`, de `comercial`, pero no a `admin`, que está en la base `admin`.
- Las tomó `admin`, con el rol `root`, que es el mismo usuario que otorgó el rol y que puede modificar cualquier colección del servidor, también esta. Para que sirvan, las debe tomar una cuenta propia que solo pueda agregar documentos, y conviene copiarlas fuera de MongoDB.

## 5. Conservación

### Riesgos observados

- **El reinicio.** A las 19:14:57 se reinició el servidor, y el perfilador volvió al nivel 0 sin ninguna línea «Profiler settings changed»: nada avisa que se dejó de registrar. `getLog` pasó de 388 eventos a 78. `system.profile` y `docker logs`, que están en disco, sí sobrevivieron ([evidencia 08](evidencias/08-conservacion.md)).
- **La sobrescritura de `system.profile`.** Al llegar a 1 MB, sobrescribe los documentos más antiguos sin que nadie lo pida.
- **El límite de `getLog`.** Guarda los últimos 1024 eventos. Los avisos de punto de control de WiredTiger salieron uno por minuto, así que por sí solos lo llenarían en unas 17 horas, aunque nadie usara la base.
- **El propio procedimiento.** El `drop()` de la Actividad 4 borró lo que el perfilador había guardado en la Actividad 3; se conserva solo porque se exportó antes.
- **El contenedor.** La bitácora completa solo está en su salida, y se pierde si se elimina.

### Exportación realizada

| Archivo | Contenido | Cuándo | SHA-256 |
| --- | --- | --- | --- |
| [system-profile-actividad3.json](evidencias/system-profile-actividad3.json) | Los cuatro documentos de la Actividad 3: la consulta, la actualización y el borrado de `app_ventas`, y la consulta del DBA a `system.profile` | Antes del `drop()` de la Actividad 4 | `a328c411…` |
| [system-profile.json](evidencias/system-profile.json) | Los tres documentos de `system.profile`: las dos actualizaciones de la Actividad 4 y el `countDocuments` de la Actividad 7 | Antes del reinicio | `f3f9492d…` |
| [bitacora-mongod.log](evidencias/bitacora-mongod.log) | Los 388 eventos de `getLog`, desde el arranque, a las 17:14:47, hasta las 19:09:48 | Antes del reinicio | `2885c072…` |

Los archivos se escribieron dentro del contenedor con `writeFileSync`, su huella se calculó ahí mismo con `sha256sum` y se copiaron al repositorio con `docker cp`. En Windows, `Get-FileHash` dio las mismas huellas, así que llegaron sin cambios; las tres están en [hashes.sha256](evidencias/hashes.sha256). La huella prueba que un archivo no cambió desde que se calculó, pero no que contenga todo lo que pasó, y quien controla el servidor podría recalcularla: por eso conviene guardarla lejos de él.

## 6. Comparación

La [evidencia 09](evidencias/09-comparacion.md) compara ocho eventos auditables en tres escenarios: PostgreSQL con bitácora y disparador (LAB-01), MongoDB Community con perfilador y bitácora (este laboratorio) y la auditoría nativa de Enterprise y Atlas, que no se practicó y se evaluó con su documentación. En resumen:

| Evento | PostgreSQL | MongoDB Community | Enterprise o Atlas, según su documentación |
| --- | --- | --- | --- |
| Acceso exitoso y fallido | Sí | Sí | Sí |
| Cambio de privilegios | Sí | No | Sí |
| Cambio de estructura | Sí | Parcial, sin usuario | Sí |
| Modificación de datos | Sí | Sí, con el perfilador encendido | Sí, con `auditAuthorizationSuccess` |
| Valor anterior del dato | Sí, por el disparador | No | No |
| Lectura de datos sensibles | No | Solo en nivel 2 | Sí, con `auditAuthorizationSuccess` |
| Cambio de configuración del registro | Sí | Sí; el usuario, por `ctx` | Parcial |

Ninguno de los tres cubre todo. PostgreSQL es el único que guardó el valor anterior, gracias al disparador, pero no registró las lecturas. Community cubre los accesos, las escrituras y los cambios del perfilador, pero no los cambios de privilegios ni el valor anterior. La auditoría nativa agregaría lo que más le falta a Community, los cambios de privilegios y de estructura con su autor, pero tampoco guarda el valor anterior.

## 7. Recomendación

Para una organización que necesite auditar los cambios de privilegios en MongoDB, se recomienda la auditoría nativa de MongoDB Enterprise o de Atlas. Es la forma que la documentación de MongoDB ofrece para registrar quién cambió un privilegio, y en este laboratorio ni el perfilador ni la bitácora de Community lo registraron. Se configuraría así:

1. **Un filtro con los eventos de usuarios y roles.** Con `auditLog.filter` se limita lo que se registra, con la misma forma de una consulta de `find` («Configure Audit Filters»), por ejemplo a los `atype` `createUser`, `updateUser`, `dropUser`, `grantRolesToUser`, `revokeRolesFromUser`, `createRole`, `updateRole`, `dropRole`, `grantPrivilegesToRole` y `revokePrivilegesFromRole` («mongo Schema Audit Messages»). Así el registro no crece con cada operación.
2. **El registro fuera del servidor.** A syslog o a un archivo que se copie a otro sistema, donde el DBA no pueda modificarlo, y con una revisión periódica de alguien de otra área. Quien tiene `root` puede modificar cualquier colección, como la de las instantáneas, que aquí tomó el mismo usuario que otorgó el rol.
3. **El control compensatorio mientras tanto, y como respaldo.** Instantáneas de los privilegios de todas las bases, cada hora y antes y después de cada cambio planeado, tomadas por una cuenta que solo pueda agregar documentos, comparadas automáticamente con la anterior y copiadas fuera de MongoDB. Además, pocas cuentas con roles que administran usuarios, como `root` o `userAdminAnyDatabase`.

### Hechos verificados en este laboratorio

- MongoDB 7.0.45 Community no tiene auditoría nativa: `buildInfo.modules` devuelve `[]`.
- Con el perfilador en nivel 2 y sin filtro, el `grantRolesToUser` no quedó en `system.profile` ni en la bitácora, y la revocación tampoco.
- Las instantáneas detectaron el rol nuevo de `app_ventas` y acotaron el cambio entre las 18:45:15 y las 18:46:46, pero no dijeron quién lo hizo.
- Las instantáneas las tomó el mismo usuario que otorgó el rol, y `getUsers()` solo cubrió la base `comercial`.
- Con cada reinicio, el perfilador vuelve al nivel 0 sin dejar aviso y `getLog` se vacía.

### Supuestos, no comprobados aquí

- Que la auditoría de Enterprise o Atlas registra cada `grantRolesToUser` con quién lo hizo (`users`), cuándo (`ts`), desde dónde (`remote`) y qué roles otorgó a quién (`param`). Lo dice la documentación, pero no se probó, porque este servidor es Community.
- Que Atlas la ofrece desde los clústeres M10, según la documentación consultada el 13 de noviembre de 2026.
- Que el costo de la licencia o de la suscripción se justifica. Depende de lo que la organización tenga que demostrar, por ley o por contrato, y del riesgo que acepte.
- Que una instantánea por hora basta. Depende de qué tan seguido cambien los privilegios y de cuánto tiempo pueda pasar un cambio sin detectarse.
- Que habrá alguien de otra área que revise los registros. Sin esa revisión, ninguna de las opciones responde preguntas.

## 8. Verificación final (sección 17)

Cada punto se comprueba con los resultados de las actividades; no se corrió una verificación aparte.

| Punto de la guía | Dónde se comprueba | ¿Se cumple? |
| --- | --- | --- |
| La auditoría nativa no existe en Community, con evidencia de la edición | `buildInfo.modules` devuelve `[]` y la versión es 7.0.45 ([evidencia 01](evidencias/01-edicion-y-limitacion.md)) | Sí |
| A dónde escribe el servidor su bitácora | A la salida estándar, que recoge Docker ([evidencia 01](evidencias/01-edicion-y-limitacion.md)) | Sí |
| `system.profile` contiene una `query`, un `update` y un `remove` de `app_ventas` | Los tres, a las 17:52:12 ([evidencia 03](evidencias/03-perfilador.md)) | Sí, en la Actividad 3. El `drop()` de la Actividad 4 los quitó de `system.profile`, y se conservan en [system-profile-actividad3.json](evidencias/system-profile-actividad3.json) |
| Usuario, cliente, aplicación y momento de cada operación, interpretados | La sección 2 de este informe y la [evidencia 03](evidencias/03-perfilador.md) | Sí |
| Un filtro de perfilado aplicado, con la evidencia que se pierde | El filtro de las escrituras: se pierden las lecturas ([evidencia 04](evidencias/04-filtro.md)) | Sí |
| Un acceso fallido y uno exitoso en la bitácora, interpretados | `conn32` y `conn34`, fallidos, y `conn29`, exitoso ([evidencia 05](evidencias/05-accesos-mongod.md)) | Sí |
| Un cambio de configuración correlacionado con su autor mediante `ctx` | `conn13`, autenticada como `admin` ([evidencia 06](evidencias/06-correlacion.md)) | Sí |
| El control compensatorio de privilegios, aplicado y explicado | Dos instantáneas, su comparación y su límite ([evidencia 07](evidencias/07-privilegios-control-compensatorio.md)) | Sí |
| `system.profile` y la bitácora, exportados con su hash | Tres archivos y [hashes.sha256](evidencias/hashes.sha256) ([evidencia 08](evidencias/08-conservacion.md)) | Sí |

## 9. Preguntas de reflexión

**¿Por qué el perfilador no debe presentarse como un mecanismo de auditoría de seguridad?**

Porque no se diseñó para eso y no da las garantías que se le piden a una auditoría. Se hizo para analizar el desempeño (sección 4.2 de la guía). Viene apagado y vuelve al nivel 0 con cada reinicio sin dejar aviso ([evidencia 08](evidencias/08-conservacion.md)). Quien tenga `enableProfiler` lo puede apagar, y `system.profile` se puede borrar, como lo hizo el propio procedimiento de la Actividad 4. Solo conserva lo que cabe en 1 MB. Y no registra justo lo más delicado: el cambio de privilegios de la Actividad 7 no quedó ni con el nivel 2 sin filtro. Presentarlo como auditoría haría creer que hay una evidencia que nadie puede garantizar.

**¿Por qué sí aporta trazabilidad aunque no sea auditoría?**

Porque, mientras está encendido, cada documento dice qué operación se hizo, quién, desde dónde, con qué aplicación y cuándo. Con eso se respondió en la Actividad 3 lo que en la Actividad 2 no se pudo: que `app_ventas`, desde `app-ventas-web`, cambió el RFC de María García a las 17:52:12. Y junto con la bitácora, por el `ctx`, se supo quién cambió la configuración del propio perfilador. La diferencia con una auditoría está en las garantías: el perfilador permite seguir lo que pasó, pero no asegura que el registro esté completo, que nadie lo haya apagado ni que cubra todos los eventos que importan.

**¿Qué riesgo introduce el nivel 2 al registrar filtros de consultas que pueden contener datos personales?**

Que `system.profile` se vuelve otra copia de los datos personales. En nivel 2 se guardan el filtro de cada consulta y el valor nuevo de cada cambio: en la Actividad 3 quedó el RFC nuevo de María García, y una búsqueda por correo o por RFC dejaría ese dato en el filtro. Esa copia dura lo que dure la evidencia, aunque el dato se corrija o se borre de la colección, y el archivo exportado se puede leer fuera de MongoDB, sin ningún permiso de la base. Este repositorio es público, y aquí no importa solo porque los clientes son ficticios. Por eso el acceso a `system.profile` y a sus exportaciones debe limitarse como el de los propios datos, y el nivel 2 conviene usarlo solo cuando haga falta y por poco tiempo.

**¿Qué diferencia hay entre detectar un cambio y atribuirlo a alguien?**

Detectar es saber que algo cambió y, a lo más, entre qué momentos. Atribuir es poder decir quién lo hizo, con un registro del servidor que lo ligue a un usuario autenticado. Las instantáneas de la Actividad 7 detectaron que `app_ventas` recibió `dbAdmin` entre las 18:45:15 y las 18:46:46, pero no dicen quién se lo dio: `tomada_por` es quien tomó la instantánea. En la Actividad 6, en cambio, sí se pudo atribuir el cambio del perfilador a `admin`, porque dos eventos del servidor compartían la conexión. Aun así, la atribución llega a una cuenta y no a una persona: `admin` es cualquiera que tenga su contraseña. Y el nombre de la aplicación no sirve para atribuir, porque lo declara el cliente.

**¿Por qué reconocer una limitación técnica es parte del trabajo profesional del DBA?**

Porque Dirección decide con lo que el DBA le dice que existe. Si se afirmara que Community registra los cambios de privilegios, la organización creería tener una evidencia que no tiene, y lo descubriría en el peor momento, durante un incidente. En la Actividad 10, cada una de las cuatro preguntas tuvo al menos una parte sin evidencia ([evidencia 10](evidencias/10-respuesta-direccion.md)). Decirlo, junto con lo que sí se comprobó, el control compensatorio con su límite y la opción que lo resolvería, es lo que permite decidir si el riesgo se acepta, se compensa o se paga. Una respuesta de «no hay evidencia» que se puede sostener vale más que una reconstrucción que no.

## Referencias

- Guía del LAB-02 de la Unidad III, secciones 4, 6, 17, 19 y 20, y Anexo A.
- Manual de MongoDB, «Auditing» (REF-U3-04): https://www.mongodb.com/docs/manual/core/auditing/
- Manual de MongoDB, «Configure Audit Filters»: https://www.mongodb.com/docs/manual/tutorial/configure-audit-filters/
- Manual de MongoDB, «mongo Schema Audit Messages»: https://www.mongodb.com/docs/manual/reference/audit-message/mongo/
- Manual de MongoDB, «Database Profiler» (REF-U3-05): https://www.mongodb.com/docs/manual/tutorial/manage-the-database-profiler/
- Manual de MongoDB, «Database Profiler Output» (REF-U3-16): https://www.mongodb.com/docs/manual/reference/database-profiler/
- Manual de MongoDB, «Log Messages» (REF-U3-06): https://www.mongodb.com/docs/manual/reference/log-messages/
- Manual de MongoDB, «getLog (database command)» (REF-U3-20): https://www.mongodb.com/docs/manual/reference/command/getLog/
- Manual de MongoDB, «Self-Managed Configuration File Options» (REF-U3-21): https://www.mongodb.com/docs/manual/reference/configuration-options/

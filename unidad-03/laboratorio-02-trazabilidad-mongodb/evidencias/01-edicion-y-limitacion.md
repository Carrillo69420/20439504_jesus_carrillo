# Evidencia 01 — Edición de MongoDB y limitación de auditoría

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 1 (sección 7 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Comprobar qué edición de MongoDB corre el servidor y dónde escribe su bitácora, antes de configurar nada, para saber si se cuenta con la auditoría nativa.

## Comandos

En la sesión del DBA (`docker exec -it dba-u3-mongo mongosh "mongodb://admin@127.0.0.1:27017/comercial?authSource=admin" --quiet`):

```javascript
db.version()
db.adminCommand({ buildInfo: 1 }).modules
db.serverCmdLineOpts().parsed
```

En otra pestaña de PowerShell, fuera de mongosh:

```powershell
docker logs dba-u3-mongo --tail 3
```

## Resultado obtenido

```text
comercial> db.version()
7.0.45
comercial> db.adminCommand({ buildInfo: 1 }).modules
[]
comercial> db.serverCmdLineOpts().parsed
{ net: { bindIp: '*' }, security: { authorization: 'enabled' } }
```

La guía muestra `7.0.43`; este servidor tiene `7.0.45`, una corrección posterior de la misma serie 7.0. `modules` y `parsed` salieron iguales que en la guía. En `parsed`, `bindIp: '*'` lo agrega el script de arranque de la imagen oficial (`--bind_ip_all`), porque el comando no indicó ninguna dirección, y `authorization: 'enabled'` viene de `--auth`. No aparecen `systemLog` ni `config`, porque el servidor arrancó sin archivo de configuración.

```text
{"t":{"$date":"2026-11-05T17:18:51.672+00:00"},"s":"I",  "c":"ACCESS",   "id":10483900,"ctx":"conn14","msg":"Connection not authenticating","attr":{"client":"127.0.0.1:32970","doc":{"application":{"name":"mongosh 2.14.0"},"driver":{"name":"nodejs|mongosh","version":"7.5.0|2.14.0"},"platform":"Node.js v24.22.1, LE","os":{"name":"linux","architecture":"x64","version":"3.10.0-327.22.2.el7.x86_64","type":"Linux"},"env":{"container":{"runtime":"docker"}}}}}
{"t":{"$date":"2026-11-05T17:19:47.259+00:00"},"s":"I",  "c":"WTCHKPT",  "id":22430,   "ctx":"Checkpointer","msg":"WiredTiger message","attr":{"message":{"ts_sec":1793899187,"ts_usec":259204,"thread":"1:0x785ebab60640","session_name":"WT_SESSION.checkpoint","category":"WT_VERB_CHECKPOINT_PROGRESS","category_id":6,"verbose_level":"DEBUG_1","verbose_level_id":1,"msg":"saving checkpoint snapshot min: 64, snapshot max: 64 snapshot count: 0, oldest timestamp: (0, 0) , meta checkpoint timestamp: (0, 0) base write gen: 1"}}}
{"t":{"$date":"2026-11-05T17:20:47.270+00:00"},"s":"I",  "c":"WTCHKPT",  "id":22430,   "ctx":"Checkpointer","msg":"WiredTiger message","attr":{"message":{"ts_sec":1793899247,"ts_usec":270798,"thread":"1:0x785ebab60640","session_name":"WT_SESSION.checkpoint","category":"WT_VERB_CHECKPOINT_PROGRESS","category_id":6,"verbose_level":"DEBUG_1","verbose_level_id":1,"msg":"saving checkpoint snapshot min: 65, snapshot max: 65 snapshot count: 0, oldest timestamp: (0, 0) , meta checkpoint timestamp: (0, 0) base write gen: 1"}}}
```

Cada línea es un documento JSON con los campos de la sección 4.5 de la guía (`t`, `s`, `c`, `id`, `ctx`, `msg` y `attr`). La primera es un evento de acceso (`c: "ACCESS"`): una conexión de mongosh 2.14.0 (`conn14`) desde `127.0.0.1` que no se autenticó. Las otras dos son del motor de almacenamiento (`c: "WTCHKPT"`), que guarda un punto de control cada minuto. Las horas terminan en `+00:00`, o sea que están en UTC: las 17:18 son las 10:18 de Culiacán.

## Análisis

**¿Qué edición de MongoDB estás usando? ¿Qué evidencia lo demuestra?** MongoDB 7.0.45 Community Edition. Lo demuestra `buildInfo.modules`, que devuelve un arreglo vacío; en Enterprise incluiría `"enterprise"`.

**¿A dónde escribe tu servidor su bitácora? ¿Cómo lo sabes?** A la salida estándar del proceso, que en un contenedor recoge Docker. `serverCmdLineOpts().parsed` no trae `systemLog`, y según la sección 4.5 de la guía (REF-U3-21), sin `systemLog.destination: file` la bitácora va a la salida estándar. Lo confirma `docker logs`, que muestra los últimos eventos en JSON. Esos eventos mezclan accesos con mensajes de operación del motor, así que para usarlos como evidencia hay que filtrarlos. Cuánto se conserva lo decide Docker, y si el contenedor se borra, esa bitácora se pierde con él. Desde mongosh, `getLog` solo devuelve los 1024 eventos más recientes y se vacía al reiniciar, así que no la sustituye.

**Según REF-U3-04, ¿qué cuatro categorías de eventos registraría la auditoría nativa?** Cambios de esquema (DDL), eventos de conjuntos de réplicas y clústeres fragmentados, autenticación y autorización, y operaciones CRUD, estas últimas solo con `auditAuthorizationSuccess: true`. Los eventos pueden ir a la consola, a syslog o a un archivo JSON o BSON (`--auditDestination`). Nada de esto existe en Community.

**¿Qué tendría que evaluar una organización antes de licenciar Enterprise o migrar a Atlas solo para obtener auditoría?** Primero, si de verdad la necesita: si una ley, un contrato o una auditoría externa le exige registrar accesos y cambios, o si le basta un control compensatorio. Después, el costo de la licencia o de la suscripción frente al riesgo que quiere cubrir, y el esfuerzo de migrar y probar sus aplicaciones. Con Atlas, además, los datos quedarían en la nube de un tercero, así que importa en qué región y bajo qué contrato. Por último, quién va a revisar esos registros y dónde se van a conservar, porque una auditoría que nadie revisa no responde ninguna pregunta.

## Conclusión

El servidor es MongoDB 7.0.45 Community: no trae auditoría nativa, y su bitácora va a la salida estándar del contenedor. Para responder a Dirección solo quedan el perfilador y la bitácora de `mongod`, que se configuran e interpretan en las siguientes actividades.

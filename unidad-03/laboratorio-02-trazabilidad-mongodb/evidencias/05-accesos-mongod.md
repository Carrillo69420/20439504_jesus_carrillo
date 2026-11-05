# Evidencia 05 — Accesos en la bitácora de `mongod`

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 5 (sección 11 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Provocar dos accesos fallidos, uno con una contraseña incorrecta y otro con un usuario que no existe, y encontrarlos en la bitácora de `mongod` junto con el último acceso exitoso de la tienda, para ver qué registra el servidor de cada uno.

## Comandos

En PowerShell, los dos intentos fallidos:

```powershell
docker exec dba-u3-mongo mongosh "mongodb://app_ventas:incorrecta@127.0.0.1:27017/comercial" --quiet --eval "db.clientes.countDocuments()"
docker exec dba-u3-mongo mongosh "mongodb://usuario_inexistente:x@127.0.0.1:27017/comercial" --quiet --eval "db.clientes.countDocuments()"
```

Son los comandos de la guía, ejecutados dentro del contenedor. El primero usa el usuario de la tienda con una contraseña equivocada a propósito, y el segundo, un usuario que no existe. Como la contraseña va en la cadena, mongosh no pide nada y no hace falta `-it`, que solo se necesita para escribirla cuando mongosh la pide.

En la sesión del DBA, los accesos fallidos y el último acceso exitoso de `app_ventas`, con la función `bitacora()`:

```javascript
bitacora().filter(e => e.c === "ACCESS" && e.msg === "Failed to authenticate").map(e => ({ t: e.t, id: e.id, ctx: e.ctx, user: e.attr.user, client: e.attr.client, error: e.attr.error, result: e.attr.result, app: e.attr.doc.application.name }))
bitacora().filter(e => e.msg === "Successfully authenticated" && e.attr.user === "app_ventas").slice(-1).map(e => ({ t: e.t, id: e.id, ctx: e.ctx, client: e.attr.client, result: e.attr.result, app: e.attr.doc.application.name }))
```

Son las consultas de la guía, cada una en una sola línea. `filter` se queda con los eventos que cumplen la condición, `map` convierte cada uno en un objeto con solo los campos elegidos y `slice(-1)` deja únicamente el último. En cada evento, `c` es el componente del servidor que lo escribió (`ACCESS` para la autenticación), `msg` el mensaje y `attr` los detalles. En `attr.doc` van los datos que el cliente manda al conectarse, entre ellos el nombre de la aplicación.

## Resultado obtenido

Los dos intentos:

```text
MongoServerError: Authentication failed.
MongoServerError: Authentication failed.
```

Los accesos fallidos en la bitácora:

```text
comercial> bitacora().filter(e => e.c === "ACCESS" && e.msg === "Failed to authenticate").map(e => ({ t: e.t, id: e.id, ctx: e.ctx, user: e.attr.user, client: e.attr.client, error: e.attr.error, result: e.attr.result, app: e.attr.doc.application.name }))
[
  {
    t: { '$date': '2026-11-05T18:26:31.941+00:00' },
    id: 5286307,
    ctx: 'conn32',
    user: 'app_ventas',
    client: '127.0.0.1:54910',
    error: 'AuthenticationFailed: SCRAM authentication failed, storedKey mismatch',
    result: 18,
    app: 'mongosh 2.14.0'
  },
  {
    t: { '$date': '2026-11-05T18:26:40.683+00:00' },
    id: 5286307,
    ctx: 'conn34',
    user: 'usuario_inexistente',
    client: '127.0.0.1:36394',
    error: 'UserNotFound: Could not find user "usuario_inexistente" for db "comercial"',
    result: 11,
    app: 'mongosh 2.14.0'
  },
  {
    t: { '$date': '2026-11-05T18:26:40.684+00:00' },
    id: 5286307,
    ctx: 'conn34',
    user: 'usuario_inexistente',
    client: '127.0.0.1:36394',
    error: 'UserNotFound: Could not find user "usuario_inexistente" for db "comercial"',
    result: 11,
    app: 'mongosh 2.14.0'
  }
]
```

| Intento | `ctx` | Momento (UTC) | `user` | `error` | `result` |
| --- | --- | --- | --- | --- | --- |
| 1. Contraseña incorrecta | `conn32` | 18:26:31.941 | `app_ventas` | `AuthenticationFailed: SCRAM authentication failed, storedKey mismatch` | 18 |
| 2. Usuario inexistente | `conn34` | 18:26:40.683 y 18:26:40.684 | `usuario_inexistente` | `UserNotFound: Could not find user "usuario_inexistente" for db "comercial"` | 11 |

Los dos intentos fueron a las 11:26 en Culiacán, desde `127.0.0.1`, porque se ejecutaron dentro del contenedor, y cada uno desde su propia conexión. Son tres líneas, pero dos intentos: las dos de `conn34` están a un milisegundo de distancia. mongosh intenta autenticarse en el mismo mensaje con el que abre la conexión, para ahorrarse un viaje de ida y vuelta (autenticación especulativa). Como el usuario no existe, eso falla y mongosh lo vuelve a intentar de la forma normal, que también falla. La primera línea tiene `isSpeculative: true` y la segunda `false`, un campo que la consulta no muestra. Con la contraseña incorrecta queda una sola línea.

El último acceso exitoso de la tienda:

```text
comercial> bitacora().filter(e => e.msg === "Successfully authenticated" && e.attr.user === "app_ventas").slice(-1).map(e => ({ t: e.t, id: e.id, ctx: e.ctx, client: e.attr.client, result: e.attr.result, app: e.attr.doc.application.name }))
[
  {
    t: { '$date': '2026-11-05T18:08:28.873+00:00' },
    id: 5286306,
    ctx: 'conn29',
    client: '127.0.0.1:55174',
    result: 0,
    app: 'app-ventas-web'
  }
]
```

Es de la segunda ejecución de la tienda en la Actividad 4, a las 18:08:28 UTC (11:08 en Culiacán). Como se vio en la evidencia 02, en cada ejecución la tienda abre varias conexiones que se autentican; `slice(-1)` se queda con la última línea, la de `conn29`. Los intentos de esta actividad no aparecen porque fallaron.

## Análisis

**¿Qué campo distingue un acceso fallido de uno exitoso?** El `id`, que identifica el tipo de evento: 5286306 es «Successfully authenticated» y 5286307 es «Failed to authenticate», lo mismo que dice `msg` en texto. También `result`: vale 0 cuando el acceso fue exitoso, y cuando falló trae el código del error, 18 para la contraseña incorrecta y 11 para el usuario inexistente.

**¿Qué diferencia hay entre el error de contraseña incorrecta y el de usuario inexistente? ¿Por qué el cliente recibe el mismo mensaje en ambos casos?** Con la contraseña incorrecta, el usuario existe y el servidor llegó a comprobar la contraseña. Con SCRAM, el servidor no guarda la contraseña, sino una clave derivada de ella (`storedKey`), y `storedKey mismatch` quiere decir que la prueba que mandó el cliente no coincidió con esa clave: `AuthenticationFailed`, código 18. Con el usuario inexistente, el servidor no encontró a nadie con quien comparar: `UserNotFound`, código 11. El cliente recibe en los dos casos `Authentication failed.` para no revelar cuál de las dos cosas pasó. Si el mensaje dijera que el usuario no existe, un atacante podría probar nombres hasta dar con los que sí existen y luego concentrarse en adivinar sus contraseñas. El detalle solo queda en la bitácora del servidor, que lee el DBA.

**¿Por qué el nombre de la aplicación del intento fallido es `mongosh 2.10.0` y no `app-ventas-web`?** En este servidor sale `mongosh 2.14.0`, la versión que trae la imagen; la guía usó la 2.10.0. Las cadenas de los intentos fallidos no llevan `appName=app-ventas-web`, y cuando no se declara un nombre, mongosh manda el suyo con su versión. El nombre de la aplicación lo declara el propio cliente al conectarse, y el servidor no lo comprueba: cualquiera podría poner `appName=app-ventas-web` en su cadena. Sirve para interpretar, pero no prueba qué programa se conectó.

## Conclusión

La bitácora de `mongod` registra cada intento de acceso con su usuario, su cliente, su conexión, su momento y la causa exacta del fallo, aunque al cliente solo le diga `Authentication failed.`. Con eso se pueden detectar intentos de entrada. Hay que contar intentos y no líneas, y no fiarse del nombre de la aplicación, porque lo pone el cliente.

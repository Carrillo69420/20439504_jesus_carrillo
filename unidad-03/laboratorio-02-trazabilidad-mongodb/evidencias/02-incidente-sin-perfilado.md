# Evidencia 02 — El incidente sin perfilado

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 2 (sección 8 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Reproducir el incidente con la configuración inicial: la tienda cambia el RFC de María García (`_id: 3`) con el perfilador apagado, y después se busca qué rastro dejó el cambio.

## Comandos

En la sesión del DBA, el estado del perfilador:

```javascript
db.getProfilingStatus()
```

En otra pestaña de PowerShell, la tienda cambia el RFC con la sesión de la aplicación:

```powershell
docker exec -it dba-u3-mongo mongosh "mongodb://app_ventas@127.0.0.1:27017/comercial?appName=app-ventas-web" --quiet --eval 'db.clientes.updateOne({ _id: 3 }, { $set: { rfc: \"GAMA780912XXX\" } })'
```

El código va entre comillas simples para que PowerShell no toque el `$set`. Las comillas dobles de adentro van como `\"`, porque PowerShell 5.1 las quita al pasarle el texto a `docker`.

De vuelta en la sesión del DBA, la búsqueda de evidencia:

```javascript
db.system.profile.countDocuments()
bitacora().filter(e => JSON.stringify(e).includes("GAMA780912XXX")).length
bitacora().filter(e => JSON.stringify(e).includes("app-ventas-web")).map(e => ({ t: e.t, c: e.c, ctx: e.ctx, msg: e.msg }))
```

## Resultado obtenido

```text
comercial> db.getProfilingStatus()
{ was: 0, slowms: 100, sampleRate: 1, ok: 1 }
```

La tienda, después de escribir la contraseña de `app_ventas`:

```text
{
  acknowledged: true,
  insertedId: null,
  matchedCount: 1,
  modifiedCount: 1,
  upsertedCount: 0
}
```

La búsqueda:

```text
comercial> db.system.profile.countDocuments()
0
comercial> bitacora().filter(e => JSON.stringify(e).includes("GAMA780912XXX")).length
0
comercial> bitacora().filter(e => JSON.stringify(e).includes("app-ventas-web")).map(e => ({ t: e.t, c: e.c, ctx: e.ctx, msg: e.msg }))
[
  {
    t: { '$date': '2026-11-05T17:33:50.703+00:00' },
    c: 'NETWORK',
    ctx: 'conn15',
    msg: 'client metadata'
  },
  {
    t: { '$date': '2026-11-05T17:33:50.703+00:00' },
    c: 'ACCESS',
    ctx: 'conn15',
    msg: 'Connection not authenticating'
  },
  {
    t: { '$date': '2026-11-05T17:33:50.709+00:00' },
    c: 'NETWORK',
    ctx: 'conn16',
    msg: 'client metadata'
  },
  {
    t: { '$date': '2026-11-05T17:33:50.716+00:00' },
    c: 'ACCESS',
    ctx: 'conn16',
    msg: 'Successfully authenticated'
  },
  {
    t: { '$date': '2026-11-05T17:33:50.801+00:00' },
    c: 'NETWORK',
    ctx: 'conn17',
    msg: 'client metadata'
  },
  {
    t: { '$date': '2026-11-05T17:33:50.802+00:00' },
    c: 'NETWORK',
    ctx: 'conn18',
    msg: 'client metadata'
  },
  {
    t: { '$date': '2026-11-05T17:33:50.809+00:00' },
    c: 'ACCESS',
    ctx: 'conn17',
    msg: 'Successfully authenticated'
  },
  {
    t: { '$date': '2026-11-05T17:33:50.810+00:00' },
    c: 'ACCESS',
    ctx: 'conn18',
    msg: 'Successfully authenticated'
  }
]
```

El perfilador está apagado (`was: 0`) y `system.profile` no tiene documentos. El RFC nuevo no aparece en ningún evento. Los únicos eventos que mencionan a la tienda son los de sus cuatro conexiones, a las 17:33:50 UTC (10:33:50 en Culiacán):

| Conexión | Eventos | ¿Se autenticó? |
| --- | --- | --- |
| `conn15` | `client metadata`, `Connection not authenticating` | No |
| `conn16` | `client metadata`, `Successfully authenticated` | Sí |
| `conn17` | `client metadata`, `Successfully authenticated` | Sí |
| `conn18` | `client metadata`, `Successfully authenticated` | Sí |

## Análisis

**¿Puedes demostrar qué cambió? ¿Y quién se conectó a esa hora?** No se puede demostrar qué cambió. Ni el perfilador ni la bitácora guardaron la operación, así que no queda el RFC nuevo ni el anterior, `GAMA780912GHI`. Quién se conectó sí se ve, a medias: la aplicación que se identificó como `app-ventas-web` abrió cuatro conexiones a las 17:33:50 UTC, y tres se autenticaron. El nombre `app-ventas-web` lo declara el propio cliente en su cadena de conexión, así que por sí solo no prueba quién era; lo que el servidor sí verifica es el usuario autenticado, que viene en esos mismos eventos y se revisa en la Actividad 5. Aun así, nada une esas conexiones con el cambio: solo se puede decir que la tienda se conectó, no que ella cambió el RFC.

**¿Por qué mongosh abre varias conexiones (conn8, conn9, …) para una sola instrucción? ¿Cuál es la que se autentica?** Porque el driver de mongosh separa la vigilancia del servidor de las operaciones. `conn15` es la conexión de monitoreo: solo le pregunta al servidor su estado y nunca se autentica, por eso registra `Connection not authenticating`. Las operaciones van por otras conexiones, que sí se autentican: `conn16`, `conn17` y `conn18`. Hay más de una porque mongosh, al conectarse, manda algunos comandos propios además de la instrucción, como `buildInfo` y `getParameter`, y cuando una conexión está ocupada el driver abre otra. Ningún evento muestra el `updateOne`, así que la bitácora no dice en cuál de ellas se ejecutó.

## Conclusión

Con el perfilador apagado, el cambio del RFC no dejó rastro de qué se modificó ni de quién lo hizo. Solo quedó que la tienda se conectó a esa hora. Para responder a Dirección, el registro tiene que estar activo antes del incidente, que es lo que se hace en la Actividad 3.

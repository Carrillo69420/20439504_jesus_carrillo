# Evidencia 03 — Perfilador en nivel 2

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 3 (sección 9 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Activar el perfilador en nivel 2 en la base `comercial`, hacer que la tienda ejecute una consulta, una actualización y una eliminación, y revisar qué guardó el perfilador de cada operación en `system.profile`.

## Comandos

En la sesión del DBA, el nivel 2 y su comprobación:

```javascript
db.setProfilingLevel(2)
db.getProfilingStatus()
```

En otra pestaña de PowerShell, la tienda consulta los clientes de Culiacán, cambia el RFC del cliente `_id: 3` y borra el cliente `_id: 2`, todo en una sola llamada de mongosh:

```powershell
docker exec -it dba-u3-mongo mongosh "mongodb://app_ventas@127.0.0.1:27017/comercial?appName=app-ventas-web" --quiet --eval 'db.clientes.find({ ciudad: \"Culiacán\" }, { nombre: 1, ciudad: 1 }).toArray(); db.clientes.updateOne({ _id: 3 }, { $set: { rfc: \"GAMA780912XYZ\" } }); db.clientes.deleteOne({ _id: 2 });'
```

Las comillas van igual que en la Actividad 2: el código entre comillas simples y las comillas dobles de adentro como `\"`.

De vuelta en la sesión del DBA, lo que el perfilador guardó de la colección `clientes`, ordenado por hora:

```javascript
db.system.profile.find({ ns: "comercial.clientes" }, { op: 1, ns: 1, command: 1, user: 1, client: 1, appName: 1, ts: 1, millis: 1, nreturned: 1, docsExamined: 1, nModified: 1, ndeleted: 1 }).sort({ ts: 1 })
```

Es la consulta de la guía, escrita en una sola línea. El primer argumento de `find` filtra por la colección (`ns`), el segundo elige los campos que se muestran y `sort({ ts: 1 })` ordena del más antiguo al más reciente.

## Resultado obtenido

```text
comercial> db.setProfilingLevel(2)
{ was: 0, slowms: 100, sampleRate: 1, ok: 1 }
comercial> db.getProfilingStatus()
{ was: 2, slowms: 100, sampleRate: 1, ok: 1 }
```

`setProfilingLevel` devuelve en `was` el nivel que había antes del cambio, 0, y `getProfilingStatus()` confirma que el vigente es 2. `slowms` sigue en 100 ms, pero en nivel 2 el perfilador registra todas las operaciones, sin importar cuánto tarden.

La tienda, después de escribir la contraseña de `app_ventas`:

```text
{ acknowledged: true, deletedCount: 1 }
```

Con `--eval`, mongosh solo imprime el resultado de la última instrucción, la del borrado.

El perfilador:

```text
comercial> db.system.profile.find({ ns: "comercial.clientes" }, { op: 1, ns: 1, command: 1, user: 1, client: 1, appName: 1, ts: 1, millis: 1, nreturned: 1, docsExamined: 1, nModified: 1, ndeleted: 1 }).sort({ ts: 1 })
[
  {
    op: 'query',
    ns: 'comercial.clientes',
    command: {
      find: 'clientes',
      filter: { ciudad: 'Culiacán' },
      projection: { nombre: 1, ciudad: 1 },
      lsid: { id: UUID('bbdf0d6d-e48f-4b13-af2c-8693d1d99758') },
      '$db': 'comercial'
    },
    docsExamined: 5,
    nreturned: 3,
    millis: 0,
    ts: ISODate('2026-11-05T17:52:12.538Z'),
    client: '127.0.0.1',
    appName: 'app-ventas-web',
    user: 'app_ventas@comercial'
  },
  {
    op: 'update',
    ns: 'comercial.clientes',
    command: {
      q: { _id: 3 },
      u: { '$set': { rfc: 'GAMA780912XYZ' } },
      multi: false,
      upsert: false
    },
    docsExamined: 1,
    nModified: 1,
    millis: 0,
    ts: ISODate('2026-11-05T17:52:12.541Z'),
    client: '127.0.0.1',
    appName: 'app-ventas-web',
    user: 'app_ventas@comercial'
  },
  {
    op: 'remove',
    ns: 'comercial.clientes',
    command: { q: { _id: 2 }, limit: 1 },
    docsExamined: 1,
    ndeleted: 1,
    millis: 0,
    ts: ISODate('2026-11-05T17:52:12.545Z'),
    client: '127.0.0.1',
    appName: 'app-ventas-web',
    user: 'app_ventas@comercial'
  }
]
```

Son tres documentos, uno por operación, registrados a las 17:52:12 UTC (10:52:12 en Culiacán). Los campos salen en el orden en que están guardados, no en el de la proyección. El `command` de la consulta trae dos campos que la guía resume con `...`: `lsid`, el identificador de la sesión que el driver agrega a cada comando, y `$db`, la base a la que se mandó.

### Interpretación (sección 9.1)

| # | op | Usuario | Cliente | Aplicación | Momento (UTC) | Qué hizo | Documentos afectados |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `query` | `app_ventas@comercial` | `127.0.0.1` | `app-ventas-web` | 17:52:12.538 | Buscó los clientes con `ciudad: "Culiacán"` y pidió solo `nombre` y `ciudad` | Revisó 5 y devolvió 3; no cambió ninguno |
| 2 | `update` | `app_ventas@comercial` | `127.0.0.1` | `app-ventas-web` | 17:52:12.541 | Cambió el `rfc` del documento `_id: 3` a `GAMA780912XYZ` | 1 modificado |
| 3 | `remove` | `app_ventas@comercial` | `127.0.0.1` | `app-ventas-web` | 17:52:12.545 | Borró el documento `_id: 2` | 1 eliminado |

Las tres operaciones duraron menos de un milisegundo (`millis: 0`).

## Análisis

**¿Puedes saber cuál era el RFC antes del cambio con la información de `system.profile`?** No. El documento del `update` solo guarda el filtro (`q: { _id: 3 }`) y el cambio (`u: { '$set': { rfc: 'GAMA780912XYZ' } }`), es decir, el valor nuevo. El anterior, `GAMA780912XXX`, que dejó la tienda en la Actividad 2, no aparece en ningún campo; se sabe solo por la evidencia 02.

**¿Puedes saber qué datos tenía el documento eliminado?** No. El documento del `remove` guarda el filtro (`q: { _id: 2 }`, `limit: 1`) y que se borró un documento (`ndeleted: 1`), pero no su contenido. Que era Carlos Pérez, con su correo, su teléfono y su RFC, se sabe solo por los datos de la sección 6.3. La consulta tampoco guarda lo que devolvió, solo cuántos documentos (`nreturned: 3`).

**A diferencia de `log_statement = 'mod'` en PostgreSQL, el nivel 2 sí registró la consulta. ¿Qué ventaja y qué riesgo tiene eso?** La ventaja es que también queda quién leyó los datos: se sabe que `app_ventas`, desde `app-ventas-web`, consultó los clientes de Culiacán y recibió tres, una lectura que con `'mod'` no habría quedado. Con datos personales importa saber quién los consultó, no solo quién los cambió. El riesgo es el volumen: como las lecturas suelen ser la mayoría de las operaciones, el nivel 2 puede degradar el rendimiento y llenar pronto `system.profile`, una colección limitada de 1 MB en la que los documentos más antiguos se sobrescriben (sección 4.3). Además, el perfilador guarda los filtros y los valores nuevos, como el RFC, así que `system.profile` también contiene datos personales y hay que restringir quién lo lee.

**¿Por qué el campo `user` incluye `@comercial`?** Porque en MongoDB un usuario se identifica por su nombre y por la base en la que se creó, que es donde se autentica. `app_ventas` se creó en `comercial` (sección 6.3), así que su nombre completo es `app_ventas@comercial`; el DBA, que se creó en `admin`, queda registrado como `admin@admin`. Así no se confunden dos usuarios con el mismo nombre en bases distintas.

## Conclusión

Con el nivel 2, el perfilador responde lo que faltó en la Actividad 2: quién hizo cada operación, desde dónde, con qué aplicación, cuándo y con qué comando, incluida la consulta. Lo que no guarda es el contenido anterior, ni el RFC de antes ni el documento borrado, así que sirve para reconstruir qué pasó, pero no para recuperar lo que se perdió. Como registra todo, en la Actividad 4 se reduce el volumen con un filtro.

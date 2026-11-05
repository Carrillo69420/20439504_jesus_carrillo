# Evidencia 04 — Filtro del perfilador

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 4 (sección 10 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Reducir lo que registra el perfilador a las operaciones que modifican datos, con un filtro, y ver qué evidencia se pierde y qué se gana. Como el procedimiento borra `system.profile`, antes se exporta lo que dejó la Actividad 3.

## Comandos

### 1. Exportar la Actividad 3 antes de borrar

La guía advierte que hay que exportar antes de borrar `system.profile`. La verificación final pide una consulta, una actualización y una eliminación de `app_ventas`, y con el filtro las consultas ya no se registran.

En la sesión del DBA, con el perfilador todavía en nivel 2:

```javascript
require("fs").writeFileSync("/tmp/system-profile-actividad3.json", EJSON.stringify(db.system.profile.find({}, { op: 1, ns: 1, command: 1, user: 1, client: 1, appName: 1, ts: 1, millis: 1, nreturned: 1, docsExamined: 1, nModified: 1, ndeleted: 1 }).sort({ ts: 1 }).toArray(), null, 2) + "\n")
```

mongosh corre sobre Node.js, así que `require("fs").writeFileSync` escribe un archivo. Como la sesión corre dentro del contenedor, el archivo queda en su `/tmp`. `EJSON.stringify` convierte los documentos a JSON extendido, que conserva los tipos de MongoDB (las fechas salen como `{"$date": …}`). Los campos son los de la evidencia 03, pero con `{}` en lugar del filtro por colección, para guardar todo lo que había. No se usó `>` como en la sección 14.2 de la guía porque en PowerShell 5.1 guarda el archivo en UTF-16 y cambia su hash, como se vio en el LAB-01.

En PowerShell, el hash dentro del servidor, la copia al repositorio y el hash en Windows. Aquí la ruta completa de la carpeta del laboratorio se abrevia con `...`, en los comandos y en su salida:

```powershell
docker exec dba-u3-mongo sh -c "cd /tmp && sha256sum system-profile-actividad3.json > hashes.sha256 && cat hashes.sha256"
docker cp dba-u3-mongo:/tmp/system-profile-actividad3.json "...\evidencias\system-profile-actividad3.json"
(Get-FileHash "...\evidencias\system-profile-actividad3.json" -Algorithm SHA256).Hash
```

### 2. El filtro

En la sesión del DBA, los pasos de la guía:

```javascript
db.setProfilingLevel(0)
db.system.profile.drop()
db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } })
db.getProfilingStatus()
```

Primero se apaga el perfilador, porque con el perfilador activo `drop()` falla. El filtro es una consulta sobre los campos de los documentos del perfilador: `$in` quiere decir que `op` sea alguno de los tres valores, o sea, solo las operaciones que modifican datos.

En otra pestaña de PowerShell, la tienda consulta a Ana López (`_id: 1`) y le cambia el teléfono:

```powershell
docker exec -it dba-u3-mongo mongosh "mongodb://app_ventas@127.0.0.1:27017/comercial?appName=app-ventas-web" --quiet --eval 'db.clientes.find({ _id: 1 }).toArray(); db.clientes.updateOne({ _id: 1 }, { $set: { telefono: \"6670000000\" } })'
```

Es el comando de la guía sin la contraseña y con las comillas como en la Actividad 3. La tienda se ejecutó dos veces. Después de la primera, la consulta del perfilador se pegó por error en la pestaña de PowerShell, que no la reconoce (`CommandNotFoundException`), y la tienda se volvió a correr antes de pasar la consulta a la sesión del DBA.

De vuelta en la sesión del DBA:

```javascript
db.system.profile.find({}, { op: 1, ns: 1, user: 1, appName: 1, "command.q": 1, "command.u": 1, ts: 1, nModified: 1 })
```

Es la consulta de la guía con `nModified` agregado, para distinguir las dos actualizaciones. `"command.q": 1` muestra solo el subcampo `q` de `command`; va entre comillas porque lleva un punto.

## Resultado obtenido

### Exportación

```text
a328c4113cb1fb144a4ed6af5b684770e5620c7f57d0eee82d7c96d8f321251a  system-profile-actividad3.json
Successfully copied 2.38kB (transferred 4.1kB) to ...\evidencias\system-profile-actividad3.json
A328C4113CB1FB144A4ED6AF5B684770E5620C7F57D0EEE82D7C96D8F321251A
```

Las dos huellas son la misma, una en minúsculas y la otra en mayúsculas: el archivo llegó igual a como salió del servidor. [`system-profile-actividad3.json`](system-profile-actividad3.json) tiene cuatro documentos:

| `ts` (UTC) | `op` | `ns` | `user` | `appName` |
| --- | --- | --- | --- | --- |
| 17:52:12.538 | `query` | `comercial.clientes` | `app_ventas@comercial` | `app-ventas-web` |
| 17:52:12.541 | `update` | `comercial.clientes` | `app_ventas@comercial` | `app-ventas-web` |
| 17:52:12.545 | `remove` | `comercial.clientes` | `app_ventas@comercial` | `app-ventas-web` |
| 17:52:19.276 | `query` | `comercial.system.profile` | `admin@admin` | `mongosh 2.14.0` |

Los tres primeros son las operaciones de la tienda de la evidencia 03. El cuarto es la consulta con la que el DBA leyó el perfilador en esa actividad: en nivel 2, el perfilador también registra al DBA. `hashes.sha256` se queda en el `/tmp` del contenedor, y en la Actividad 8 se le agregarán los otros dos archivos exportados. La carpeta del laboratorio tiene un `.gitattributes` que marca los archivos exportados con `-text`, como en el LAB-01, para que Git no les cambie los saltos de línea ni el hash.

### Filtro

```text
comercial> db.setProfilingLevel(0)
{ was: 2, slowms: 100, sampleRate: 1, ok: 1 }
comercial> db.system.profile.drop()
true
comercial> db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } })
{
  was: 0,
  slowms: 100,
  sampleRate: 1,
  note: 'When a filter expression is set, slowms and sampleRate are not used for profiling and slow-query log lines.',
  ok: 1
}
comercial> db.getProfilingStatus()
{
  was: 1,
  slowms: 100,
  sampleRate: 1,
  filter: { op: { '$in': [ 'insert', 'remove', 'update' ] } },
  note: 'When a filter expression is set, slowms and sampleRate are not used for profiling and slow-query log lines.',
  ok: 1
}
```

El perfilador estaba en nivel 2 desde la Actividad 3 (`was: 2`), `drop()` borró la colección (`true`) y ahora está en nivel 1 con el filtro. MongoDB guarda la lista en orden alfabético. La `note` dice que, con un filtro, `slowms` y `sampleRate` ya no se usan para el perfilado ni para las líneas de consulta lenta de la bitácora.

### La tienda

Como en la Actividad 3, mongosh pidió la contraseña de `app_ventas` y solo imprimió el resultado de la última instrucción, la actualización. La primera ejecución:

```text
{
  acknowledged: true,
  insertedId: null,
  matchedCount: 1,
  modifiedCount: 1,
  upsertedCount: 0
}
```

La segunda:

```text
{
  acknowledged: true,
  insertedId: null,
  matchedCount: 1,
  modifiedCount: 0,
  upsertedCount: 0
}
```

La primera vez cambió el teléfono de Ana López. La segunda encontró el documento (`matchedCount: 1`), pero no cambió nada, porque el teléfono ya tenía ese valor.

### El perfilador

```text
comercial> db.system.profile.find({}, { op: 1, ns: 1, user: 1, appName: 1, "command.q": 1, "command.u": 1, ts: 1, nModified: 1 })
[
  {
    op: 'update',
    ns: 'comercial.clientes',
    command: { q: { _id: 1 }, u: { '$set': { telefono: '6670000000' } } },
    nModified: 1,
    ts: ISODate('2026-11-05T18:07:58.978Z'),
    appName: 'app-ventas-web',
    user: 'app_ventas@comercial'
  },
  {
    op: 'update',
    ns: 'comercial.clientes',
    command: { q: { _id: 1 }, u: { '$set': { telefono: '6670000000' } } },
    nModified: 0,
    ts: ISODate('2026-11-05T18:08:28.872Z'),
    appName: 'app-ventas-web',
    user: 'app_ventas@comercial'
  }
]
```

Solo quedaron las dos actualizaciones, a las 18:07:58 y a las 18:08:28 UTC (11:07 y 11:08 en Culiacán). Las dos consultas `find({ _id: 1 })` no aparecen, porque el filtro las dejó fuera. La segunda actualización sí aparece aunque no cambió nada (`nModified: 0`): el filtro se fija en el tipo de operación, no en si modificó algo.

## Análisis

**¿Qué perdiste de evidencia al aplicar el filtro? ¿Qué ganaste?** Se perdieron las lecturas: la tienda consultó dos veces los datos de Ana López y no quedó rastro, así que ya no se puede saber quién consultó datos personales. Además, el procedimiento borró con `drop()` todo lo registrado antes; lo de la Actividad 3 se conserva solo porque se exportó primero. Se ganó espacio: en `system.profile` entran solo las operaciones que cambian datos, que son las que responden quién modificó qué, y en su límite de 1 MB caben muchas más antes de que se sobrescriban las antiguas. También afecta menos el rendimiento, porque el servidor escribe muchos menos documentos que con el nivel 2. Y como el filtro mira el tipo de operación, queda incluso el intento que no cambió nada.

**¿Qué filtro usarías si solo interesaran operaciones sobre la colección `clientes`?** El que filtra por `ns`, el campo con la base y la colección:

```javascript
db.setProfilingLevel(1, { filter: { ns: "comercial.clientes" } })
```

Así se registran todas las operaciones sobre `clientes`, también las consultas. Si solo interesaran las modificaciones, se combinan las dos condiciones: `{ filter: { op: { $in: ["insert", "update", "remove"] }, ns: "comercial.clientes" } }`.

## Conclusión

El filtro deja en `system.profile` solo las operaciones que cambian datos. Eso da menos volumen y más tiempo antes de que se sobrescriba, pero ya no deja rastro de las lecturas. Como `drop()` borró lo anterior, la evidencia de la Actividad 3 queda solo en el archivo exportado, con su hash.

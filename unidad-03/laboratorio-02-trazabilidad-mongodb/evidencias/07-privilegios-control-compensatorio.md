# Evidencia 07 — Cambios de privilegios y control compensatorio

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 7 (sección 13 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Otorgarle un rol adicional a la aplicación y buscar ese cambio en el perfilador y en la bitácora de `mongod`, para comprobar si MongoDB Community lo registra. Como no lo registra, se prueba un control compensatorio: guardar instantáneas de los usuarios y sus roles, y compararlas para saber si algo cambió.

## Comandos

Todo se ejecutó en la sesión del DBA.

### 1. Primera instantánea

```javascript
db.getSiblingDB("auditoria").instantaneas_privilegios.insertOne({ momento: new Date(), tomada_por: db.runCommand({ connectionStatus: 1 }).authInfo.authenticatedUsers, usuarios: db.getUsers().users.map(u => ({ user: u.user, db: u.db, roles: u.roles })) })
```

Es el comando de la guía en una sola línea. Guarda un documento en la colección `instantaneas_privilegios` de la base `auditoria`, separada de `comercial`. `getSiblingDB` usa otra base sin salir de la actual, y como la base y la colección no existían, MongoDB las creó al guardar el primer documento. El documento lleva el momento, el usuario que tomó la instantánea (`connectionStatus` dice con qué usuario está autenticada la sesión) y los usuarios de la base actual con sus roles (`getUsers`).

### 2. El cambio de privilegios

```javascript
db.setProfilingLevel(2, { filter: "unset" })
db.getProfilingStatus()
db.grantRolesToUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }])
```

La guía usa `db.setProfilingLevel(2)`, que cambia el nivel pero deja el filtro de la Actividad 4 en la configuración. En nivel 2 ese filtro no se aplica, porque el perfilador registra todas las operaciones, incluidas las que el filtro deja fuera. Aun así, se agregó `{ filter: "unset" }`, que lo quita, para que `getProfilingStatus()` mostrara que durante la prueba no había ningún filtro. `grantRolesToUser` le agrega a `app_ventas` el rol `dbAdmin` sobre `comercial`, un rol para administrar la base.

### 3. Buscar el cambio

```javascript
db.system.profile.countDocuments({ "command.grantRolesToUser": { $exists: true } })
bitacora().filter(e => JSON.stringify(e).includes("grantRoles")).length
```

Son las consultas de la guía. La primera cuenta los documentos del perfilador cuyo comando sea `grantRolesToUser`: `$exists: true` pide que el campo exista. La segunda convierte cada evento de la bitácora en texto con `JSON.stringify` y cuenta los que mencionan `grantRoles` en cualquier parte.

### 4. Segunda instantánea y comparación

Se repitió el `insertOne` del paso 1 y se compararon las dos instantáneas:

```javascript
db.getSiblingDB("auditoria").instantaneas_privilegios.find({}, { _id: 0 }).sort({ momento: 1 })
```

`{ _id: 0 }` oculta el identificador y `sort({ momento: 1 })` las ordena de la más antigua a la más reciente.

### 5. Dejar el servidor como estaba

```javascript
db.revokeRolesFromUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }])
db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } })
db.getProfilingStatus()
```

Como pide la guía, se quitó el rol y se volvió al filtro de la Actividad 4. `getProfilingStatus()` se agregó para comprobar la configuración final.

## Resultado obtenido

### Primera instantánea

```text
comercial> db.getSiblingDB("auditoria").instantaneas_privilegios.insertOne({ momento: new Date(), tomada_por: db.runCommand({ connectionStatus: 1 }).authInfo.authenticatedUsers, usuarios: db.getUsers().users.map(u => ({ user: u.user, db: u.db, roles: u.roles })) })
{
  acknowledged: true,
  insertedId: ObjectId('6aeccebbb89535722b81857a')
}
```

### El cambio y la búsqueda

```text
comercial> db.setProfilingLevel(2, { filter: "unset" })
{
  was: 1,
  slowms: 100,
  sampleRate: 1,
  filter: { op: { '$in': [ 'insert', 'remove', 'update' ] } },
  note: 'When a filter expression is set, slowms and sampleRate are not used for profiling and slow-query log lines.',
  ok: 1
}
comercial> db.getProfilingStatus()
{ was: 2, slowms: 100, sampleRate: 1, ok: 1 }
comercial> db.grantRolesToUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }])
{ ok: 1 }
comercial> db.system.profile.countDocuments({ "command.grantRolesToUser": { $exists: true } })
0
comercial> bitacora().filter(e => JSON.stringify(e).includes("grantRoles")).length
0
```

`setProfilingLevel` devuelve la configuración que había antes del cambio: nivel 1 con el filtro. `getProfilingStatus()` confirma que el nivel vigente es 2 y que ya no hay `filter`, así que el perfilador registraba todo. El rol se otorgó (`ok: 1`), pero los dos conteos dan 0, como en la guía: ni el perfilador ni la bitácora dejaron rastro del cambio.

### Comparación de las instantáneas

```text
comercial> db.getSiblingDB("auditoria").instantaneas_privilegios.find({}, { _id: 0 }).sort({ momento: 1 })
[
  {
    momento: ISODate('2026-11-05T18:45:15.552Z'),
    tomada_por: [ { user: 'admin', db: 'admin' } ],
    usuarios: [
      {
        user: 'app_ventas',
        db: 'comercial',
        roles: [ { role: 'readWrite', db: 'comercial' } ]
      }
    ]
  },
  {
    momento: ISODate('2026-11-05T18:46:46.122Z'),
    tomada_por: [ { user: 'admin', db: 'admin' } ],
    usuarios: [
      {
        user: 'app_ventas',
        db: 'comercial',
        roles: [
          { role: 'readWrite', db: 'comercial' },
          { role: 'dbAdmin', db: 'comercial' }
        ]
      }
    ]
  }
]
```

| Dato | Primera instantánea | Segunda instantánea |
| --- | --- | --- |
| `momento` (UTC) | 18:45:15.552 | 18:46:46.122 |
| Hora en Culiacán | 11:45:15 | 11:46:46 |
| `tomada_por` | `admin`, de la base `admin` | `admin`, de la base `admin` |
| Roles de `app_ventas` | `readWrite` sobre `comercial` | `readWrite` y `dbAdmin` sobre `comercial` |

Entre una instantánea y otra, `app_ventas` ganó el rol `dbAdmin`. En la guía, `dbAdmin` aparece antes que `readWrite`, y aquí después; el orden no importa, porque lo que se compara es qué roles tiene el usuario. Las instantáneas solo incluyen a `app_ventas` porque `getUsers()` lista los usuarios definidos en la base actual, `comercial`; `admin` está definido en la base `admin` y no aparece. Para incluir a los usuarios de todas las bases se puede usar `db.adminCommand({ usersInfo: { forAllDBs: true } })`.

| Pregunta | ¿La instantánea responde? |
| --- | --- |
| ¿Cambiaron los privilegios de `app_ventas`? | Sí: pasó de `readWrite` a `readWrite` y `dbAdmin`. |
| ¿Qué rol se agregó? | Sí: `dbAdmin` sobre `comercial`. |
| ¿Quién lo agregó? | No. `tomada_por` dice quién tomó cada instantánea, no quién hizo el cambio. |
| ¿Cuándo exactamente? | No, solo que ocurrió entre las 18:45:15 y las 18:46:46 UTC (11:45 y 11:46 en Culiacán), en un lapso de minuto y medio. |

### Revocación del rol y filtro

```text
comercial> db.revokeRolesFromUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }])
{ ok: 1 }
comercial> db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } })
{
  was: 2,
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

Se quitó el rol (`ok: 1`) y el perfilador quedó como al final de la Actividad 4: nivel 1 con el filtro de las operaciones que modifican datos.

## Análisis

**¿Por qué un cambio de privilegios es uno de los eventos auditables más importantes?** Porque decide qué puede hacer un usuario de ahí en adelante. Después del cambio, todo lo que haga con el nuevo rol parece autorizado, y si el cambio no quedó registrado, no se puede saber desde cuándo tiene ese permiso ni quién se lo dio. Por eso es el paso típico de una escalada de privilegios. El rol de esta actividad lo muestra. Las acciones de un rol se consultan con `db.getRole("dbAdmin", { showPrivileges: true })`, y las de `dbAdmin` incluyen `enableProfiler`, para cambiar el perfilador de `comercial`, `dropCollection` sobre `comercial.system.profile` y `dropDatabase`. Con `dbAdmin`, la tienda podría apagar el perfilador y borrar `system.profile`, es decir, el registro de sus propias operaciones, o incluso borrar la base completa. La bitácora conservaría la línea del cambio del perfilador, como en la evidencia 06, pero lo que había en `system.profile` se perdería.

**¿Con qué frecuencia tomarías instantáneas? ¿Qué factores influyen?** El lapso entre dos instantáneas es lo más que un cambio puede pasar sin detectarse, y también lo más que se puede acotar cuándo ocurrió. Influyen qué tan seguido cambian los privilegios de forma legítima (si casi nunca cambian, cualquier diferencia es una alerta), qué tan sensibles son los datos (aquí, datos personales de clientes, como el RFC), cuánto tiempo se puede tolerar un cambio sin detectarlo y el costo, que es bajo: cada instantánea es un documento pequeño, con un elemento por usuario. Para `comercial` tomaría una cada hora, más una antes y otra después de cada cambio planeado, y las compararía automáticamente con la anterior para avisar en cuanto haya una diferencia. Hay un límite que ninguna frecuencia resuelve: un rol que se otorga y se quita entre dos instantáneas no aparece en ninguna. Si en esta actividad el rol se hubiera quitado antes de la segunda instantánea, las dos habrían salido iguales.

**¿Quién debería poder escribir en `auditoria.instantaneas_privilegios`?** Solo el proceso que toma las instantáneas, con una cuenta propia que únicamente pueda agregar documentos a esa colección, sin modificarlos ni borrarlos. No deberían poder escribir ahí la aplicación ni los DBA del día a día, porque quien puede cambiar privilegios no debe poder corregir el registro que lo delataría. En esta actividad las instantáneas las tomó `admin`, que tiene el rol `root` y es el mismo usuario que otorgó el rol: podría haber editado o borrado la primera para ocultar el cambio. Como un usuario con `root` puede modificar cualquier colección del servidor, conviene además copiar las instantáneas fuera de MongoDB, a un lugar donde el DBA no pueda escribir.

**Redacta en tres líneas cómo comunicarías esta limitación a Dirección.**

> La edición de MongoDB que usamos, Community, no registra quién cambia los permisos de los usuarios ni cuándo.
>
> Para compensarlo, guardamos copias periódicas de los permisos y las comparamos: así sabremos qué cambió y entre qué horas, pero no quién lo hizo.
>
> Para saber quién, haría falta licenciar MongoDB Enterprise o usar Atlas, cuya auditoría registra cada cambio con el usuario y el momento.

La tercera línea se apoya en la [documentación de los mensajes de auditoría de MongoDB](https://www.mongodb.com/docs/manual/reference/audit-message/mongo/): el evento `grantRolesToUser` registra quién hizo el cambio (`users`), cuándo (`ts`), desde dónde (`remote`) y a quién le otorgó qué roles (`param`).

## Conclusión

MongoDB Community no deja rastro de un cambio de privilegios: con el perfilador en nivel 2 y sin filtro, el `grantRolesToUser` no quedó ni en `system.profile` ni en la bitácora. Las instantáneas compensan una parte, porque dicen qué cambió y entre qué momentos, pero no quién lo hizo, y no ven los cambios que se deshacen entre dos instantáneas. Para que sirvan, las debe tomar una cuenta distinta de la de quien administra los privilegios.

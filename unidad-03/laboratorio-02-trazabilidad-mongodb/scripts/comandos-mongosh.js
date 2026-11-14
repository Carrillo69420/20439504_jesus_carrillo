// =====================================================
// LAB-02 — Trazabilidad en MongoDB Community
// Comandos de mongosh, por actividad
// Secciones 6 a 14 de la guía (preparación y Actividades 1 a 8)
// Alumno: Jesús Arturo Carrillo Avilez
// =====================================================
// Reúne los comandos tal como se ejecutaron. No se corre de una sola vez:
// cada bloque dice en qué sesión va, y los resultados con su interpretación
// están en las evidencias 01 a 08. Las actividades 9 y 10 no llevan
// comandos: comparan y responden con lo obtenido aquí.
//
// Sesión del DBA, que entra a la base comercial (ahí, db es comercial):
//   docker exec -it dba-u3-mongo mongosh "mongodb://admin@127.0.0.1:27017/comercial?authSource=admin" --quiet
//
// Sesión de la aplicación, que se usó desde PowerShell con --eval:
//   docker exec -it dba-u3-mongo mongosh "mongodb://app_ventas@127.0.0.1:27017/comercial?appName=app-ventas-web" --quiet --eval '<código>'
// En --eval, el código va entre comillas simples y sus comillas dobles van
// como \", porque PowerShell 5.1 las quita al pasarle el texto a docker.
// Aquí el código de la tienda va con sus comillas normales.
//
// Ninguna cadena lleva la contraseña: mongosh la pide al conectarse.

// -----------------------------------------------------
// Preparación: usuarios y datos (sección 6.3)
// -----------------------------------------------------
// Sesión sin credenciales, que la excepción de localhost permite mientras
// no existe ningún usuario:
//   docker exec -it dba-u3-mongo mongosh --quiet
// En mongosh se cambia de base con «use admin» y «use comercial», que no es
// JavaScript; aquí va db.getSiblingDB, que trabaja sobre otra base sin salir
// de la actual. passwordPrompt() pide la contraseña sin mostrarla, así que
// no queda escrita en ningún comando.

db.getSiblingDB("admin").createUser({ user: "admin", pwd: passwordPrompt(), roles: ["root"] })
db.getSiblingDB("admin").auth("admin", passwordPrompt())

db.getSiblingDB("comercial").createUser({
  user: "app_ventas",
  pwd: passwordPrompt(),
  roles: [{ role: "readWrite", db: "comercial" }]
})

db.getSiblingDB("comercial").clientes.insertMany([
  { _id: 1, nombre: "Ana López", correo: "ana.lopez@example.test", telefono: "6671234567", rfc: "LOAA850315ABC", edad: 41, ciudad: "Culiacán", codigo_postal: "80000" },
  { _id: 2, nombre: "Carlos Pérez", correo: "carlos.perez@example.test", telefono: "6672345678", rfc: "PECA900720DEF", edad: 35, ciudad: "Culiacán", codigo_postal: "80100" },
  { _id: 3, nombre: "María García", correo: "maria.garcia@example.test", telefono: "6673456789", rfc: "GAMA780912GHI", edad: 47, ciudad: "Mazatlán", codigo_postal: "82000" },
  { _id: 4, nombre: "Luis Torres", correo: "luis.torres@example.test", telefono: "6674567890", rfc: "TOLU920201JKL", edad: 34, ciudad: "Los Mochis", codigo_postal: "81200" },
  { _id: 5, nombre: "Laura Sánchez", correo: "laura.sanchez@example.test", telefono: "6675678901", rfc: "SALA880525MNO", edad: 38, ciudad: "Culiacán", codigo_postal: "80200" }
])

// 12, las letras de «María García» con su espacio: los acentos llegaron completos
db.getSiblingDB("comercial").clientes.findOne({ _id: 3 }).nombre.length

// -----------------------------------------------------
// Función auxiliar (sección 6.4)
// -----------------------------------------------------
// Se define una vez en cada sesión del DBA: lee los eventos recientes de
// mongod con getLog y convierte cada línea en un objeto para filtrarla.

function bitacora() { return db.adminCommand({ getLog: "global" }).log.map(l => JSON.parse(l)) }

// -----------------------------------------------------
// Actividad 1 — Lo que no existe en esta edición (sección 7, evidencia 01)
// -----------------------------------------------------

db.version()
db.adminCommand({ buildInfo: 1 }).modules
db.serverCmdLineOpts().parsed

// En otra pestaña de PowerShell, fuera de mongosh:
//   docker logs dba-u3-mongo --tail 3

// -----------------------------------------------------
// Actividad 2 — El incidente sin perfilado (sección 8, evidencia 02)
// -----------------------------------------------------

db.getProfilingStatus()

// Sesión de la aplicación: la tienda cambia el RFC de María García
db.clientes.updateOne({ _id: 3 }, { $set: { rfc: "GAMA780912XXX" } })

// Sesión del DBA: la búsqueda de evidencia
db.system.profile.countDocuments()
bitacora().filter(e => JSON.stringify(e).includes("GAMA780912XXX")).length
bitacora().filter(e => JSON.stringify(e).includes("app-ventas-web")).map(e => ({ t: e.t, c: e.c, ctx: e.ctx, msg: e.msg }))

// -----------------------------------------------------
// Actividad 3 — Activar el perfilador y registrar operaciones (sección 9,
// evidencia 03)
// -----------------------------------------------------

db.setProfilingLevel(2)
db.getProfilingStatus()

// Sesión de la aplicación: las tres van en el mismo --eval, separadas por «;»
db.clientes.find({ ciudad: "Culiacán" }, { nombre: 1, ciudad: 1 }).toArray()
db.clientes.updateOne({ _id: 3 }, { $set: { rfc: "GAMA780912XYZ" } })
db.clientes.deleteOne({ _id: 2 })

// Sesión del DBA: lo que el perfilador guardó de clientes, de lo más antiguo
// a lo más reciente
db.system.profile.find({ ns: "comercial.clientes" }, { op: 1, ns: 1, command: 1, user: 1, client: 1, appName: 1, ts: 1, millis: 1, nreturned: 1, docsExamined: 1, nModified: 1, ndeleted: 1 }).sort({ ts: 1 })

// -----------------------------------------------------
// Actividad 4 — Reducir el volumen con un filtro (sección 10, evidencia 04)
// -----------------------------------------------------
// Primero se exporta lo de la Actividad 3, con el perfilador todavía en
// nivel 2, porque el procedimiento lo borra. writeFileSync escribe en el /tmp
// del contenedor; no se usó «>» porque PowerShell 5.1 guarda el archivo en
// UTF-16 y le cambia la huella.

require("fs").writeFileSync("/tmp/system-profile-actividad3.json", EJSON.stringify(db.system.profile.find({}, { op: 1, ns: 1, command: 1, user: 1, client: 1, appName: 1, ts: 1, millis: 1, nreturned: 1, docsExamined: 1, nModified: 1, ndeleted: 1 }).sort({ ts: 1 }).toArray(), null, 2) + "\n")

// En PowerShell, la huella dentro del contenedor, la copia al repositorio y
// la huella en Windows («...» es la ruta de la carpeta del laboratorio):
//   docker exec dba-u3-mongo sh -c "cd /tmp && sha256sum system-profile-actividad3.json > hashes.sha256 && cat hashes.sha256"
//   docker cp dba-u3-mongo:/tmp/system-profile-actividad3.json "...\evidencias\system-profile-actividad3.json"
//   (Get-FileHash "...\evidencias\system-profile-actividad3.json" -Algorithm SHA256).Hash

// El filtro. Primero se apaga el perfilador, porque con él activo drop() falla
db.setProfilingLevel(0)
db.system.profile.drop()
db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } })
db.getProfilingStatus()

// Sesión de la aplicación: la tienda consulta a Ana López y le cambia el
// teléfono (se corrió dos veces; la razón está en la evidencia 04)
db.clientes.find({ _id: 1 }).toArray()
db.clientes.updateOne({ _id: 1 }, { $set: { telefono: "6670000000" } })

// Sesión del DBA
db.system.profile.find({}, { op: 1, ns: 1, user: 1, appName: 1, "command.q": 1, "command.u": 1, ts: 1, nModified: 1 })

// -----------------------------------------------------
// Actividad 5 — Accesos en la bitácora de mongod (sección 11, evidencia 05)
// -----------------------------------------------------
// En PowerShell, dos intentos fallidos con la contraseña escrita en la
// cadena: app_ventas con una contraseña equivocada a propósito, y un usuario
// que no existe. Los comandos completos están en la evidencia 05; aquí van
// sin las contraseñas de prueba:
//   docker exec dba-u3-mongo mongosh "mongodb://app_ventas:<contraseña equivocada>@127.0.0.1:27017/comercial" --quiet --eval "db.clientes.countDocuments()"
//   docker exec dba-u3-mongo mongosh "mongodb://usuario_inexistente:<contraseña>@127.0.0.1:27017/comercial" --quiet --eval "db.clientes.countDocuments()"

// Sesión del DBA: los accesos fallidos y el último acceso exitoso de app_ventas
bitacora().filter(e => e.c === "ACCESS" && e.msg === "Failed to authenticate").map(e => ({ t: e.t, id: e.id, ctx: e.ctx, user: e.attr.user, client: e.attr.client, error: e.attr.error, result: e.attr.result, app: e.attr.doc.application.name }))
bitacora().filter(e => e.msg === "Successfully authenticated" && e.attr.user === "app_ventas").slice(-1).map(e => ({ t: e.t, id: e.id, ctx: e.ctx, client: e.attr.client, result: e.attr.result, app: e.attr.doc.application.name }))

// -----------------------------------------------------
// Actividad 6 — Correlacionar un cambio de configuración con su autor
// (sección 12, evidencia 06)
// -----------------------------------------------------

bitacora().filter(e => e.msg === "Profiler settings changed").map(e => ({ t: e.t, ctx: e.ctx, msg: e.msg, attr: e.attr }))

// conn13 es la conexión que dio la consulta anterior; la guía usa conn31
bitacora().filter(e => e.ctx === "conn13" && e.msg === "Successfully authenticated").map(e => ({ t: e.t, ctx: e.ctx, user: e.attr.user, db: e.attr.db, client: e.attr.client }))

// -----------------------------------------------------
// Actividad 7 — Cambios de privilegios: el límite más importante
// (sección 13, evidencia 07)
// -----------------------------------------------------

// Primera instantánea de los privilegios, en la base auditoria
db.getSiblingDB("auditoria").instantaneas_privilegios.insertOne({ momento: new Date(), tomada_por: db.runCommand({ connectionStatus: 1 }).authInfo.authenticatedUsers, usuarios: db.getUsers().users.map(u => ({ user: u.user, db: u.db, roles: u.roles })) })

// El cambio, con el perfilador en nivel 2. La guía usa setProfilingLevel(2);
// filter: "unset" quita además el filtro de la Actividad 4
db.setProfilingLevel(2, { filter: "unset" })
db.getProfilingStatus()
db.grantRolesToUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }])

// Buscar el cambio en el perfilador y en la bitácora
db.system.profile.countDocuments({ "command.grantRolesToUser": { $exists: true } })
bitacora().filter(e => JSON.stringify(e).includes("grantRoles")).length

// Segunda instantánea, con el mismo insertOne, y comparación de las dos
db.getSiblingDB("auditoria").instantaneas_privilegios.insertOne({ momento: new Date(), tomada_por: db.runCommand({ connectionStatus: 1 }).authInfo.authenticatedUsers, usuarios: db.getUsers().users.map(u => ({ user: u.user, db: u.db, roles: u.roles })) })
db.getSiblingDB("auditoria").instantaneas_privilegios.find({}, { _id: 0 }).sort({ momento: 1 })

// Dejar el servidor como estaba: sin el rol y con el filtro de la Actividad 4
db.revokeRolesFromUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }])
db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } })
db.getProfilingStatus()

// -----------------------------------------------------
// Actividad 8 — Conservación: exportar antes de perder (sección 14,
// evidencia 08)
// -----------------------------------------------------
// Se exporta antes de reiniciar, porque el reinicio vacía getLog.

bitacora().length
require("fs").writeFileSync("/tmp/system-profile.json", EJSON.stringify(db.system.profile.find({}, { op: 1, ns: 1, user: 1, client: 1, appName: 1, ts: 1, "command.q": 1, "command.u": 1 }).toArray(), null, 2) + "\n")

// Cada evento de getLog ya termina en salto de línea: por eso join("") y no
// el join("\n") de la guía, que dejaría una línea en blanco entre eventos
require("fs").writeFileSync("/tmp/bitacora-mongod.log", db.adminCommand({ getLog: "global" }).log.join(""))

// En PowerShell, las huellas, con «>>» para no perder la de la Actividad 4,
// la copia al repositorio y las huellas en Windows:
//   docker exec dba-u3-mongo sh -c "cd /tmp && sha256sum system-profile.json bitacora-mongod.log >> hashes.sha256 && cat hashes.sha256"
//   docker cp dba-u3-mongo:/tmp/system-profile.json "...\evidencias\system-profile.json"
//   docker cp dba-u3-mongo:/tmp/bitacora-mongod.log "...\evidencias\bitacora-mongod.log"
//   docker cp dba-u3-mongo:/tmp/hashes.sha256 "...\evidencias\hashes.sha256"
//   (Get-FileHash "...\evidencias\system-profile.json" -Algorithm SHA256).Hash
//   (Get-FileHash "...\evidencias\bitacora-mongod.log" -Algorithm SHA256).Hash

// El reinicio: se sale de la sesión del DBA con exit y, en PowerShell,
//   docker restart dba-u3-mongo
// Luego se abre una sesión nueva del DBA y se vuelve a definir bitacora(),
// porque las funciones de mongosh solo existen en la sesión que las define.

db.getProfilingStatus()
db.system.profile.countDocuments()
bitacora().length
bitacora().filter(e => e.msg === "Profiler settings changed").length
bitacora().filter(e => e.msg === "Successfully authenticated").map(e => ({ t: e.t, ctx: e.ctx, user: e.attr.user }))
db.system.profile.stats().maxSize

// En PowerShell, los cambios del perfilador que conserva la bitácora del
// contenedor:
//   (docker logs dba-u3-mongo | Select-String -SimpleMatch "Profiler settings changed").Count

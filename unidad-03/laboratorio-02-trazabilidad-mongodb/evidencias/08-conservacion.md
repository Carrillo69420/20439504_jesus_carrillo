# Evidencia 08 — Conservación: exportar antes de perder

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 8 (sección 14 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Exportar `system.profile` y la bitácora de `mongod` con su huella SHA-256, y reiniciar el servidor para ver qué evidencia sobrevive al reinicio y cuál se pierde.

## Comandos

### 1. Exportar antes de reiniciar

La guía pone el reinicio (14.1) antes de las exportaciones (14.2 y 14.3), pero en la 14.3 advierte que hay que exportar antes de reiniciar, porque el reinicio vacía la memoria de `getLog`. Por eso aquí se exportó primero.

En la sesión del DBA:

```javascript
bitacora().length
require("fs").writeFileSync("/tmp/system-profile.json", EJSON.stringify(db.system.profile.find({}, { op: 1, ns: 1, user: 1, client: 1, appName: 1, ts: 1, "command.q": 1, "command.u": 1 }).toArray(), null, 2) + "\n")
require("fs").writeFileSync("/tmp/bitacora-mongod.log", db.adminCommand({ getLog: "global" }).log.join(""))
```

`bitacora().length` cuenta los eventos que hay en la memoria de `getLog`, para compararlos después del reinicio. Las dos exportaciones son las consultas de las secciones 14.2 y 14.3, escritas con `writeFileSync` dentro del contenedor, como en la Actividad 4, en lugar de redirigirlas con `>`, que en PowerShell 5.1 guarda el archivo en UTF-16; `+ "\n"` termina el JSON con un salto de línea. `getLog` devuelve cada evento como un texto que ya termina en salto de línea, así que se unen con `join("")`; con el `join("\n")` de la guía quedaría una línea en blanco después de cada evento.

En PowerShell, las huellas dentro del servidor, la copia al repositorio y las huellas en Windows. Como en la evidencia 04, la ruta completa de la carpeta del laboratorio se abrevia con `...`, en los comandos y en su salida:

```powershell
docker exec dba-u3-mongo sh -c "cd /tmp && sha256sum system-profile.json bitacora-mongod.log >> hashes.sha256 && cat hashes.sha256"
docker cp dba-u3-mongo:/tmp/system-profile.json "...\evidencias\system-profile.json"
docker cp dba-u3-mongo:/tmp/bitacora-mongod.log "...\evidencias\bitacora-mongod.log"
docker cp dba-u3-mongo:/tmp/hashes.sha256 "...\evidencias\hashes.sha256"
(Get-FileHash "...\evidencias\system-profile.json" -Algorithm SHA256).Hash
(Get-FileHash "...\evidencias\bitacora-mongod.log" -Algorithm SHA256).Hash
```

El `hashes.sha256` del contenedor ya tenía la huella del archivo exportado en la Actividad 4. `>>` agrega las dos nuevas al final; con `>` se habría reemplazado el archivo y esa línea se habría perdido.

### 2. Reiniciar

Se cerró la sesión del DBA con `exit` y se reinició el servidor con el comando de la tabla A.1 de la guía para este despliegue:

```powershell
docker restart dba-u3-mongo
```

Luego se abrió una nueva sesión del DBA, con la misma cadena de siempre, y se volvió a definir `bitacora()`, porque las funciones de mongosh solo existen en la sesión en que se definen.

### 3. Revisar después del reinicio

En la nueva sesión del DBA:

```javascript
db.getProfilingStatus()
db.system.profile.countDocuments()
bitacora().length
bitacora().filter(e => e.msg === "Profiler settings changed").length
bitacora().filter(e => e.msg === "Successfully authenticated").map(e => ({ t: e.t, ctx: e.ctx, user: e.attr.user }))
db.system.profile.stats().maxSize
```

Las tres primeras son las comprobaciones de la sección 14.1. Las otras se agregaron para ver si siguen en memoria los cambios del perfilador, si la cuenta de conexiones volvió a empezar y cuál es el tamaño máximo de `system.profile`: `stats()` da los datos de almacenamiento de una colección, y `maxSize` es el tamaño máximo de una colección de tamaño limitado, en bytes.

En PowerShell, los cambios del perfilador en la bitácora del contenedor:

```powershell
(docker logs dba-u3-mongo | Select-String -SimpleMatch "Profiler settings changed").Count
```

`Select-String` deja pasar solo las líneas que contienen el texto; con `-SimpleMatch`, el texto se busca tal cual, sin tratarlo como expresión regular. `.Count` cuenta las líneas que pasaron.

## Resultado obtenido

### Exportación

```text
comercial> bitacora().length
388
```

Los dos `writeFileSync` no imprimen nada. En PowerShell:

```text
a328c4113cb1fb144a4ed6af5b684770e5620c7f57d0eee82d7c96d8f321251a  system-profile-actividad3.json
f3f9492d2af7fe44478eb8517d7fc097ac331a6d69c58ab1c3085f8e645066a8  system-profile.json
2885c072a00d7e226185ca1aa5db46e9026f03c80f3b8501f86068a7c1c3cc69  bitacora-mongod.log
Successfully copied 965B (transferred 2.56kB) to ...\evidencias\system-profile.json
Successfully copied 158kB (transferred 160kB) to ...\evidencias\bitacora-mongod.log
Successfully copied 269B (transferred 2.05kB) to ...\evidencias\hashes.sha256
F3F9492D2AF7FE44478EB8517D7FC097AC331A6D69C58AB1C3085F8E645066A8
2885C072A00D7E226185CA1AA5DB46E9026F03C80F3B8501F86068A7C1C3CC69
```

Las huellas calculadas en Windows son las mismas que dentro del servidor, en mayúsculas: los archivos llegaron sin cambios. [`hashes.sha256`](hashes.sha256) quedó con las tres:

| Archivo | Contenido | SHA-256 |
| --- | --- | --- |
| [`system-profile-actividad3.json`](system-profile-actividad3.json) | Los cuatro documentos de la Actividad 3, exportados en la Actividad 4 | `a328c411…` |
| [`system-profile.json`](system-profile.json) | Los tres documentos que había en `system.profile` | `f3f9492d…` |
| [`bitacora-mongod.log`](bitacora-mongod.log) | Los 388 eventos de `getLog`, uno por línea | `2885c072…` |

Los documentos de `system-profile.json`:

| `ts` (UTC) | `op` | `ns` | `user` | `appName` |
| --- | --- | --- | --- | --- |
| 18:07:58.978 | `update` | `comercial.clientes` | `app_ventas@comercial` | `app-ventas-web` |
| 18:08:28.872 | `update` | `comercial.clientes` | `app_ventas@comercial` | `app-ventas-web` |
| 18:45:35.489 | `command` | `comercial.system.profile` | `admin@admin` | `mongosh 2.14.0` |

Los dos primeros son las actualizaciones de la tienda de la Actividad 4, que pasaron el filtro. El tercero es del DBA, en la Actividad 7: el `countDocuments` con que se buscó el `grantRolesToUser`, que mongosh ejecuta como un comando `aggregate` sobre `system.profile`. Su `command` sale vacío porque la proyección de la guía solo incluye `q` y `u`, los campos de una actualización. Según la bitácora, el perfilador estuvo en nivel 2 sin filtro de las 18:45:18 a las 18:47:00, y ese documento es lo único que registró en ese lapso: estaba registrando, y aun así el cambio de rol no aparece, como se vio en la evidencia 07.

`bitacora-mongod.log` va desde el arranque del servidor, a las 17:14:47 UTC, hasta las 19:09:48 UTC. Como el servidor llevaba 388 eventos, menos que los 1024 que guarda `getLog`, el archivo tiene la historia completa desde el arranque; coincide línea por línea con las primeras 388 líneas de `docker logs`. Incluye los eventos interpretados en las actividades anteriores:

| Evento (`msg`) | Líneas | Qué registra |
| --- | --- | --- |
| `Successfully authenticated` | 17 | Los accesos exitosos del DBA y de la tienda |
| `Failed to authenticate` | 3 | Los dos intentos fallidos de la Actividad 5 (el del usuario inexistente deja dos líneas) |
| `Profiler settings changed` | 5 | Los cambios del perfilador de las actividades 3, 4 y 7 |
| `CMD: drop` | 1 | El `drop()` de `system.profile` en la Actividad 4 |
| `Slow query` | 2 | Las dos actualizaciones de la tienda en la Actividad 4 |

Las dos líneas `Slow query` no son consultas lentas. Como avisaba la `note` de `setProfilingLevel` en la Actividad 4, con un filtro ya no se usa `slowms` para las líneas de consulta lenta: lo que pasa el filtro también se escribe en la bitácora.

### Reinicio

```text
dba-u3-mongo
```

Según `docker logs`, `mongod` recibió la señal de apagado a las 19:14:57.966 UTC (12:14 en Culiacán), terminó de apagarse a las 19:14:58.014 y volvió a arrancar a las 19:14:58.608.

### Después del reinicio

```text
comercial> db.getProfilingStatus()
{ was: 0, slowms: 100, sampleRate: 1, ok: 1 }
comercial> db.system.profile.countDocuments()
3
comercial> bitacora().length
78
comercial> bitacora().filter(e => e.msg === "Profiler settings changed").length
0
comercial> bitacora().filter(e => e.msg === "Successfully authenticated").map(e => ({ t: e.t, ctx: e.ctx, user: e.attr.user }))
[
  {
    t: { '$date': '2026-11-05T19:15:11.209+00:00' },
    ctx: 'conn2',
    user: 'admin'
  },
  {
    t: { '$date': '2026-11-05T19:15:11.306+00:00' },
    ctx: 'conn3',
    user: 'admin'
  },
  {
    t: { '$date': '2026-11-05T19:15:11.307+00:00' },
    ctx: 'conn4',
    user: 'admin'
  }
]
comercial> db.system.profile.stats().maxSize
1048576
```

En PowerShell:

```text
5
```

| Qué se revisó | Antes del reinicio | Después del reinicio |
| --- | --- | --- |
| Configuración del perfilador | Nivel 1 con el filtro de la Actividad 4 | Nivel 0, sin filtro |
| Documentos en `system.profile` | 3 | 3 |
| Eventos en `getLog` | 388 | 78 |
| `Profiler settings changed` en `getLog` | 5 | 0 |
| `Profiler settings changed` en `docker logs` | 5 | 5 |
| Números de conexión | De `conn1` a `conn34` | Otra vez desde `conn1` |

El reinicio no borró lo que estaba en disco: `system.profile` conserva sus tres documentos, uno más que en la guía por el `countDocuments` de la Actividad 7, y `docker logs` sigue teniendo los cinco cambios del perfilador. Se perdió lo que vivía en la memoria de `mongod`. El perfilador volvió al nivel 0 y el filtro desapareció, así que desde el reinicio no se registra ninguna operación. `getLog` empezó de cero, con solo los 78 eventos del nuevo arranque y de la sesión nueva. La cuenta de conexiones también volvió a empezar: la nueva sesión del DBA se autenticó en `conn2`, `conn3` y `conn4`, números que antes del reinicio ya habían usado otras conexiones. Por eso, como se dijo en la evidencia 06, un `ctx` solo identifica una conexión dentro del mismo arranque. `maxSize` confirma que `system.profile` puede crecer hasta 1 MB (1 048 576 bytes).

### Configuración permanente

La sección 14.1 muestra cómo hacer permanentes el perfilado y la bitácora con el archivo de configuración de `mongod`: `systemLog.destination: file`, `systemLog.path` y `systemLog.logAppend: true` para que la bitácora se escriba en un archivo que sobrevive a los reinicios, y `operationProfiling.mode` para que el perfilador arranque en el nivel elegido, en todas las bases. Es opcional y no se aplicó. Este servidor arranca con `--auth` en la línea de comandos, sin archivo de configuración, así que en cada reinicio el perfilador vuelve al nivel 0 y la bitácora solo sale por la salida del contenedor, que es la que guarda `docker logs`.

## Análisis

**Menciona tres formas en que la evidencia del perfilador o de la bitácora puede perderse sin que nadie la borre deliberadamente.**

1. **Un reinicio.** Cualquier reinicio, planeado o por una falla, regresa el perfilador al nivel 0 y vacía `getLog`, como se vio aquí. Desde ese momento no se registra ninguna operación hasta que alguien vuelva a activar el perfilador, y ese paso al nivel 0 no deja ningún «Profiler settings changed» en la bitácora: nada avisa que se dejó de registrar.
2. **La sobrescritura de `system.profile`.** Es una colección de tamaño limitado, de 1 MB. Cuando se llena, MongoDB sobrescribe los documentos más antiguos para hacer lugar a los nuevos.
3. **El límite de `getLog`.** Solo guarda los últimos 1024 eventos, y los más antiguos salen de la memoria conforme llegan los nuevos, aunque el servidor no se reinicie. En este servidor, los avisos de punto de control de WiredTiger, el motor de almacenamiento (componente `WTCHKPT`), salieron uno por minuto, 115 entre las 17:15:47 y las 19:09:48, así que por sí solos llenarían los 1024 eventos en unas 17 horas, aunque nadie usara la base.

Además, la bitácora completa solo queda en la salida del contenedor, que se pierde si se elimina el contenedor.

**¿Por qué el tamaño de 1 MB de `system.profile` es un problema de conservación y no solo de espacio?** Porque al llenarse no deja de registrar ni avisa: sobrescribe los documentos más antiguos. El problema no es que falte lugar para lo nuevo, sino que lo viejo desaparece sin que nadie lo borre. Cada documento del perfilador ocupa alrededor de 1 KB, así que en 1 MB caben unas mil operaciones; con el nivel 2 y una tienda con tráfico, eso puede ser cuestión de minutos. Cuánto tiempo se conserva la evidencia no lo decide una política de retención, sino el tráfico. Darle más tamaño a `system.profile` solo alarga ese plazo: para conservar hay que exportar antes de que se sobrescriba, con su huella, como se hizo con `system-profile-actividad3.json` antes del `drop()` de la Actividad 4.

**¿Por qué `getLog` sirve para interpretar pero no para conservar?** Porque lee la memoria de `mongod`: guarda solo los últimos 1024 eventos y se vacía en cada reinicio. Aquí pasó de 388 eventos a 78, y los cinco cambios del perfilador ya no están en `getLog`, aunque `docker logs` los conserva. Para interpretar es muy cómodo: se consulta desde mongosh, sin tener acceso a los archivos del servidor, y con `bitacora()` cada evento se filtra y se correlaciona, como en las actividades 5 y 6. Pero lo que no se exporte desaparece con el siguiente reinicio o cuando lleguen otros 1024 eventos. Para conservar, la bitácora se escribe en un archivo que sobreviva a los reinicios (`systemLog.path` con `logAppend`) o se exporta con su huella, como `bitacora-mongod.log`.

## Conclusión

El reinicio mostró qué evidencia vive en disco y cuál en memoria: `system.profile` y `docker logs` sobrevivieron, pero la configuración del perfilador y `getLog` se perdieron. Ninguno de los dos mecanismos sirve para conservar por sí solo: `system.profile` se sobrescribe al llegar a 1 MB, y `getLog` guarda solo los últimos 1024 eventos hasta el siguiente reinicio. Por eso la evidencia se exportó antes del reinicio, con su huella en `hashes.sha256`.

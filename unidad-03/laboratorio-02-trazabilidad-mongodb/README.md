# LAB-02 — Trazabilidad en MongoDB Community

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad III, temas 3.1 Auditoría de bases de datos y 3.2 Bitácoras y trazabilidad
- Entorno: MongoDB 7.0.45 Community en Docker (contenedor `dba-u3-mongo`, con la base `comercial`) y mongosh 2.14.0
- Fecha: 5 de noviembre de 2026

Este README explica cómo se desplegó el servidor y qué versión tiene, como pide la sección 18 de la guía, y relaciona cada actividad con su evidencia. Las evidencias están en `evidencias/`, en Markdown, con el comando, el resultado y su interpretación.

| Actividad | Evidencia |
| --- | --- |
| 1. Lo que no existe en esta edición | [01-edicion-y-limitacion.md](evidencias/01-edicion-y-limitacion.md) |
| 2. El incidente sin perfilado | [02-incidente-sin-perfilado.md](evidencias/02-incidente-sin-perfilado.md) |

## Objetivo

Configurar e interpretar los mecanismos de trazabilidad que sí tiene MongoDB Community, el perfilador y la bitácora de `mongod`; identificar qué eventos auditables cubren y cuáles no, y explicar qué añadiría la auditoría nativa de las ediciones Enterprise y Atlas (sección 2 de la guía).

## Despliegue del servidor

Se creó un servidor nuevo para el laboratorio con la imagen oficial `mongo:7`, como indica el Anexo A.2 de la guía para contenedores:

```powershell
docker run -d --name dba-u3-mongo -v dba-u3-mongo-data:/data/db mongo:7 --auth
```

Lo que va después del nombre de la imagen se entrega a `mongod`: `--auth` habilita el control de acceso, igual que `security.authorization: enabled` en un archivo de configuración.

Diferencias con el comando de la guía:

- **Sin `-p 27017:27017`.** Todo se ejecuta dentro del contenedor con `docker exec`, así que las conexiones llegan desde `127.0.0.1`, como en los resultados de la guía. El Anexo A.2 advierte que, por el puerto publicado, `client` mostraría la dirección de la red interna del contenedor. Además, el servidor no queda expuesto en el equipo.
- **Volumen con nombre `dba-u3-mongo-data`.** Los datos quedan en un volumen fácil de identificar, que se conserva aunque haya que recrear el contenedor.
- **Sin `-e TZ`.** A diferencia del LAB-01, donde se usó `TZ=America/Mazatlan`, aquí las marcas de tiempo quedan en UTC. El perfilador guarda `ts` como fecha UTC y mongosh la muestra así; sin `TZ`, la bitácora de `mongod` usa la misma zona, y los dos registros se comparan sin conversiones. La hora de Culiacán es UTC−7: las 17:18 UTC son las 10:18.

### Versión

| Comando | Resultado |
| --- | --- |
| `db.version()` | `7.0.45` |
| `db.adminCommand({ buildInfo: 1 }).modules` | `[]`, es decir, Community |

La comprobación completa está en la [evidencia 01](evidencias/01-edicion-y-limitacion.md). El cliente es mongosh 2.14.0, que viene dentro de la imagen; con ese nombre aparecen sus conexiones en la bitácora.

### Sesiones (sección 6.2)

| Sesión | Cómo se abre |
| --- | --- |
| DBA (`admin`) | `docker exec -it dba-u3-mongo mongosh "mongodb://admin@127.0.0.1:27017/comercial?authSource=admin" --quiet` |
| Aplicación (`app_ventas`) | `docker exec -it dba-u3-mongo mongosh "mongodb://app_ventas@127.0.0.1:27017/comercial?appName=app-ventas-web" --quiet` |

Son las cadenas de la sección 6.2 sin la contraseña. Como falta, mongosh la pide al conectarse, y así no queda escrita en el comando. `authSource=admin` indica que el usuario del DBA está definido en la base `admin`, y `appName=app-ventas-web` es el nombre con que la aplicación aparece en el perfilador y en la bitácora.

### Usuarios y datos (sección 6.3)

El primer usuario se creó con la excepción de localhost: se abrió `docker exec -it dba-u3-mongo mongosh --quiet`, sin credenciales, y se siguió el orden de la Unidad II, `use admin`, `createUser` y `db.auth`. Quedaron así:

- `admin`, definido en la base `admin`, con el rol `root`.
- `app_ventas`, definido en `comercial`, con `readWrite` sobre `comercial`.
- La colección `comercial.clientes`, con los cinco clientes ficticios de la sección 6.3. Para comprobar que los acentos llegaron completos, `db.clientes.findOne({ _id: 3 }).nombre.length` devolvió `12`, las letras de «María García» con su espacio.

Las contraseñas se escribieron con `passwordPrompt()`, para que no quedaran en ningún comando. Son valores de práctica y no se incluyen en este repositorio.

### Función auxiliar (sección 6.4)

En cada sesión del DBA se define `bitacora()`, que lee los eventos recientes de `mongod` con `getLog` y convierte cada línea en un objeto para poder filtrarla. Es la función de la guía, escrita en una sola línea:

```javascript
function bitacora() { return db.adminCommand({ getLog: "global" }).log.map(l => JSON.parse(l)) }
```

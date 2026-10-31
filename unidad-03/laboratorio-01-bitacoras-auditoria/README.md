# LAB-01 — Bitácoras y auditoría del dato en PostgreSQL

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad III, temas 3.1 Auditoría de bases de datos y 3.2 Bitácoras y trazabilidad
- Entorno: PostgreSQL 16.15 en Docker (contenedor `dba-u3-pg`, con la base `comercial`)
- Fechas: 29 y 31 de octubre de 2026

Este README explica cómo se desplegó el servidor y qué versión tiene, como pide la sección 27 de la guía, y relaciona cada actividad con su script y su evidencia. Las evidencias están en `evidencias/`, en Markdown, con el comando, el resultado y su interpretación. El informe, la verificación final y la reflexión están en [informe.md](informe.md).

| Actividad | Script | Evidencia |
| --- | --- | --- |
| 1. Configuración de registro por defecto | — | [01-configuracion-inicial.md](evidencias/01-configuracion-inicial.md) |
| 2. Que el servidor administre su propia bitácora | [01-colector-y-vista.sql](sql/01-colector-y-vista.sql) | [02-colector.md](evidencias/02-colector.md) |
| 3. El incidente sin bitácora | — | [03-incidente-sin-bitacora.md](evidencias/03-incidente-sin-bitacora.md) |
| 4. Configurar la bitácora | [02-configuracion-bitacora.sql](sql/02-configuracion-bitacora.sql) | [04-configuracion-bitacora.md](evidencias/04-configuracion-bitacora.md) |
| 5. Accesos exitosos y fallidos | — | [05-accesos.md](evidencias/05-accesos.md) |
| 6. Cambios de privilegios y de estructura | [03-privilegios-estructura.sql](sql/03-privilegios-estructura.sql) | [06-privilegios-estructura.md](evidencias/06-privilegios-estructura.md) |
| 7. Modificaciones de datos: ddl frente a mod | — | [07-modificaciones.md](evidencias/07-modificaciones.md) |
| 8. Errores y operaciones rechazadas | — | [08-errores.md](evidencias/08-errores.md) |
| 9. Sesiones activas con `pg_stat_activity` | — | [09-pg-stat-activity.md](evidencias/09-pg-stat-activity.md) |
| 10. Diseño del registro de auditoría | [04-esquema-auditoria.sql](sql/04-esquema-auditoria.sql) | [10-diseno-auditoria.md](evidencias/10-diseno-auditoria.md) |
| 11. Función y disparador de auditoría | [05-funcion-disparador.sql](sql/05-funcion-disparador.sql) | [10-diseno-auditoria.md](evidencias/10-diseno-auditoria.md), segunda parte |
| 12. El incidente auditado | [06-campos-modificados.sql](sql/06-campos-modificados.sql) | [11-incidente-auditado.md](evidencias/11-incidente-auditado.md) |
| 13. Altas y bajas | — | [12-altas-bajas.md](evidencias/12-altas-bajas.md) |
| 14. Intentar manipular la auditoría | — | [13-manipulacion.md](evidencias/13-manipulacion.md) |
| 15. Límites: lecturas y volumen | — | [14-limites.md](evidencias/14-limites.md) |
| 16. Exportar y conservar la bitácora | — | [15-cronologia.md](evidencias/15-cronologia.md), pasos 1 a 5; [bitacora-lab01.log](evidencias/bitacora-lab01.log) y [bitacora-lab01.sha256](evidencias/bitacora-lab01.sha256) |
| 17. Reconstruir la cronología | — | [15-cronologia.md](evidencias/15-cronologia.md), pasos 6 y 7 |

## Objetivo

Configurar la bitácora de PostgreSQL y una auditoría a nivel de dato, de modo que se puedan demostrar los accesos, los cambios de privilegios y de estructura, las modificaciones de datos con su valor anterior, los errores y los cambios de configuración. Después, interpretar esos registros como evidencia de lo ocurrido (sección 2 de la guía).

## Despliegue del servidor

Se creó un servidor nuevo para la unidad con la imagen oficial `postgres:16`, como indica el Anexo A de la guía para contenedores:

```powershell
docker run -d --name dba-u3-pg -e POSTGRES_PASSWORD=<REDACTED> -e POSTGRES_DB=comercial -e TZ=America/Mazatlan -v dba-u3-pg-data:/var/lib/postgresql/data postgres:16
```

Diferencias con el comando de la guía:

- **Sin `-p 5432:5432`.** El puerto 5432 del equipo lo ocupa un PostgreSQL instalado en Windows. Todo se ejecuta dentro del contenedor con `docker exec`, así que las sesiones por red llegan desde `127.0.0.1`, igual que en la verificación de la guía.
- **Volumen con nombre `dba-u3-pg-data` y sin `--rm`.** El LAB-03 continúa sobre este mismo servidor (sección 26).
- **`TZ=America/Mazatlan`.** La bitácora queda en la hora del Pacífico de México (UTC−7) y no en UTC.

No se usó `dba-practica`, el servidor de la Unidad II. El LAB-04 ya le había activado el registro de conexiones y había endurecido su `pg_hba.conf`, y este laboratorio parte de la configuración por defecto.

### Identificación desde el motor (sección 6.3)

| Consulta | Resultado |
| --- | --- |
| `SELECT version();` | `PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit` |
| `SHOW data_directory;` | `/var/lib/postgresql/data` |
| `SHOW config_file;` | `/var/lib/postgresql/data/postgresql.conf` |
| `SHOW hba_file;` | `/var/lib/postgresql/data/pg_hba.conf` |

### Sesiones (sección 6.2)

| Sesión | Cómo se abre |
| --- | --- |
| Administrador | `docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off`, por el socket local. `-P pager=off` evita que una salida ancha abra el paginador. |
| Por red | `docker exec -it dba-u3-pg psql -W "postgresql://<usuario>@127.0.0.1/comercial?application_name=<aplicacion>"`. `-W` hace que `psql` pida la contraseña antes de conectarse, así que no queda escrita en el comando. |

### Autenticación (sección 6.4)

Las reglas por TCP para `127.0.0.1` y `::1` venían en `trust`. Se cambiaron a `scram-sha-256` con el comando `sed` del Anexo A (tabla A.2) y se recargó la configuración con `SELECT pg_reload_conf();`:

| Línea | Tipo | Dirección | Antes | Después |
| --- | --- | --- | --- | --- |
| 117 | local | — | trust | trust |
| 119 | host | 127.0.0.1 | trust | scram-sha-256 |
| 121 | host | ::1 | trust | scram-sha-256 |
| 128 | host | all | scram-sha-256 | scram-sha-256 |

La regla `local` se dejó en `trust`, como indica la guía. Es la de la sesión de administrador, y al socket solo se llega desde dentro del contenedor.

**¿Por qué una regla `trust` afecta lo que la bitácora puede demostrar sobre la identidad del usuario?** Con `trust`, el servidor acepta el nombre de usuario que diga el cliente sin pedirle ninguna prueba. Cualquiera que llegue por 127.0.0.1 podría entrar como `app_ventas` o como `postgres`. La bitácora registraría `user=app_ventas`, pero eso solo diría qué nombre se usó, no que lo usó alguien que conoce la contraseña, y además nunca habría un acceso fallido que registrar. Con `scram-sha-256`, el usuario que aparece en la bitácora tuvo que demostrar que conoce su contraseña. Es lo mismo que se hizo en el LAB-04 de la Unidad II, donde `pg_hba.conf` quedó sin reglas `trust`: la autenticación es lo que le da valor a la identidad que registra la bitácora.

### Datos y roles (sección 6.5)

- Tabla `clientes` con los cinco clientes ficticios de la Unidad II.
- Rol `app_ventas`, la aplicación de ventas, con SELECT y UPDATE sobre `clientes`.
- Rol `soporte_ana`, la analista de soporte, con SELECT.
- Las contraseñas se asignaron con `\password`, para que no quedaran escritas en ninguna sentencia. Son valores de práctica y no se incluyen en este repositorio.

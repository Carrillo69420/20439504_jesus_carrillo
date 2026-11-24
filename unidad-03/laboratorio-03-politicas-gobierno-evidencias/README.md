# LAB-03 — Políticas, gobierno de datos y evidencias

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad III, evidencia oficial de la unidad: «Configuración o diseño de auditoría con bitácora interpretada»
- Entorno: PostgreSQL 16.15 en Docker (contenedor `dba-u3-pg`, el del LAB-01, con la base `comercial`) y los archivos exportados del LAB-02 (MongoDB 7.0.45)
- Fecha: 24 de noviembre de 2026

Este README relaciona cada actividad con su evidencia. Las evidencias están en `evidencias/`, en Markdown, con el comando, el resultado y su interpretación, y los scripts, en `sql/`.

| Actividad | Evidencia |
| --- | --- |
| 1. Calidad de datos desde la operación | [01-calidad.md](evidencias/01-calidad.md) y el script [01-verificaciones-calidad.sql](sql/01-verificaciones-calidad.sql) |
| 2. Propietarios, custodios y usuarios | [02-responsables.md](evidencias/02-responsables.md) |
| 3. Diccionario de datos operativo dentro del motor | [03-diccionario.md](evidencias/03-diccionario.md), el script [02-comentarios-diccionario.sql](sql/02-comentarios-diccionario.sql) y el archivo exportado [diccionario-clientes.csv](evidencias/diccionario-clientes.csv) |
| 4. Catálogo mínimo de datos | [04-catalogo.md](evidencias/04-catalogo.md) y el script [03-inventario-tablas.sql](sql/03-inventario-tablas.sql) |
| 5. Criterio de conservación de bitácoras | [05-conservacion.md](evidencias/05-conservacion.md) |
| 6. Políticas prácticas de datos | [POL-01 Acceso](politicas/POL-01-acceso.md), [POL-02 Respaldo](politicas/POL-02-respaldo.md), [POL-03 Retención](politicas/POL-03-retencion.md), [POL-04 Restauración](politicas/POL-04-restauracion.md), [POL-05 Uso de datos sensibles](politicas/POL-05-datos-sensibles.md) y [POL-06 Cambios en producción](politicas/POL-06-cambios-produccion.md) |

## Objetivo

Construir los elementos mínimos de gobierno práctico de datos para la base `comercial` (calidad, propietarios, catálogo, diccionario, criterio de conservación, políticas prácticas y registro de cambios) y relacionarlos con las evidencias técnicas de los laboratorios anteriores en un expediente para auditoría interna (sección 2 de la guía).

## Entorno

Se usa el servidor del LAB-01, como pide la sección 6 de la guía. Su despliegue está explicado en el [README del LAB-01](../laboratorio-01-bitacoras-auditoria/README.md). La sesión de administrador se abre igual que entonces:

```powershell
docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off
```

### Preparación (sección 6)

| Comando | Resultado |
| --- | --- |
| `\dn` | `auditoria`, `dba` y `public` |
| `SHOW log_statement;` | `mod` |
| `SELECT count(*) FROM dba.bitacora;` | `8` |

El contenedor se arrancó el 24 de noviembre a las 08:32:01, y PostgreSQL abrió un archivo de bitácora nuevo, `postgresql-2026-11-24_083201.log`. Sus 8 líneas eran las 6 del arranque y las 2 de la conexión de la sesión. `dba.bitacora` solo lee el archivo actual (`pg_current_logfile()`): lo que se registró en el LAB-01 sigue en los archivos del 29 y del 31 de octubre, en el directorio `log` del servidor.

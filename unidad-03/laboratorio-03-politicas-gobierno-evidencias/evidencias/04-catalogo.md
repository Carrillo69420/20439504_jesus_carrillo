# Evidencia 04 — Catálogo mínimo de datos

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 4 (sección 10 de la guía)
- Servidores: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`, y `dba-u3-mongo`, MongoDB 7.0.45 en Docker, el del LAB-02
- Fecha: 24 de noviembre de 2026

## Objetivo

Reunir en un catálogo los conjuntos de datos de la empresa en los dos motores: dónde está cada uno, quién responde por él, si contiene datos personales, para qué existe, cuánto se conserva y dónde está su diccionario.

## Pasos y resultados

Los pasos 1 y 2 se ejecutaron en la sesión de administrador de `dba-u3-pg`. Las sentencias están en [sql/03-inventario-tablas.sql](../sql/03-inventario-tablas.sql); aquí van como se escribieron en `psql`, cada una en una línea. Los datos de MongoDB salen de los archivos del LAB-02: para este catálogo no se abrió su servidor.

### 1. Inventario técnico de las tablas

```sql
ANALYZE;
SELECT n.nspname AS esquema, c.relname AS tabla, pg_get_userbyid(c.relowner) AS propietario_tecnico, c.reltuples::bigint AS filas_estimadas, pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano, obj_description(c.oid, 'pg_class') AS descripcion FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'information_schema') ORDER BY 1, 2;
```

```text
ANALYZE
  esquema  |      tabla       | propietario_tecnico | filas_estimadas | tamano |                                                                 descripcion
-----------+------------------+---------------------+-----------------+--------+----------------------------------------------------------------------------------------------------------------------------------------------
 auditoria | cambios_clientes | postgres            |              10 | 32 kB  |
 public    | clientes         | postgres            |               7 | 24 kB  | Clientes de Comercializadora Norte. Propietario: Gerencia Comercial. Custodio: DBA. Clasificación: confidencial (contiene datos personales).
(2 rows)
```

- Fuera de los esquemas del sistema hay dos tablas, `clientes` y `auditoria.cambios_clientes`. `gobierno.solicitudes_cambio` (CAT-03) todavía no existe: se crea en la Actividad 7.
- Las estimaciones coinciden con lo que se sabe de cada tabla. `clientes` tiene 7 filas: las 5 que cambió el `UPDATE` sin `WHERE` de la Actividad 15 del LAB-01 ([evidencia 14 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/14-limites.md)) y los registros 7 y 8 de la Actividad 1 ([evidencia 01](01-calidad.md)). `cambios_clientes` tiene 10 eventos: los 8 que había al terminar esa actividad del LAB-01 (1 `DELETE`, 1 `INSERT` y 6 `UPDATE`) y los 2 `INSERT` de la Actividad 1, porque el disparador también registra las altas.
- `propietario_tecnico` es `postgres` en las dos: es la cuenta dueña del objeto en el motor, la que puede modificarlo o borrarlo. No es el propietario del dato, que para `clientes` es la Gerencia Comercial y para `cambios_clientes`, Auditoría interna ([evidencia 02](02-responsables.md)).
- Solo `clientes` tiene descripción, la que se le puso en la Actividad 3 ([evidencia 03](03-diccionario.md)). `cambios_clientes` no tiene comentario.
- `ANALYZE` no quedó en la bitácora de hoy: con `log_statement = 'mod'` no se registra.

### 2. La vista que la consulta deja fuera

```sql
SELECT n.nspname AS esquema, c.relname AS vista, pg_get_userbyid(c.relowner) AS propietario_tecnico, obj_description(c.oid, 'pg_class') AS descripcion FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind = 'v' AND n.nspname NOT IN ('pg_catalog', 'information_schema') ORDER BY 1, 2;
```

```text
 esquema |  vista   | propietario_tecnico | descripcion
---------+----------+---------------------+-------------
 dba     | bitacora | postgres            |
(1 row)
```

Esta consulta no viene en la guía. La guía advierte que la del paso 1 solo lista tablas (`relkind = 'r'`) y deja fuera la vista `dba.bitacora`, aunque también debe inventariarse. Con `relkind = 'v'` aparece, y es la única vista fuera de los esquemas del sistema, también sin comentario. La vista no guarda datos: lee el archivo actual de la bitácora. Por eso el conjunto que se cataloga es la bitácora completa, los archivos del directorio `log` y la vista con que se consultan (CAT-06).

### 3. El catálogo

En la ubicación se usa el formato que pide la guía, `servidor / base / esquema.objeto`, con los nombres de los contenedores. En MongoDB, el último nivel es la colección. Las dos bitácoras no son objetos de una base: su ubicación es donde el servidor las escribe.

| ID | Conjunto de datos | Motor | Ubicación | Propietario | Custodio | Clasificación | Contiene datos personales | Finalidad | Conservación | Diccionario |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| CAT-01 | Clientes | PostgreSQL 16 | `dba-u3-pg` / `comercial` / `public.clientes` | Gerencia Comercial | DBA | Confidencial | Sí | Identificar, contactar y facturar a los clientes; estadísticas | Por dato, según la Unidad II: lo fiscal, cinco años; lo demás, mientras sea cliente | [diccionario-clientes.csv](diccionario-clientes.csv) |
| CAT-02 | Auditoría de clientes | PostgreSQL 16 | `dba-u3-pg` / `comercial` / `auditoria.cambios_clientes` | Auditoría interna | DBA | Confidencial | Sí: la fila completa, antes y después del cambio | Saber quién cambió qué dato de un cliente y cuándo | Actividad 5 | No tiene; la estructura está en [el script del LAB-01](../../laboratorio-01-bitacoras-auditoria/sql/04-esquema-auditoria.sql) |
| CAT-03 | Registro de cambios | PostgreSQL 16 | `dba-u3-pg` / `comercial` / `gobierno.solicitudes_cambio` | Comité de cambios | DBA | Interna | No, si registra áreas y no personas | Comprobar que cada cambio tuvo folio, aprobación y ventana | La fija el Comité de cambios | El comentario de la tabla (Actividad 7) |
| CAT-04 | Clientes (tienda) | MongoDB 7 | `dba-u3-mongo` / `comercial` / `clientes` | Gerencia Comercial | DBA | Confidencial | Sí | Las de CAT-01, para la tienda | La de CAT-01 | No tiene; los campos están en [el script del LAB-02](../../laboratorio-02-trazabilidad-mongodb/scripts/comandos-mongosh.js) |
| CAT-05 | Perfilado | MongoDB 7 | `dba-u3-mongo` / `comercial` / `system.profile` | Auditoría interna | DBA | Confidencial | Sí: las operaciones perfiladas, con su filtro y sus valores | Diagnosticar el rendimiento y saber quién hizo cada operación | Actividad 5 | No tiene; los campos los define MongoDB |
| CAT-06 | Bitácora de PostgreSQL | PostgreSQL 16 | `dba-u3-pg` / directorio `log`; se consulta con `comercial` / `dba.bitacora` | Auditoría interna | DBA | Confidencial | Sí: las sentencias con sus valores | Saber quién se conectó y qué cambió | Actividad 5 | No tiene; el formato de cada línea lo fija `log_line_prefix` ([LAB-01, sql/02](../../laboratorio-01-bitacoras-auditoria/sql/02-configuracion-bitacora.sql)) |
| CAT-07 | Bitácora de `mongod` | MongoDB 7 | `dba-u3-mongo` / salida del contenedor (`docker logs`) | Auditoría interna | DBA | Confidencial | Sí: las operaciones lentas, con su comando | Saber quién se conectó, desde dónde, y qué operaciones fueron lentas | Actividad 5 | No tiene; cada evento es un JSON que define MongoDB |
| CAT-08 | Instantáneas de privilegios | MongoDB 7 | `dba-u3-mongo` / `auditoria` / `instantaneas_privilegios` | Auditoría interna | DBA | Confidencial | No: cuentas y roles, no datos de clientes | Detectar cambios de privilegios comparando instantáneas | Actividad 5 | No tiene; los campos están en [la evidencia 07 del LAB-02](../../laboratorio-02-trazabilidad-mongodb/evidencias/07-privilegios-control-compensatorio.md) |

- **Los conjuntos.** Son los cinco de la guía y tres más, los mismos de la matriz de la [evidencia 02](02-responsables.md): la bitácora de PostgreSQL, por la advertencia del paso 2; la de `mongod`, y las instantáneas de privilegios del LAB-02. El propietario y el custodio de cada uno son los de esa matriz.
- **Clasificación.** Se usan dos niveles. *Confidencial*: solo lo leen quienes lo necesitan, porque contiene datos personales, como dice el comentario de `clientes`, o información de seguridad, como las instantáneas de privilegios. *Interna*: no tiene datos personales ni de seguridad; no se publica, pero lo puede consultar el personal que trabaja con él.
- **Datos personales en la auditoría y en las bitácoras.** Se explican en la pregunta 1. En las dos bitácoras también hay ejemplos: la de PostgreSQL guardó el `UPDATE` con el RFC nuevo del cliente 3 ([evidencia 13 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/13-manipulacion.md)), y en la de `mongod` exportada en el LAB-02, las dos operaciones lentas guardan el teléfono nuevo del cliente 1 ([bitacora-mongod.log](../../laboratorio-02-trazabilidad-mongodb/evidencias/bitacora-mongod.log)).
- **Conservación.** La de los clientes es la política de retención de la Unidad II ([evidencia 10 de su LAB-03](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/10-retencion.md)): los datos fiscales de las facturas, cinco años (CFF, art. 30); el contacto y las estadísticas, mientras sea cliente. CAT-04 tiene los mismos datos y el mismo propietario, así que sigue la misma política. Los plazos de la auditoría, las bitácoras y las instantáneas se fijan en la Actividad 5. El del registro de cambios no está en esa actividad: lo decide su propietario, el Comité de cambios.
- **CAT-03** se llenó con lo que ya está decidido: el propietario de la evidencia 02 y las columnas que da la guía para la Actividad 7. En el ejemplo de la guía, `solicitado_por` y `aprobado_por` guardan áreas (`'Gerencia Comercial'`, `'Comité de cambios'`). Si guardaran nombres de personas, o si una descripción nombrara a un cliente, CAT-03 tendría datos personales y pasaría a confidencial.
- **Bitácora de `mongod`.** El contenedor del LAB-02 se creó sin indicar un archivo para la bitácora ([README del LAB-02](../../laboratorio-02-trazabilidad-mongodb/README.md)), así que `mongod` la escribe en su salida estándar, que guarda Docker (`docker logs`). `getLog` solo lee los últimos eventos que hay en memoria y se vacía en cada reinicio ([evidencia 08 del LAB-02](../../laboratorio-02-trazabilidad-mongodb/evidencias/08-conservacion.md)).

## Preguntas

**1. ¿Por qué CAT-02 y CAT-05 contienen datos personales aunque su propósito sea la auditoría?**

Porque para demostrar qué cambió hay que guardar el dato que cambió y quién lo cambió:

- `auditoria.cambios_clientes` guarda la fila completa antes y después de cada cambio, con `to_jsonb(OLD)` y `to_jsonb(NEW)` ([LAB-01, sql/05](../../laboratorio-01-bitacoras-auditoria/sql/05-funcion-disparador.sql)): nombre, correo, teléfono, RFC y los demás campos, aunque el cambio haya sido de una sola columna. Con eso se comparó en el LAB-01 el RFC actual del cliente 3 con el último RFC auditado ([evidencia 13 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/13-manipulacion.md)).
- `system.profile` guarda cada operación perfilada con su filtro y su cambio. En el LAB-02, el documento del `update` guardó el teléfono nuevo del cliente 1, `"$set": { "telefono": "6670000000" }`, junto con la cuenta y la aplicación que lo hicieron ([system-profile.json](../../laboratorio-02-trazabilidad-mongodb/evidencias/system-profile.json)).

Por eso se clasifican igual que los datos que registran y necesitan la misma protección: acceso restringido y un plazo de conservación propio. Si se borra un cliente de `clientes`, sus datos siguen en la auditoría y en el perfilado hasta que venza ese plazo. Lo mismo pasa con las dos bitácoras (CAT-06 y CAT-07).

**2. ¿Qué pasa si CAT-01 y CAT-04 tienen propietarios distintos y el RFC de un cliente difiere entre ambos motores?**

Que nadie tiene autoridad para decir cuál es el correcto. Los dos guardan el nombre, el correo, el teléfono y el RFC de los clientes, y en este entorno nada los sincroniza: el `id` de PostgreSQL y el `_id` de MongoDB son independientes, y ninguno apunta al otro. Con dos propietarios:

- Cada uno defendería su copia, y el desacuerdo terminaría en el DBA, que es custodio de las dos y acabaría decidiendo sin tener la autoridad para hacerlo (el riesgo de la pregunta 3 de la [evidencia 02](02-responsables.md)).
- La factura puede salir con el RFC equivocado, según el sistema del que se tome.
- Si el cliente pide corregir su RFC, la corrección puede quedar en un motor y no en el otro, y la copia sin corregir seguiría en uso.

Por eso la matriz de la evidencia 02 les dio el mismo propietario, la Gerencia Comercial: decide cuál copia manda y aprueba las correcciones en las dos. Si tuvieran que tener propietarios distintos, harían falta una regla escrita sobre cuál motor manda en el RFC y una conciliación periódica entre los dos.

**3. ¿Qué información del catálogo cambia con más frecuencia y quién debe actualizarla?**

- **Lo técnico, que cambia todos los días.** Las filas y el tamaño del paso 1, y la lista de tablas, que crecerá en la Actividad 7 con `gobierno.solicitudes_cambio`. Lo actualiza el DBA, como custodio, volviendo a correr la consulta del paso 1 en lugar de copiarlo a mano.
- **Lo que cambia con la estructura.** Al agregar una columna, como `canal_alta` en el ejemplo de la Actividad 7, cambian el diccionario y a veces la clasificación y la finalidad. El DBA avisa del cambio, y el propietario decide la clasificación y la finalidad, con el folio de la solicitud que lo autorizó.
- **Lo de gobierno, que cambia poco.** El propietario, la clasificación, la finalidad y la conservación cambian cuando cambia la organización o la ley. Los actualiza el propietario de cada conjunto; en la conservación interviene también el área jurídica.

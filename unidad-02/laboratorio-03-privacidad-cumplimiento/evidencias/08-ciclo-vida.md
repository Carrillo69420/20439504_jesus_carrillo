# Evidencia 08 — Cancelación y ciclo de vida de los datos

LAB-03, Actividad 8 (sección 14 de la guía). No se borró nada: como pide la guía, antes de cualquier DELETE se revisó dónde más están los datos de la persona. El caso es el de Ana López (id 1), la misma persona de las Actividades 6 y 7.

## Objetivo

Antes de cumplir una cancelación ya autorizada, encontrar todos los lugares donde están los datos de Ana López, armar el mapa que pide la guía y explicar por qué borrar su renglón de `clientes` no basta.

## Procedimiento

Se partió de la Actividad 6, donde los datos de Ana aparecieron en cuatro tablas, y después se revisó lo demás en dos partes.

**Dentro de la base**, con cinco consultas de solo lectura. Las tablas y vistas que existen:

```sql
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
```

Las llaves foráneas:

```sql
SELECT conrelid::regclass AS tabla, pg_get_constraintdef(oid) AS llave
FROM pg_constraint
WHERE contype = 'f';
```

Si hay réplicas, archivado de WAL o registro de sentencias:

```sql
SELECT (SELECT count(*) FROM pg_stat_replication) AS replicas,
       (SELECT count(*) FROM pg_replication_slots) AS slots,
       current_setting('archive_mode') AS archive_mode,
       current_setting('log_statement') AS log_statement;
```

Las versiones viejas de renglones que siguen guardadas en `clientes` (tuplas muertas):

```sql
SELECT schemaname, relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'clientes';
```

La posición física de cada renglón (`ctid`: página y número de renglón):

```sql
SELECT ctid, id, nombre
FROM clientes
ORDER BY ctid;
```

**Fuera de la base:**

- Los archivos del contenedor, con `\! ls -la /tmp` desde psql (psql corre dentro del contenedor), y el historial de psql (`/root/.psql_history`).
- El repositorio y su historial, con `git log --all -S "ana.lopez@example.test"`, que dice en qué commit entró su correo.
- La carpeta `Imágenes\Capturas de pantalla` de OneDrive.

## Resultado

### Respuestas a las preguntas de la guía

| Pregunta | Respuesta en este entorno |
| --- | --- |
| ¿Existen otras tablas relacionadas? | Sí, cuatro. `clientes_soporte` (Actividad 2) tiene su id, nombre, correo y teléfono. `pii.mapa_cliente` (LAB-01) une su id con un token. `analitica.clientes` (LAB-01) guarda con ese token su edad, ciudad, código postal y fecha de alta exactos. `clientes_protegidos` (LAB-02) tiene su nombre y un RFC cifrado. Solo `pii.mapa_cliente` tiene llave foránea hacia `clientes`. |
| ¿Existen respaldos? | No se encontró ninguno: en los laboratorios no se ha hecho ningún `pg_dump`, y el archivado de WAL está apagado (`archive_mode = off`). |
| ¿Existen réplicas? | No: `pg_stat_replication` y `pg_replication_slots` no tienen renglones. |
| ¿Existen registros de auditoría? | No. El servidor no registra las sentencias (`log_statement = none`), y su log solo guarda las que dieron error, ninguna con datos de Ana. Lo que sí hay son registros de sesión con sus datos: `/tmp/lab02.log`, `/tmp/lab03.log` y el historial de psql. |
| ¿Existen copias utilizadas para analítica? | Sí, `analitica.clientes`. La vista `v_analitica_clientes` no cuenta: no guarda datos, se calcula desde `clientes`. |
| ¿Existen archivos exportados? | Sí. El script `sql/01-clasificacion.sql` del LAB-01 trae su renglón completo. El 23/10/2026, nueve archivos de texto de la carpeta del repositorio mencionaban a Ana, y los PDF de las Actividades 2, 6 y 7 tienen capturas con sus datos. |
| ¿Existen sistemas externos? | Sí. GitHub tiene una copia del repositorio con todo su historial, y OneDrive sincroniza con la nube la carpeta del repositorio y las capturas de pantalla. |

### Mapa

```text
clientes (Ana López, id 1)
   │
   ├── la misma tabla: la versión vieja de su renglón, con el correo anterior
   │
   ├── tablas relacionadas
   │      ├── clientes_soporte: copia de la Actividad 2, todavía con el correo anterior
   │      ├── pii.mapa_cliente: su id y su token; la única con llave hacia clientes
   │      │      └── analitica.clientes: edad, ciudad, código postal y fecha de alta exactos
   │      └── clientes_protegidos: su nombre y un RFC cifrado; sin llave, se busca por nombre
   │
   ├── respaldos: no hay (ningún pg_dump; archive_mode = off)
   │
   ├── réplicas: no hay (pg_stat_replication y pg_replication_slots vacíos)
   │
   ├── reportes: capturas en los PDF de las Actividades 2, 6 y 7
   │
   ├── exportaciones y registros
   │      ├── sql/01-clasificacion.sql (LAB-01): su renglón completo, en Git desde el 14/10/2026
   │      ├── /tmp/lab02.log: el RFC del LAB-02 en claro, aunque en la tabla está cifrado
   │      ├── /tmp/lab03.log: consultas y resultados con su correo, su teléfono y su RFC
   │      └── /root/.psql_history: consultas con su correo, su teléfono y los dos RFC
   │
   └── sistemas externos
          ├── GitHub: el repositorio con todo su historial
          └── OneDrive: la carpeta del repositorio y las capturas de pantalla
```

### Qué pasaría hoy con el DELETE

La llave foránea de `pii.mapa_cliente` se creó en el LAB-01 (`sql/03-seudonimizacion.sql`) sin `ON DELETE`, así que PostgreSQL aplica la regla por defecto: no deja borrar a un cliente mientras su token siga en el mapa. Se probó en `dba-ensayo`, un contenedor de práctica armado con los mismos scripts, dentro de una transacción que se deshizo con `ROLLBACK`:

```text
ERROR:  update or delete on table "clientes" violates foreign key constraint "mapa_cliente_cliente_id_fkey" on table "mapa_cliente"
DETAIL:  Key (id)=(1) is still referenced from table "mapa_cliente".
```

En `dba-practica` no se ejecutó ningún DELETE.

Las otras tres copias no lo detendrían, pero tampoco se enterarían: `clientes_soporte`, `analitica.clientes` y `clientes_protegidos` no tienen llave hacia `clientes`, así que conservarían los datos de Ana después del borrado. Ya pasó con la rectificación de la Actividad 7: `clientes` cambió el correo y la copia de soporte se quedó con el anterior.

Ni siquiera dentro de `clientes` desaparece el renglón al momento. En PostgreSQL, un UPDATE o un DELETE no quita en ese instante la versión vieja del renglón; la quita después VACUUM (manual de PostgreSQL 16, sección 25.1.2). La consulta a `pg_stat_user_tables` marca una tupla muerta en `clientes` y ningún VACUUM, y el `ctid` muestra dónde está: los renglones de los otros cuatro clientes siguen en las posiciones 2 a 5 de la página 0, pero el de Ana ahora está en la 6. El UPDATE de la Actividad 7 escribió una versión nueva, y la vieja, con el correo anterior, se queda en la posición 1 hasta que pase VACUUM.

Fuera de la tabla, todo cambio se escribe primero en el WAL (manual, sección 30.3). En este servidor el WAL no se archiva y no hay réplicas, pero en una empresa con esas piezas el borrado no llega igual a todos lados: las réplicas reciben el DELETE, mientras que los respaldos y el WAL archivado guardan los datos como estaban cuando se generaron.

### Cómo debería cumplirse la cancelación

1. **Confirmar la autorización.** El DBA pide por escrito la autorización del área responsable antes de tocar la base. La ley pide que una persona o un departamento de datos personales tramite las solicitudes (art. 29), así que la orden debe venir de ahí.
2. **Separar lo que no se puede borrar todavía.** La empresa no está obligada a cancelar los datos que debe tratar por disposición legal (art. 25, fracción II). Si Ana tiene facturas emitidas, su nombre, su RFC y su código postal fiscal se conservan cinco años como documentación fiscal (CFF, art. 30).
3. **Bloquear antes de suprimir.** La cancelación abre un periodo de bloqueo: los datos se conservan solo para atender posibles responsabilidades, no se usan para nada más y, al terminar, se suprimen (arts. 2, fracción III, y 24). En la base, eso significa sacar a Ana de todo lo que usan Soporte y Analítica. Hoy la tabla no tiene un campo para marcar a un cliente como bloqueado: es el mismo hueco de la evidencia 01, que se retoma en la Actividad 12.
4. **Suprimir en todas las copias y en orden.** Primero `clientes_soporte` y `analitica.clientes`, luego `pii.mapa_cliente` y al final `clientes`, cuando ya nada apunte a su renglón. El renglón de `analitica.clientes` va antes que el mapa porque solo se encuentra con el token que el mapa guarda. En `clientes_protegidos` hay que confirmar antes que el renglón es de Ana, porque no tiene llave y su RFC no coincide con el de `clientes`. Después, un VACUUM en esas tablas para que PostgreSQL quite las versiones viejas.
5. **Limpiar lo que está fuera de la base.** Los registros de sesión, el historial de psql, las exportaciones y las capturas. Si los datos se pasaron a terceros, la empresa debe avisarles para que también los cancelen (art. 24).
6. **Avisar y dejar registro.** Se avisa a Ana cuando la cancelación termine (art. 24) y se registra qué se hizo: fecha, tablas, cuántos renglones y quién lo hizo, sin copiar los datos borrados.

### ¿Por qué eliminar un registro de una tabla no necesariamente significa que toda la información relacionada con esa persona haya desaparecido de la organización?

Porque un DELETE actúa sobre una tabla de una base, y los datos de una persona se copian muchas veces durante su ciclo de vida: a otras tablas, a copias para analítica, a registros, exportaciones, reportes, respaldos y sistemas de terceros. Ninguna de esas copias se entera del borrado. En este entorno, con cinco clientes y tres laboratorios, los datos de Ana ya están en cuatro tablas además de `clientes`, en tres archivos del contenedor, en el repositorio y su historial, en GitHub y en OneDrive. Y aun dentro de `clientes`, la versión vieja de su renglón sigue en el archivo hasta que pase VACUUM.

Las vistas son la excepción: `v_clientes_soporte` y `v_analitica_clientes` no guardan datos, así que dejan de mostrar a Ana en cuanto su renglón sale de `clientes`. Por eso, en la Actividad 7, la vista mostró el correo nuevo y la copia física se quedó con el anterior.

## Análisis

1. **Borrar es un proceso, no una sentencia.** La cancelación se cumple recorriendo todo el mapa, no con un DELETE en `clientes`. La ley pide resguardar los datos de forma que los derechos ARCO se ejerzan sin dilación (art. 21), y eso solo es posible si la empresa sabe dónde están sus copias.
2. **Las copias sin llave son el mayor problema.** `clientes_soporte` y `clientes_protegidos` no reciben los cambios ni los borrados de `clientes`, y `clientes_protegidos` solo se encuentra por nombre y con otro RFC. Una copia desactualizada deja a la empresa con datos inexactos, y mantenerlos es una infracción (art. 58, fracción VI).
3. **Borrar el mapa no anonimiza.** Si solo se borra el renglón de `pii.mapa_cliente`, en `analitica.clientes` quedan su edad, ciudad, código postal y fecha de alta exactos. En esta base cada código postal es distinto (evidencia 01), así que con otra fuente, como una factura que sí se conserva, se podría volver a saber de quién es.
4. **Los registros y las herramientas crean copias que nadie planeó.** El RFC que el LAB-02 cifró en `clientes_protegidos` está en claro en `/tmp/lab02.log` y en el historial de psql: cifrar la columna no protegió esas copias. Lo mismo pasa con las capturas, los PDF y la sincronización de OneDrive; en una empresa real se suman archivos de Excel, correos con adjuntos y herramientas de reportes.
5. **Los respaldos y Git están hechos para no olvidar.** Un respaldo no se edita: se borra cuando vence su propio plazo y, si se restaura antes, hay que volver a aplicar las cancelaciones. En Git, borrar un archivo hoy no lo quita de los commits anteriores ni de GitHub; habría que reescribir el historial.
6. **Documentar también copia.** Esta evidencia y los PDF de las Actividades 6 y 7 son copias nuevas de datos de Ana. Por eso esta evidencia solo repite lo indispensable: no copia sus RFC, basta con decir que no coinciden.

## Conclusión

Antes de borrar a una persona hay que saber dónde están sus datos. En este entorno, los de Ana López ya están en cuatro tablas además de `clientes`, en tres archivos del contenedor, en el repositorio con su historial, en GitHub y en OneDrive, y hoy el DELETE en `clientes` ni siquiera pasaría por la llave foránea del mapa. Cumplir una cancelación significa bloquear primero, respetar lo que la ley obliga a conservar, suprimir en todas las copias en el orden correcto y dejar registro de lo que se hizo. El mejor control es no crear copias que no hacen falta y, cuando un área necesita datos, dárselos con vistas.

## Referencias

- Guía del LAB-03, secciones 12 a 14; [evidencia 01](01-inventario-datos.md) y los PDF de las Actividades [6](06-derecho-acceso.pdf) y [7](07-derecho-rectificacion.pdf).
- Scripts del LAB-01 ([`sql/01-clasificacion.sql`](../../laboratorio-01-proteccion-datos/sql/01-clasificacion.sql) y [`sql/03-seudonimizacion.sql`](../../laboratorio-01-proteccion-datos/sql/03-seudonimizacion.sql)) y del LAB-02 ([`sql/02-cifrado-datos.sql`](../../laboratorio-02-cifrado-credenciales/sql/02-cifrado-datos.sql)).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 (fracción III), 21, 24, 25, 29 y 58. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Código Fiscal de la Federación, artículo 30. Texto vigente, última reforma publicada en el DOF el 9 de abril de 2026. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/CFF.pdf
- Manual de PostgreSQL 16, sección 25.1.2, «Recovering Disk Space»: https://www.postgresql.org/docs/16/routine-vacuuming.html
- Manual de PostgreSQL 16, sección 30.3, «Write-Ahead Logging (WAL)»: https://www.postgresql.org/docs/16/wal-intro.html

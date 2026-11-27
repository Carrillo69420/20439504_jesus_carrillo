-- =====================================================
-- LAB-03 — Políticas, gobierno de datos y evidencias
-- 03 · Inventario técnico de tablas
-- Sección 10 de la guía (Actividad 4)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador. Da los datos técnicos del catálogo;
-- los de gobierno (propietario, clasificación, finalidad, conservación) no
-- están en el motor y se completan en evidencias/04-catalogo.md.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Actualiza las estadísticas; sin él, filas_estimadas puede salir en -1 en
-- tablas recién creadas
ANALYZE;

-- Tablas fuera de los esquemas del sistema. propietario_tecnico es la cuenta
-- dueña del objeto en el motor, no el propietario del dato
SELECT n.nspname                                   AS esquema,
       c.relname                                   AS tabla,
       pg_get_userbyid(c.relowner)                 AS propietario_tecnico,
       c.reltuples::bigint                         AS filas_estimadas,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS tamano,
       obj_description(c.oid, 'pg_class')          AS descripcion
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY 1, 2;

-- Agregada, no viene en la guía: las vistas, que la consulta anterior deja
-- fuera. Así aparece dba.bitacora, que también es un activo del catálogo
SELECT n.nspname                          AS esquema,
       c.relname                          AS vista,
       pg_get_userbyid(c.relowner)        AS propietario_tecnico,
       obj_description(c.oid, 'pg_class') AS descripcion
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'v'
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY 1, 2;

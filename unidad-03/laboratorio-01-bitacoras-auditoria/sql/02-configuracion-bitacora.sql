-- =====================================================
-- LAB-01 — Bitácoras y auditoría del dato en PostgreSQL
-- 02 · Configuración de la bitácora
-- Sección 10 de la guía (Actividad 4)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador. Los cambios se aplican con una
-- recarga, sin reiniciar, y se verifican en la misma sesión y en una nueva.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
-- El espacio del final separa el prefijo del mensaje
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
ALTER SYSTEM SET log_statement = 'ddl';
SELECT pg_reload_conf();

-- La recarga es asíncrona, así que esta consulta va aparte. En esta sesión,
-- log_connections sigue en off: se fija al abrir la sesión, y la recarga
-- solo lo cambia para las sesiones nuevas.
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections', 'log_line_prefix', 'log_statement');

-- Sesión nueva, fuera de psql:
--   \q
--   docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off

SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections', 'log_line_prefix', 'log_statement');

-- La guía usa LIMIT 6; con 7 entra también la línea de la recarga (SIGHUP)
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 7;

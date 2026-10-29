-- =====================================================
-- LAB-01 — Bitácoras y auditoría del dato en PostgreSQL
-- 01 · Colector y vista de la bitácora
-- Sección 8 de la guía (Actividad 2)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador, en dos partes: logging_collector
-- solo cambia al reiniciar el servidor, y el reinicio se hace desde PowerShell.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Parte 1 · Activar el colector

ALTER SYSTEM SET logging_collector = on;

-- La guía no recarga aquí. Sin la recarga, pending_restart sale f porque el
-- servidor todavía no ha leído postgresql.auto.conf; con ella sale t.
SELECT pg_reload_conf();

SELECT name, setting, pending_restart FROM pg_settings WHERE name = 'logging_collector';

-- Reinicio (Anexo A, tabla A.1), fuera de psql:
--   \q
--   docker restart dba-u3-pg
--   docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off

-- Parte 2 · Comprobar el colector y leer la bitácora

SELECT name, setting, source FROM pg_settings WHERE name = 'logging_collector';

-- Ruta relativa al directorio de datos (/var/lib/postgresql/data)
SELECT pg_current_logfile();

-- El archivo vigente, leído por el propio servidor, una fila por línea
SELECT linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n') AS linea;

-- Vista de uso exclusivo del administrador
CREATE SCHEMA dba;
REVOKE ALL ON SCHEMA dba FROM PUBLIC;

CREATE VIEW dba.bitacora AS
SELECT t.n AS num, t.linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n')
     WITH ORDINALITY AS t(linea, n)
WHERE t.linea <> '';

-- Últimas 10 líneas
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 10;

-- Líneas que contienen un texto, sin distinguir mayúsculas
SELECT linea FROM dba.bitacora WHERE linea ILIKE '%update%';

-- Líneas que cumplen una expresión regular
SELECT linea FROM dba.bitacora WHERE linea ~ '(FATAL|ERROR)';

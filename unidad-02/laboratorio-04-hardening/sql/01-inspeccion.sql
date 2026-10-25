-- =====================================================
-- LAB-04 — Hardening y configuración segura de PostgreSQL
-- 01 · Inspección del estado inicial
-- Secciones 7, 8, 10, 13, 14, 16, 17 y 21 de la guía
-- (Actividades 1, 2, 4, 7, 8, 10, 11 y 15)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

\echo '== LAB-04 · Evidencia 01 · Superficie de ataque · sql/01-inspeccion.sql · Jesús Arturo Carrillo Avilez (20439504) =='

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 7 Superficie de ataque (Actividad 1)
SELECT version();

-- Los cuatro SHOW de la guía en una sola consulta; source dice de dónde sale cada valor
SELECT name, setting, source
FROM pg_settings
WHERE name IN ('port', 'listen_addresses', 'ssl', 'password_encryption')
ORDER BY name;

-- Conexiones abiertas. A la consulta de la guía se le agrega backend_type:
-- los renglones sin usuario son procesos internos del servidor, no clientes.
SELECT
    pid,
    usename,
    datname,
    client_addr,
    client_port,
    application_name,
    backend_type
FROM pg_stat_activity;

\prompt 'Toma la captura 01 y presiona Enter... ' pausa
\! clear

\echo '== LAB-04 · Evidencia 03 · Reglas de pg_hba.conf · sql/01-inspeccion.sql · Jesús Arturo Carrillo Avilez (20439504) =='

-- 10 Reglas de pg_hba.conf (Actividad 4); line_number es el renglón del archivo
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method
FROM pg_hba_file_rules;

\prompt 'Toma la captura 03 y presiona Enter... ' pausa
\! clear

-- 8 Archivos de configuración, datos y logs (Actividad 2)
SELECT name, setting
FROM pg_settings
WHERE name IN ('config_file', 'hba_file', 'ident_file', 'data_directory',
               'log_directory', 'logging_collector', 'log_connections', 'log_disconnections')
ORDER BY name;

-- 14 Roles (Actividad 8). Se excluyen los roles predefinidos pg_*, que no inician sesión.
SELECT
    rolname,
    rolsuper,
    rolinherit,
    rolcreaterole,
    rolcreatedb,
    rolcanlogin
FROM pg_roles
WHERE rolname !~ '^pg_'
ORDER BY rolname;

-- 16 Extensiones (Actividad 10)
SELECT extname, extversion
FROM pg_extension
ORDER BY extname;

-- 17 Parámetros de conexión (Actividad 11); 0 en los tiempos significa desactivado
SELECT name, setting, unit
FROM pg_settings
WHERE name IN ('max_connections', 'superuser_reserved_connections',
               'statement_timeout', 'idle_in_transaction_session_timeout')
ORDER BY name;

-- 21 TLS (Actividad 15)
SELECT name, setting
FROM pg_settings
WHERE name IN ('ssl', 'ssl_min_protocol_version')
ORDER BY name;

-- pg_stat_ssl no tiene usename ni client_addr, así que se une con pg_stat_activity
SELECT
    s.pid,
    a.usename,
    a.client_addr,
    s.ssl,
    s.version,
    s.cipher
FROM pg_stat_ssl s
JOIN pg_stat_activity a ON a.pid = s.pid
WHERE s.pid = pg_backend_pid();

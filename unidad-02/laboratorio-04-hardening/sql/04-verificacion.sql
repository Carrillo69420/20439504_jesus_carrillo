-- =====================================================
-- LAB-04 — Hardening y configuración segura de PostgreSQL
-- 04 · Verificación después del hardening
-- Secciones 21, 22 y 26 de la guía (Actividades 15 y 16, verificación final)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Después del cambio, la única forma de entrar como administrador es como el
-- usuario postgres del sistema operativo:
-- docker exec -it -u postgres dba-practica psql -d comercializadora -f /tmp/lab04/sql/04-verificacion.sql

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

\echo '== LAB-04 · Evidencia 06 · Verificación · sql/04-verificacion.sql · Jesús Arturo Carrillo Avilez (20439504) =='

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 22 Configuración después de los cambios
SELECT name, setting, source
FROM pg_settings
WHERE name IN ('listen_addresses', 'ssl', 'log_connections',
               'log_disconnections', 'idle_in_transaction_session_timeout')
ORDER BY name;

-- Reglas vigentes de pg_hba.conf
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method
FROM pg_hba_file_rules;

\prompt 'Toma la captura 06 y presiona Enter... ' pausa
\! clear

\echo '== LAB-04 · Evidencia 05 · TLS · sql/04-verificacion.sql · Jesús Arturo Carrillo Avilez (20439504) =='

-- Desde aquí psql muestra cada línea antes de ejecutarla
\set ECHO all

-- 21 La aplicación entra por TCP con TLS y comprueba el certificado del servidor
\connect "host=localhost dbname=comercializadora user=app_comercializadora sslmode=verify-full sslrootcert=/etc/ssl/certs/ssl-cert-snakeoil.pem"

SELECT
    a.usename,
    a.client_addr,
    s.ssl,
    s.version,
    s.cipher
FROM pg_stat_ssl s
JOIN pg_stat_activity a ON a.pid = s.pid
WHERE s.pid = pg_backend_pid();

-- Los intentos que deben rechazarse van en un psql aparte (\!): en un script,
-- un \connect fallido cerraría esta sesión y terminaría el script.

-- La misma cuenta sin TLS: pg_hba.conf no tiene una regla para ese caso
\! psql "host=localhost dbname=comercializadora user=app_comercializadora sslmode=disable"

-- El superusuario por TCP, aunque use TLS: tampoco tiene regla
\! psql "host=localhost dbname=comercializadora user=postgres sslmode=require"

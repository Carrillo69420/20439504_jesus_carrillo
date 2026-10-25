-- =====================================================
-- LAB-04 — Hardening y configuración segura de PostgreSQL
-- 03 · Cambios de configuración
-- Secciones 9, 12, 17 y 21 de la guía (Actividades 3, 6, 11 y 15)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Antes de correrlo se respalda pg_hba.conf y se pone en su lugar
-- configuracion/pg_hba.conf (los pasos están en configuracion/cambios.md).

\set ON_ERROR_STOP on
\pset pager off

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 12 El pg_hba.conf nuevo, tal como lo leerá el servidor
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method,
    error
FROM pg_hba_file_rules;

-- Si alguna regla tiene error, el script se detiene aquí y no cambia nada:
-- con un pg_hba.conf inválido el servidor no volvería a arrancar.
-- El aviso de las reglas hostssl es esperado mientras ssl siga apagado;
-- ssl se prende más abajo, en este mismo script.
DO $$
BEGIN
    IF EXISTS (SELECT 1
               FROM pg_hba_file_rules
               WHERE error IS NOT NULL
                 AND error <> 'hostssl record cannot match because SSL is disabled') THEN
        RAISE EXCEPTION 'pg_hba.conf tiene errores; no se aplicó ningún cambio';
    END IF;
END
$$;

-- 9 Escuchar solo en la interfaz local (este cambio necesita reinicio)
ALTER SYSTEM SET listen_addresses = 'localhost';

-- 21 TLS con el certificado de prueba que trae la imagen postgres:16
ALTER SYSTEM SET ssl = 'on';
ALTER SYSTEM SET ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem';
ALTER SYSTEM SET ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key';

-- 8 y 17 Registro de conexiones y límite a las transacciones abiertas sin actividad
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';

-- Aplica pg_hba.conf y los parámetros que no necesitan reinicio
SELECT pg_reload_conf();

-- La recarga no es instantánea: se le da un segundo al servidor antes de revisar
\! sleep 1

-- Con ssl ya encendido, ninguna regla debe tener error
SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    auth_method,
    error
FROM pg_hba_file_rules;

-- Lo que quedó en postgresql.auto.conf y si ya se aplicó. listen_addresses
-- queda pendiente hasta reiniciar, y log_connections cuenta desde la siguiente sesión.
SELECT name, setting, applied, error
FROM pg_file_settings
WHERE sourcefile LIKE '%postgresql.auto.conf'
ORDER BY seqno;

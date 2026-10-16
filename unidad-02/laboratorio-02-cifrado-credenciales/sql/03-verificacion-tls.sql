-- =====================================================
-- LAB-02 — Cifrado, credenciales y comunicaciones seguras
-- 03 · Verificación de TLS
-- Secciones 11 y 12 de la guía (Actividades 5 y 6)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 11 Configuración de TLS del servidor
SHOW ssl;

SHOW ssl_min_protocol_version;

SHOW port;

SHOW listen_addresses;

-- 11.1 Dirección y puerto desde los que se conecta el cliente
SELECT
    inet_client_addr(),
    inet_client_port();

-- ¿La sesión actual usa TLS? (la Actividad 6 repite esta consulta desde psql)
SELECT
    ssl,
    version,
    cipher
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();

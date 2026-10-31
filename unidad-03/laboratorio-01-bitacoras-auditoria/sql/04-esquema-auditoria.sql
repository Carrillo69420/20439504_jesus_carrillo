-- =====================================================
-- LAB-01 — Bitácoras y auditoría del dato en PostgreSQL
-- 04 · Esquema y tabla de auditoría de clientes
-- Sección 16 de la guía (Actividad 10)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador. Con log_statement = 'mod'
-- (Actividad 7), los CREATE y el REVOKE quedan en la bitácora.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Esquema separado. Un esquema nuevo no le da ningún privilegio a
-- PUBLIC; el REVOKE deja la regla escrita
CREATE SCHEMA auditoria;
REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;

-- Un registro por cada cambio en clientes. Los valores por defecto
-- se calculan al insertar cada registro
CREATE TABLE auditoria.cambios_clientes (
    id_evento        BIGSERIAL PRIMARY KEY,
    momento          TIMESTAMPTZ NOT NULL DEFAULT now(),
    usuario_sesion   TEXT        NOT NULL DEFAULT session_user,
    usuario_efectivo TEXT        NOT NULL DEFAULT current_user,
    aplicacion       TEXT        DEFAULT current_setting('application_name'),
    ip_cliente       INET        DEFAULT inet_client_addr(),
    operacion        TEXT        NOT NULL,
    id_cliente       BIGINT,
    valores_antes    JSONB,
    valores_despues  JSONB
);

-- Verificación: privilegios del esquema y estructura de la tabla
\dn+ auditoria
\d auditoria.cambios_clientes

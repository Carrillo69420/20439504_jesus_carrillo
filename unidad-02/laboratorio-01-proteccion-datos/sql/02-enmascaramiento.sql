-- =====================================================
-- LAB-01 — Protección y privacidad de datos
-- 02 · Enmascaramiento (masking)
-- Sección 8 de la guía (Actividad 2)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 8.1 Rol del área de soporte
CREATE ROLE soporte NOLOGIN;

-- 8.2 Vista con correo, teléfono y RFC parcialmente ocultos
CREATE VIEW v_clientes_soporte AS
SELECT
    id,
    nombre,

    CONCAT(
        LEFT(correo, 2),
        '*****',
        SUBSTRING(correo FROM POSITION('@' IN correo))
    ) AS correo,

    CONCAT(
        '******',
        RIGHT(telefono, 4)
    ) AS telefono,

    CONCAT(
        '*********',
        RIGHT(rfc, 4)
    ) AS rfc

FROM clientes;

SELECT *
FROM v_clientes_soporte;

-- 8.3 Permisos: soporte lee la vista, nunca la tabla
GRANT USAGE
ON SCHEMA public
TO soporte;

GRANT SELECT
ON v_clientes_soporte
TO soporte;

REVOKE ALL
ON clientes
FROM soporte;

-- Permisos aplicados al rol
SELECT
    grantee AS rol,
    table_schema AS esquema,
    table_name AS objeto,
    privilege_type AS privilegio
FROM information_schema.role_table_grants
WHERE grantee = 'soporte';

-- 8.4 Verificación actuando como soporte
SET ROLE soporte;

SELECT session_user AS sesion, current_user AS rol_activo;

-- Permitido: datos enmascarados
SELECT *
FROM v_clientes_soporte;

-- Rechazado: acceso directo a la tabla original
SELECT *
FROM clientes;

RESET ROLE;

-- De vuelta como postgres: la tabla original sigue completa
SELECT current_user AS rol_activo;

SELECT nombre, correo, telefono, rfc
FROM clientes;

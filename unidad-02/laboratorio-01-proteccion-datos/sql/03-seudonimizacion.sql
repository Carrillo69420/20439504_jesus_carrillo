-- =====================================================
-- LAB-01 — Protección y privacidad de datos
-- 03 · Seudonimización y separación de funciones
-- Secciones 9, 10 y 11 de la guía (Actividades 3 y 4)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 9.1 Esquemas: pii guarda el mapa, analitica el conjunto seudonimizado
CREATE SCHEMA pii;

CREATE SCHEMA analitica;

-- 9.2 Tabla de correspondencia token -> cliente
CREATE TABLE pii.mapa_cliente (
    token UUID PRIMARY KEY,
    cliente_id BIGINT UNIQUE
        REFERENCES public.clientes(id)
);

-- 9.3 Un token aleatorio por cliente
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO pii.mapa_cliente
(token, cliente_id)
SELECT
    gen_random_uuid(),
    id
FROM clientes;

SELECT *
FROM pii.mapa_cliente;

-- 10. Conjunto de datos para analítica, sin nombre, correo, teléfono ni RFC
CREATE TABLE analitica.clientes AS
SELECT
    m.token AS cliente_token,
    c.edad,
    c.ciudad,
    c.codigo_postal,
    c.fecha_alta
FROM pii.mapa_cliente m
JOIN clientes c
    ON c.id = m.cliente_id;

SELECT *
FROM analitica.clientes;

-- 11. Separación de funciones: analista solo ve el conjunto seudonimizado
CREATE ROLE analista NOLOGIN;

GRANT USAGE
ON SCHEMA analitica
TO analista;

GRANT SELECT
ON analitica.clientes
TO analista;

-- Permisos aplicados al rol
SELECT
    grantee AS rol,
    table_schema AS esquema,
    table_name AS objeto,
    privilege_type AS privilegio
FROM information_schema.role_table_grants
WHERE grantee = 'analista';

-- 11.1 Verificación actuando como analista
SET ROLE analista;

SELECT session_user AS sesion, current_user AS rol_activo;

-- Permitido: conjunto seudonimizado
SELECT *
FROM analitica.clientes;

-- Rechazado: mapa de correspondencia
SELECT *
FROM pii.mapa_cliente;

-- Rechazado: datos originales
SELECT *
FROM public.clientes;

RESET ROLE;

-- De vuelta como postgres: solo con el mapa se vuelve a la identidad
SELECT current_user AS rol_activo;

SELECT
    m.token,
    m.cliente_id,
    c.nombre
FROM pii.mapa_cliente m
JOIN clientes c
    ON c.id = m.cliente_id;

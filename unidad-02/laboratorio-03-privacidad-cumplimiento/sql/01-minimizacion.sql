-- =====================================================
-- LAB-03 — Privacidad, cumplimiento y gobierno de los datos
-- 01 · Minimización: tabla mínima para atención al cliente
-- Sección 8 de la guía (Actividad 2)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 8. La solicitud original copiaba los nueve campos de clientes. No se crea:
-- soporte no necesita RFC, edad, ciudad, código postal ni fecha de alta.

-- 8.1 Estructura mínima: solo los datos que usa soporte
CREATE TABLE clientes_soporte (
    id BIGINT PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    correo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20)
);

\d clientes_soporte

-- Carga a partir de clientes
INSERT INTO clientes_soporte (id, nombre, correo, telefono)
SELECT id, nombre, correo, telefono
FROM clientes;

-- Consulta
SELECT *
FROM clientes_soporte;

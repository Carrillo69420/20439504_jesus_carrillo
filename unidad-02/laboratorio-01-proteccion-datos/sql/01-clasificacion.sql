-- =====================================================
-- LAB-01 — Protección y privacidad de datos
-- 01 · Preparación de la base y clasificación de datos
-- Secciones 6 y 7 de la guía (Actividad 1)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 6.1 Tabla de clientes
CREATE TABLE clientes (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    correo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    rfc VARCHAR(13),
    edad INTEGER,
    ciudad VARCHAR(80),
    codigo_postal VARCHAR(10),
    fecha_alta DATE DEFAULT CURRENT_DATE
);

\d clientes

-- 6.2 Datos de prueba (ficticios)
INSERT INTO clientes
(nombre, correo, telefono, rfc, edad, ciudad, codigo_postal)
VALUES
('Ana López',     'ana.lopez@example.test',     '6671234567', 'LOAA850315ABC', 41, 'Culiacán',   '80000'),
('Carlos Pérez',  'carlos.perez@example.test',  '6672345678', 'PECA900720DEF', 35, 'Culiacán',   '80100'),
('María García',  'maria.garcia@example.test',  '6673456789', 'GAMA780912GHI', 47, 'Mazatlán',   '82000'),
('Luis Torres',   'luis.torres@example.test',   '6674567890', 'TOLU920201JKL', 34, 'Los Mochis', '81200'),
('Laura Sánchez', 'laura.sanchez@example.test', '6675678901', 'SALA880525MNO', 38, 'Culiacán',   '80200');

SELECT *
FROM clientes;

-- 7. Apoyo para la matriz de clasificación
-- Un campo con tantos valores distintos como registros distingue por sí solo
-- a cada cliente dentro de esta tabla.
SELECT
    COUNT(*) AS registros,
    COUNT(DISTINCT nombre) AS nombre,
    COUNT(DISTINCT correo) AS correo,
    COUNT(DISTINCT telefono) AS telefono,
    COUNT(DISTINCT rfc) AS rfc,
    COUNT(DISTINCT edad) AS edad,
    COUNT(DISTINCT ciudad) AS ciudad,
    COUNT(DISTINCT codigo_postal) AS codigo_postal,
    COUNT(DISTINCT fecha_alta) AS fecha_alta
FROM clientes;

-- Sin nombre, correo, teléfono ni RFC: ¿cuántos clientes comparten la misma
-- combinación de edad, ciudad y código postal?
SELECT
    edad,
    ciudad,
    codigo_postal,
    COUNT(*) AS clientes
FROM clientes
GROUP BY edad, ciudad, codigo_postal
ORDER BY edad;

-- =====================================================
-- LAB-03 — Políticas, gobierno de datos y evidencias
-- 01 · Verificaciones de calidad de datos
-- Sección 7 de la guía (Actividad 1)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador. Con log_statement = 'mod', el
-- INSERT queda en la bitácora; las consultas no dejan rastro en ella.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Dos registros capturados con errores, a propósito. No se corrigen ni se
-- eliminan: forman parte de los hallazgos del expediente.
INSERT INTO clientes (nombre, correo, telefono, rfc, edad, ciudad, codigo_postal) VALUES
('Ana Lopez', 'ANA.LOPEZ@example.test', '6671234567', 'LOAA850315AB', 41, 'Culiacan', '80000'),
('Jorge Díaz', 'sin-correo', '667', NULL, -3, 'Culiacán', '8000');

-- Posibles duplicados por correo
SELECT lower(correo) AS correo_normalizado,
       count(*) AS registros,
       string_agg(id::text, ', ') AS ids
FROM clientes
GROUP BY lower(correo)
HAVING count(*) > 1;

-- RFC con formato no válido o ausente. Solo revisa el formato: no comprueba
-- que el RFC exista ni sustituye las reglas oficiales del SAT.
SELECT id, nombre, rfc
FROM clientes
WHERE rfc IS NULL
   OR rfc !~ '^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$';

-- Correo con formato no válido
SELECT id, nombre, correo
FROM clientes
WHERE correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$';

-- Edad fuera de rango
SELECT id, nombre, edad
FROM clientes
WHERE edad IS NOT NULL AND (edad < 18 OR edad > 120);

-- Completitud
SELECT count(*) AS total,
       count(*) FILTER (WHERE telefono IS NULL) AS sin_telefono,
       count(*) FILTER (WHERE rfc IS NULL) AS sin_rfc
FROM clientes;

-- Agregadas, no vienen en la guía: el INSERT trae también un teléfono y un
-- código postal incompletos y una ciudad escrita de dos formas, y ninguna de
-- las consultas anteriores los detecta.
SELECT id, nombre, telefono, codigo_postal
FROM clientes
WHERE telefono !~ '^[0-9]{10}$' OR codigo_postal !~ '^[0-9]{5}$';

SELECT ciudad, count(*) AS registros
FROM clientes
GROUP BY ciudad
ORDER BY ciudad;

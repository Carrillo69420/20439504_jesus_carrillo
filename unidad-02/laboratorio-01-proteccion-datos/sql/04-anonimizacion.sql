-- =====================================================
-- LAB-01 — Protección y privacidad de datos
-- 04 · Anonimización y riesgo de reidentificación
-- Secciones 12 y 13 de la guía (Actividades 5 y 6)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 12.1 Generalizar la edad
SELECT
    CASE
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+'
    END AS rango_edad,
    COUNT(*) AS total
FROM clientes
GROUP BY 1;

-- 12.2 Generalizar la región
SELECT
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes
GROUP BY 1;

-- 12.3 Combinar atributos
SELECT
    CASE
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+'
    END AS rango_edad,
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes
GROUP BY 1, 2;

-- 12.4 Suprimir grupos pequeños (umbral didáctico k = 5)
SELECT
    CASE
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+'
    END AS rango_edad,
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes
GROUP BY 1, 2
HAVING COUNT(*) >= 5;

-- 13. Reto: reducir aún más el riesgo de reidentificación
-- Cambios respecto a 12.4: rangos de edad más amplios, zona postal de un solo
-- dígito y una categoría propia para edades vacías o menores de 18.
SELECT
    CASE
        WHEN edad BETWEEN 18 AND 29 THEN '18-29'
        WHEN edad BETWEEN 30 AND 49 THEN '30-49'
        WHEN edad >= 50 THEN '50+'
        ELSE 'sin dato'
    END AS rango_edad,
    LEFT(codigo_postal, 1) || 'xxxx' AS zona_postal,
    COUNT(*) AS total
FROM clientes
GROUP BY 1, 2
HAVING COUNT(*) >= 5
ORDER BY 1, 2;

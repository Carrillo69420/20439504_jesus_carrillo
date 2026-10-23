-- =====================================================
-- LAB-03 — Privacidad, cumplimiento y gobierno de los datos
-- 02 · Separación por finalidad: información agregada para analítica
-- Sección 9 de la guía (Actividad 3)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 9. Clientes por ciudad
SELECT
    ciudad,
    COUNT(*) AS cantidad_clientes
FROM clientes
GROUP BY ciudad
ORDER BY cantidad_clientes DESC;

-- Clientes por rango de edad
SELECT
    CASE
        WHEN edad < 18 THEN 'Menor de 18'
        WHEN edad BETWEEN 18 AND 29 THEN '18-29'
        WHEN edad BETWEEN 30 AND 44 THEN '30-44'
        WHEN edad BETWEEN 45 AND 59 THEN '45-59'
        ELSE '60 o más'
    END AS rango_edad,
    COUNT(*) AS cantidad
FROM clientes
GROUP BY
    CASE
        WHEN edad < 18 THEN 'Menor de 18'
        WHEN edad BETWEEN 18 AND 29 THEN '18-29'
        WHEN edad BETWEEN 30 AND 44 THEN '30-44'
        WHEN edad BETWEEN 45 AND 59 THEN '45-59'
        ELSE '60 o más'
    END
ORDER BY rango_edad;

-- Clientes por región del código postal. La guía la pide pero no da la consulta:
-- los dos primeros dígitos identifican la entidad federativa o una parte de ella
-- (en Sinaloa van del 80 al 82).
SELECT
    LEFT(codigo_postal, 2) AS region_cp,
    COUNT(*) AS cantidad_clientes
FROM clientes
GROUP BY region_cp
ORDER BY region_cp;

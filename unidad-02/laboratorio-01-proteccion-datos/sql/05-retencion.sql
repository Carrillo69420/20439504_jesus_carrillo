-- =====================================================
-- LAB-01 — Protección y privacidad de datos
-- 05 · Retención de datos y verificación final
-- Secciones 14 y 15 de la guía (Actividad 7 y verificación final)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 14. Registros que superan el periodo de conservación de cinco años
SELECT *
FROM clientes
WHERE fecha_alta <
      CURRENT_DATE - INTERVAL '5 years';

-- Fecha límite de hoy y fecha hasta la que se conserva cada registro.
-- Solo se consulta: no se ejecuta ningún DELETE sobre la tabla principal.
SELECT CAST(CURRENT_DATE - INTERVAL '5 years' AS DATE) AS limite_hoy;

SELECT
    id,
    fecha_alta,
    CAST(fecha_alta + INTERVAL '5 years' AS DATE) AS conservar_hasta
FROM clientes
ORDER BY id;

-- 15. Verificación final (solo lectura, se puede repetir)

-- Área de soporte: lee la vista enmascarada, no la tabla original
SET ROLE soporte;

SELECT session_user AS sesion, current_user AS rol_activo;

SELECT *
FROM v_clientes_soporte;

SELECT *
FROM clientes;

RESET ROLE;

-- Área de analítica: lee el conjunto seudonimizado, no el mapa ni la tabla original
SET ROLE analista;

SELECT session_user AS sesion, current_user AS rol_activo;

SELECT *
FROM analitica.clientes;

SELECT *
FROM pii.mapa_cliente;

SELECT *
FROM public.clientes;

RESET ROLE;

-- Información para dirección: agregada y sin identificadores directos
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

-- Retención: registros que exceden el periodo de cinco años
SELECT *
FROM clientes
WHERE fecha_alta <
      CURRENT_DATE - INTERVAL '5 years';

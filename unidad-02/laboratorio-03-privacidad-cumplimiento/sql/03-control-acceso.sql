-- =====================================================
-- LAB-03 — Privacidad, cumplimiento y gobierno de los datos
-- 03 · Control de acceso relacionado con la finalidad
-- Sección 10 de la guía (Actividad 4)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 10. El rol analista ya existe desde el LAB-01 (sql/03-seudonimizacion.sql),
-- creado con CREATE ROLE analista NOLOGIN. Crearlo otra vez daría el error
-- "already exists", así que se comprueba que existe y que no puede iniciar sesión.
SELECT rolname, rolcanlogin, rolsuper
FROM pg_roles
WHERE rolname = 'analista';

-- Vista con la información preparada para analítica: ciudad y rango de edad
CREATE VIEW v_analitica_clientes AS
SELECT
    ciudad,
    CASE
        WHEN edad < 18 THEN 'Menor de 18'
        WHEN edad BETWEEN 18 AND 29 THEN '18-29'
        WHEN edad BETWEEN 30 AND 44 THEN '30-44'
        WHEN edad BETWEEN 45 AND 59 THEN '45-59'
        ELSE '60 o más'
    END AS rango_edad
FROM clientes;

-- Permisos: solo la vista; no se otorga SELECT sobre clientes
GRANT USAGE ON SCHEMA public TO analista;

GRANT SELECT
ON v_analitica_clientes
TO analista;

-- Verificación. A la consulta de la guía se le agrega table_schema: sin esa columna,
-- el permiso del LAB-01 sobre analitica.clientes parece un permiso sobre la tabla clientes.
SELECT
    grantee,
    table_schema,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee = 'analista'
ORDER BY table_schema, table_name;

-- Prueba con el rol: la vista responde y la tabla clientes se niega
SET ROLE analista;

SELECT *
FROM v_analitica_clientes;

SELECT nombre, correo, rfc
FROM clientes;

RESET ROLE;

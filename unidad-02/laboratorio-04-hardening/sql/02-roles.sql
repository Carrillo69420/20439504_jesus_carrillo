-- =====================================================
-- LAB-04 — Hardening y configuración segura de PostgreSQL
-- 02 · Roles, privilegios y cuenta de aplicación
-- Secciones 14 y 15 de la guía (Actividades 8 y 9)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 15 Cuenta de aplicación: inicia sesión, pero sin atributos administrativos.
-- El IF evita el error "already exists" si el script se corre otra vez.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_comercializadora') THEN
        CREATE ROLE app_comercializadora LOGIN;
    END IF;
END
$$;

ALTER ROLE app_comercializadora
    LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS
    CONNECTION LIMIT 10;

-- Ninguna consulta de la aplicación puede durar más de 30 segundos
ALTER ROLE app_comercializadora SET statement_timeout = '30s';

-- La contraseña se teclea dos veces y no aparece en pantalla.
-- psql manda al servidor solo el verificador SCRAM, nunca la contraseña.
\password app_comercializadora

-- Por omisión cualquier rol (PUBLIC) puede conectarse a la base;
-- desde aquí solo quien tenga el permiso explícito.
REVOKE CONNECT, TEMPORARY ON DATABASE comercializadora FROM PUBLIC;
GRANT CONNECT ON DATABASE comercializadora TO app_comercializadora;

-- Privilegios mínimos: consultar, registrar y actualizar clientes.
-- Sin DELETE, sin crear objetos y sin acceso a pii ni a las tablas de prácticas.
GRANT USAGE ON SCHEMA public TO app_comercializadora;
GRANT SELECT, INSERT, UPDATE ON clientes TO app_comercializadora;
GRANT USAGE ON SEQUENCE clientes_id_seq TO app_comercializadora;

\prompt 'Presiona Enter para ver el resultado... ' pausa
\! clear

\echo '== LAB-04 · Evidencia 04 · Roles y privilegios · sql/02-roles.sql · Jesús Arturo Carrillo Avilez (20439504) =='

-- 14 Tabla de roles (Actividad 8), ya con la cuenta de aplicación
SELECT
    rolname,
    rolcanlogin AS login,
    rolsuper AS superuser,
    rolcreaterole AS createrole,
    rolcreatedb AS createdb,
    rolconnlimit AS limite,
    rolconfig AS ajustes
FROM pg_roles
WHERE rolname !~ '^pg_'
ORDER BY rolname;

-- Privilegios de la cuenta de aplicación sobre tablas
SELECT
    table_name,
    string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE grantee = 'app_comercializadora'
GROUP BY table_name;

-- Desde aquí psql muestra cada sentencia antes de su resultado
\set ECHO all

-- Prueba con el rol, como en el LAB-01 y el LAB-03
SET ROLE app_comercializadora;

SELECT count(*) AS clientes_visibles
FROM clientes;

-- WHERE false no toca ningún renglón, pero PostgreSQL revisa el permiso de todos modos
DELETE FROM clientes WHERE false;

SELECT *
FROM pii.mapa_cliente;

CREATE TABLE prueba_app (id integer);

RESET ROLE;

-- =====================================================
-- LAB-02 — Cifrado, credenciales y comunicaciones seguras
-- 01 · Preparación y protección de credenciales
-- Secciones 6 y 7 de la guía (Actividad 1)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 6. Preparación: se usa la base del LAB-01
\d clientes

SELECT *
FROM clientes;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

SELECT extname
FROM pg_extension
WHERE extname = 'pgcrypto';

-- Las tablas de demostración se borran primero para poder ejecutar el script de nuevo
DROP TABLE IF EXISTS usuarios_insegura;
DROP TABLE IF EXISTS usuarios_segura;

-- 7.1 Implementación incorrecta: la contraseña se guarda en texto claro
CREATE TABLE usuarios_insegura (
    id BIGSERIAL PRIMARY KEY,
    usuario VARCHAR(50) NOT NULL,
    password VARCHAR(100) NOT NULL
);

INSERT INTO usuarios_insegura (usuario, password)
VALUES ('juan', 'Password123');

SELECT *
FROM usuarios_insegura;

-- 7.3 Representación no reversible
-- gen_salt('bf') genera una sal aleatoria para bcrypt
SELECT gen_salt('bf') AS sal;

-- La misma contraseña, dos veces
SELECT crypt(
    'Password123',
    gen_salt('bf')
);

SELECT crypt(
    'Password123',
    gen_salt('bf')
);

-- 7.4 Tabla para credenciales protegidas
CREATE TABLE usuarios_segura (
    id BIGSERIAL PRIMARY KEY,
    usuario VARCHAR(50) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL
);

INSERT INTO usuarios_segura (usuario, password_hash)
VALUES (
    'juan',
    crypt('Password123', gen_salt('bf'))
);

SELECT *
FROM usuarios_segura;

-- 7.5 Verificar una contraseña: correcta e incorrecta
SELECT
    usuario,
    password_hash = crypt('Password123', password_hash)
        AS contraseña_correcta
FROM usuarios_segura
WHERE usuario = 'juan';

SELECT
    usuario,
    password_hash = crypt('OtraPassword', password_hash)
        AS contraseña_correcta
FROM usuarios_segura
WHERE usuario = 'juan';

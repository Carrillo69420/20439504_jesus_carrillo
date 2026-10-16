-- =====================================================
-- LAB-02 — Cifrado, credenciales y comunicaciones seguras
-- 02 · Cifrado de información sensible
-- Sección 8 de la guía (Actividad 2)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- La tabla de demostración se borra primero para poder ejecutar el script de nuevo
DROP TABLE IF EXISTS clientes_protegidos;

-- 8.1 Tabla con el RFC cifrado (BYTEA guarda bytes, no texto)
CREATE TABLE clientes_protegidos (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    rfc_cifrado BYTEA NOT NULL
);

-- 'CLAVE-DE-PRUEBA' es una clave ficticia, solo para la práctica
INSERT INTO clientes_protegidos (
    nombre,
    rfc_cifrado
)
VALUES (
    'Ana López',
    pgp_sym_encrypt('LOPA900101ABC', 'CLAVE-DE-PRUEBA')
);

SELECT *
FROM clientes_protegidos;

-- 8.2 Recuperar el dato con la clave correcta
SELECT
    id,
    nombre,
    pgp_sym_decrypt(
        rfc_cifrado,
        'CLAVE-DE-PRUEBA'
    ) AS rfc
FROM clientes_protegidos;

-- Con una clave incorrecta el descifrado falla (error esperado)
SELECT
    id,
    nombre,
    pgp_sym_decrypt(
        rfc_cifrado,
        'CLAVE-INCORRECTA'
    ) AS rfc
FROM clientes_protegidos;

-- =====================================================
-- LAB-03 — Privacidad, cumplimiento y gobierno de los datos
-- 04 · Derechos ARCO: acceso y rectificación
-- Secciones 12 y 13 de la guía (Actividades 6 y 7)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================

SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- 12.1 Derecho de acceso. La consulta de la guía busca a Ana con 'ana@example.com',
-- pero su correo registrado es otro, así que devuelve 0 filas.
SELECT
    id,
    nombre,
    correo,
    telefono,
    rfc,
    edad,
    ciudad,
    codigo_postal,
    fecha_alta
FROM clientes
WHERE correo = 'ana@example.com';

-- Con el correo registrado sí aparece
SELECT
    id,
    nombre,
    correo,
    telefono,
    rfc,
    edad,
    ciudad,
    codigo_postal,
    fecha_alta
FROM clientes
WHERE correo = 'ana.lopez@example.test';

-- Sus datos también están fuera de clientes, y la respuesta debe incluirlos.
-- Copia de la Actividad 2
SELECT id, nombre, correo, telefono
FROM clientes_soporte
WHERE id = 1;

-- Tabla seudonimizada del LAB-01: el token se relaciona con Ana mediante pii.mapa_cliente
SELECT a.cliente_token, a.edad, a.ciudad, a.codigo_postal, a.fecha_alta
FROM analitica.clientes a
JOIN pii.mapa_cliente m ON m.token = a.cliente_token
WHERE m.cliente_id = 1;

-- Tabla del LAB-02 con el RFC cifrado. No tiene llave foránea hacia clientes,
-- así que solo se puede buscar por nombre.
SELECT id, nombre
FROM clientes_protegidos
WHERE nombre = 'Ana López';

-- 13. Derecho de rectificación
SELECT current_user AS usuario,
       current_database() AS base_de_datos,
       now() AS fecha_ejecucion;

-- Antes del cambio
SELECT
    id,
    nombre,
    correo
FROM clientes
WHERE id = 1;

UPDATE clientes
SET correo = 'nuevo-correo@example.com'
WHERE id = 1;

-- Verificación de la guía
SELECT
    id,
    nombre,
    correo
FROM clientes
WHERE id = 1;

-- La copia de la Actividad 2 conserva el correo anterior
SELECT id, nombre, correo
FROM clientes_soporte
WHERE id = 1;

-- La vista enmascarada del LAB-01 sí muestra el correo nuevo, porque se calcula desde clientes
SELECT id, nombre, correo
FROM v_clientes_soporte
WHERE id = 1;

-- El servidor no registra las sentencias: no queda constancia de quién hizo el UPDATE
SHOW log_statement;

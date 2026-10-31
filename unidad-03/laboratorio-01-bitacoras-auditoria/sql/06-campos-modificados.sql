-- =====================================================
-- LAB-01 — Bitácoras y auditoría del dato en PostgreSQL
-- 06 · Campos que cambió cada UPDATE auditado
-- Sección 18 de la guía (Actividad 12)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador. Solo lee la auditoría, así que
-- con log_statement = 'mod' no deja línea en la bitácora.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Cada registro guarda al cliente completo antes y después del cambio.
-- jsonb_each separa valores_despues en una fila por campo, y el WHERE deja
-- solo los campos cuyo valor no es el que había antes.
-- ->> y #>> '{}' sacan el valor como texto, sin las comillas de JSON
SELECT a.id_evento, a.momento, a.usuario_sesion, a.ip_cliente,
       d.key                     AS campo,
       a.valores_antes ->> d.key AS antes,
       d.value #>> '{}'          AS despues
FROM auditoria.cambios_clientes a
CROSS JOIN LATERAL jsonb_each(a.valores_despues) d
WHERE a.operacion = 'UPDATE'
  AND a.valores_antes -> d.key IS DISTINCT FROM d.value
ORDER BY a.id_evento;

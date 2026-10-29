-- =====================================================
-- LAB-01 — Bitácoras y auditoría del dato en PostgreSQL
-- 03 · Cambios de privilegios y de estructura
-- Sección 12 de la guía (Actividad 6)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador, con log_statement = 'ddl'
-- (Actividad 4), para que cada sentencia quede en la bitácora.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Privilegios. soporte_ana no tenía UPDATE y app_ventas ya lo tenía
-- (sección 6.5); ninguna de las dos sentencias da error
REVOKE UPDATE ON clientes FROM soporte_ana;
GRANT UPDATE ON clientes TO app_ventas;

-- Estructura
ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);

-- 12.1 · Un rol desechable con la contraseña escrita en la sentencia.
-- La guía usa aquí una contraseña de práctica; en este repositorio, que es
-- público, va <REDACTED>. Cualquier valor queda igual en la bitácora.
CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
DROP ROLE rol_temporal;

SELECT linea FROM dba.bitacora WHERE linea LIKE '%statement:%' ORDER BY num;

-- Todo lo que la bitácora registró sobre rol_temporal, en orden
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%rol_temporal%' ORDER BY num;

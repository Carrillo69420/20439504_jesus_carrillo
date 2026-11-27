-- =====================================================
-- LAB-03 — Políticas, gobierno de datos y evidencias
-- 05 · Evidencias técnicas del expediente (E1 a E5)
-- Sección 14 de la guía (Actividad 8)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador, después del script 04. Son las
-- consultas de la guía, pero cada resultado se guarda con \o en
-- /tmp/lab03-evid, dentro del contenedor, porque > en PowerShell 5.1 guarda
-- en UTF-16. Después la carpeta se copia al equipo con docker cp.

\pset pager off
\! mkdir -p /tmp/lab03-evid

-- E1 — Configuración de registro vigente
\o /tmp/lab03-evid/E1-configuracion-registro.txt
SELECT name, setting, source FROM pg_settings
WHERE name IN ('logging_collector', 'log_connections', 'log_disconnections',
               'log_statement', 'log_line_prefix', 'log_min_error_statement')
ORDER BY name;

-- E2 — Privilegios vigentes sobre tablas
\o /tmp/lab03-evid/E2-privilegios.txt
SELECT grantee, table_schema, table_name,
       string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privilegios
FROM information_schema.role_table_grants
WHERE table_schema NOT IN ('pg_catalog', 'information_schema') AND grantee <> 'postgres'
GROUP BY 1, 2, 3 ORDER BY 1;

-- E3 — Disparadores (tgenabled = O: activo)
\o /tmp/lab03-evid/E3-disparadores.txt
SELECT tgname, tgenabled, tgrelid::regclass FROM pg_trigger WHERE NOT tgisinternal;

-- E4 — Muestra de la auditoría: solo metadatos, sin valores_antes ni valores_despues
\o /tmp/lab03-evid/E4-muestra-auditoria.txt
SELECT id_evento, momento, usuario_sesion, aplicacion, operacion, id_cliente
FROM auditoria.cambios_clientes ORDER BY id_evento DESC LIMIT 10;

-- E5 — Bitácora completa: todos los archivos del directorio log, en orden,
-- con las contraseñas tapadas antes de salir del servidor
\o
\pset format unaligned
\pset tuples_only on
\o /tmp/lab03-evid/E5-bitacora-postgresql.log
SELECT regexp_replace(string_agg(pg_read_file('log/' || name), '' ORDER BY name),
                      'PASSWORD\s+''[^'']*''', 'PASSWORD ''<REDACTED>''', 'gi')
FROM pg_ls_logdir()
WHERE name ~ '^postgresql-.*\.log$';
\o
\pset format aligned
\pset tuples_only off

-- Hash de E5 y lista de lo exportado
\! cd /tmp/lab03-evid && sha256sum E5-bitacora-postgresql.log > E5-bitacora-postgresql.sha256 && cat E5-bitacora-postgresql.sha256
\! ls -l /tmp/lab03-evid

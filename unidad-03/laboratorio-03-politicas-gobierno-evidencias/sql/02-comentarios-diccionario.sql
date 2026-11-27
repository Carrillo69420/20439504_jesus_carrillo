-- =====================================================
-- LAB-03 — Políticas, gobierno de datos y evidencias
-- 02 · Comentarios y diccionario de datos
-- Sección 9 de la guía (Actividad 3)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador. Con log_statement = 'mod', cada
-- COMMENT queda en la bitácora con el texto completo del comentario.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Significado de la tabla y de sus columnas. Los seis primeros son los de la
-- guía; los de telefono, ciudad, codigo_postal, fecha_alta y segmento se
-- completaron con la finalidad que les dio la Unidad II. Cualquier usuario
-- conectado a la base puede leer los comentarios: no deben llevar secretos.
COMMENT ON TABLE clientes IS 'Clientes de Comercializadora Norte. Propietario: Gerencia Comercial. Custodio: DBA. Clasificación: confidencial (contiene datos personales).';
COMMENT ON COLUMN clientes.id IS 'Identificador interno del cliente. Generado por el sistema.';
COMMENT ON COLUMN clientes.nombre IS 'Nombre completo. Dato personal identificador directo.';
COMMENT ON COLUMN clientes.correo IS 'Correo de contacto. Dato personal. Uso: notificaciones al cliente.';
COMMENT ON COLUMN clientes.rfc IS 'RFC del cliente. Dato personal. Uso: facturación. Cambios auditados en auditoria.cambios_clientes.';
COMMENT ON COLUMN clientes.edad IS 'Edad en años cumplidos. Dato personal. Uso: analítica agregada.';
COMMENT ON COLUMN clientes.telefono IS 'Teléfono de contacto. Dato personal. Uso: contacto con el cliente.';
COMMENT ON COLUMN clientes.ciudad IS 'Ciudad del cliente. Dato personal. Uso: estadísticas por ciudad, solo en conteos.';
COMMENT ON COLUMN clientes.codigo_postal IS 'Código postal del cliente. Dato personal. Uso: región para estadísticas y, si es el del domicilio fiscal, facturación.';
COMMENT ON COLUMN clientes.fecha_alta IS 'Fecha de alta del cliente; por omisión, el día del registro. Dato personal. Uso: antigüedad del cliente y retención de sus datos.';
COMMENT ON COLUMN clientes.segmento IS 'Segmento comercial del cliente. Dato personal. Uso y valores válidos: pendientes de definir por la Gerencia Comercial.';

-- Diccionario: la estructura sale de information_schema.columns y el
-- significado, de col_description, que recibe la tabla y el número de columna
SELECT c.ordinal_position          AS pos,
       c.column_name               AS columna,
       c.data_type                 AS tipo,
       c.character_maximum_length  AS longitud,
       c.is_nullable               AS acepta_nulos,
       c.column_default            AS valor_por_defecto,
       col_description('public.clientes'::regclass, c.ordinal_position) AS descripcion
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name = 'clientes'
ORDER BY c.ordinal_position;

-- Agregadas, no vienen en la guía: comprueban si los COMMENT quedaron en la
-- bitácora (pregunta 2) y con qué nivel de registro
SHOW log_statement;

SELECT num,
       substr(linea, 1, 23) AS momento,
       substring(linea from 'user=([^ ]*)') AS usuario,
       substring(linea from 'statement: (COMMENT ON [A-Z]+ [^ ]+)') AS sentencia
FROM dba.bitacora
WHERE linea LIKE '%statement: COMMENT%'
ORDER BY num;

-- La exportación a CSV se hace desde PowerShell, fuera de esta sesión. El
-- archivo se crea dentro del contenedor con -o y se copia con docker cp:
--   docker exec dba-u3-pg psql -U postgres -d comercial --csv -o /tmp/diccionario-clientes.csv -c "SELECT c.column_name AS columna, c.data_type AS tipo, c.character_maximum_length AS longitud, c.is_nullable AS acepta_nulos, col_description('public.clientes'::regclass, c.ordinal_position) AS descripcion FROM information_schema.columns c WHERE c.table_schema = 'public' AND c.table_name = 'clientes' ORDER BY c.ordinal_position"
--   docker cp dba-u3-pg:/tmp/diccionario-clientes.csv "...\evidencias\diccionario-clientes.csv"

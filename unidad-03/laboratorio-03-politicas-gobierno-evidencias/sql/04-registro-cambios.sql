-- =====================================================
-- LAB-03 — Políticas, gobierno de datos y evidencias
-- 04 · Registro de solicitudes de cambio y extracción de cambios
-- Sección 13 de la guía (Actividad 7)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador. Crea el registro que pide POL-06,
-- registra el folio CAM-2026-014, ejecuta su cambio dentro de la ventana y
-- extrae de la bitácora los cambios de estructura y privilegios.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

CREATE SCHEMA gobierno;
REVOKE ALL ON SCHEMA gobierno FROM PUBLIC;

CREATE TABLE gobierno.solicitudes_cambio (
    folio            TEXT PRIMARY KEY,
    descripcion      TEXT NOT NULL,
    solicitado_por   TEXT NOT NULL,
    aprobado_por     TEXT,
    ambiente         TEXT NOT NULL CHECK (ambiente IN ('desarrollo', 'pruebas', 'produccion')),
    fecha_aprobacion TIMESTAMPTZ,
    ventana_inicio   TIMESTAMPTZ,
    ventana_fin      TIMESTAMPTZ
);

COMMENT ON TABLE gobierno.solicitudes_cambio IS 'Registro de solicitudes de cambio en la base comercial. Propietario: Comité de cambios. Custodio: DBA. Evidencia de POL-06.';

-- Folio aprobado ayer por el Comité de cambios, con la ventana abierta desde hace 5 minutos
INSERT INTO gobierno.solicitudes_cambio VALUES
('CAM-2026-014', 'Agregar columna canal_alta a clientes', 'Gerencia Comercial',
 'Comité de cambios', 'produccion', now() - interval '1 day',
 now() - interval '5 minutes', now() + interval '1 hour');

ALTER TABLE clientes ADD COLUMN canal_alta VARCHAR(20);
COMMENT ON COLUMN clientes.canal_alta IS 'Canal por el que se registró el cliente. Cambio CAM-2026-014.';

-- El cambio se hizo dentro de la ventana
SELECT folio, aprobado_por,
       ventana_inicio <= now() AND now() <= ventana_fin AS dentro_de_ventana
FROM gobierno.solicitudes_cambio;

-- Cambios de estructura y privilegios de todos los archivos de la bitácora.
-- dba.bitacora solo lee el archivo vigente y cada arranque abre uno nuevo,
-- así que se leen todos los del directorio log. Las contraseñas se tapan
-- antes de que salgan del servidor.
SELECT a.name                                     AS archivo,
       l.num,
       substr(l.linea, 1, 23)                     AS momento,
       substring(l.linea from 'user=([^ ]*)')     AS usuario,
       regexp_replace(substring(l.linea from 'statement: (.*)$'),
                      'PASSWORD\s+''[^'']*''', 'PASSWORD ''<REDACTED>''', 'gi') AS sentencia
FROM pg_ls_logdir() AS a
CROSS JOIN LATERAL regexp_split_to_table(pg_read_file('log/' || a.name), E'\n')
     WITH ORDINALITY AS l(linea, num)
WHERE a.name ~ '^postgresql-.*\.log$'
  AND l.linea ~ 'statement: (CREATE|ALTER|DROP|GRANT|REVOKE)'
ORDER BY a.name, l.num;

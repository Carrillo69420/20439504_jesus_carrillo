-- =====================================================
-- LAB-01 — Bitácoras y auditoría del dato en PostgreSQL
-- 05 · Función y disparador de auditoría de clientes
-- Sección 17 de la guía (Actividad 11)
-- Alumno: Jesús Arturo Carrillo Avilez
-- =====================================================
-- Se corre en la sesión de administrador, después de 04-esquema-auditoria.sql.
-- Con log_statement = 'mod' (Actividad 7), el CREATE FUNCTION, el REVOKE
-- y el CREATE TRIGGER quedan en la bitácora.

-- Sin paginador, para que cada resultado quede completo en la terminal
\pset pager off

-- Se ejecuta con los privilegios de su dueño (SECURITY DEFINER), así que
-- escribe en auditoria aunque quien cambia clientes no tenga acceso.
-- El search_path fijo decide dónde se buscan los nombres sin esquema
CREATE OR REPLACE FUNCTION auditoria.registrar_cambio_cliente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.cambios_clientes (operacion, id_cliente, valores_despues)
        VALUES (TG_OP, NEW.id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria.cambios_clientes (operacion, id_cliente, valores_antes, valores_despues)
        VALUES (TG_OP, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria.cambios_clientes (operacion, id_cliente, valores_antes)
        VALUES (TG_OP, OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- Una función nueva la puede ejecutar PUBLIC. Nadie necesita llamarla
-- directamente, y el disparador funciona sin ese privilegio
REVOKE ALL ON FUNCTION auditoria.registrar_cambio_cliente() FROM PUBLIC;

-- Después de cada alta, modificación o baja, una vez por fila
CREATE TRIGGER trg_auditoria_clientes
AFTER INSERT OR UPDATE OR DELETE ON clientes
FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio_cliente();

-- Verificación: el disparador (O = habilitado) y la función
SELECT tgname, tgenabled, tgrelid::regclass FROM pg_trigger WHERE NOT tgisinternal;
SELECT proname, prosecdef, proacl, proconfig FROM pg_proc WHERE proname = 'registrar_cambio_cliente';

-- Primera línea de cada sentencia de la auditoría en la bitácora
SELECT num, linea FROM dba.bitacora
WHERE linea LIKE '%statement:%' AND linea LIKE '%auditoria%'
ORDER BY num;

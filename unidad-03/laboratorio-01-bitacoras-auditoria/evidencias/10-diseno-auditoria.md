# Evidencia 10 — Diseño del registro de auditoría

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividades 10 y 11 (secciones 16 y 17 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 29 de octubre de 2026

## Objetivo

Decidir qué debe guardar cada registro de auditoría de `clientes`, justificando cada campo con las preguntas de Dirección, y crear la tabla en un esquema sin acceso público. Después, crear la función y el disparador que la llenan (Actividad 11, al final de este documento).

## Diseño del registro

El reporte de facturación indica que el RFC de María García (`id = 3`) no coincide con el que se registró originalmente. Dirección pregunta (sección 5 de la guía):

1. ¿Quién hizo el cambio?
2. ¿Cuándo?
3. ¿Desde qué aplicación o equipo?
4. ¿Hubo intentos de acceso fallidos antes del cambio?
5. ¿Qué valor tenía el RFC antes del cambio?

| Campo | Tipo | ¿Qué pregunta responde? | ¿Puede ser nulo? ¿Por qué? |
| --- | --- | --- | --- |
| `id_evento` | `BIGSERIAL` | Ninguna por sí solo: identifica cada registro y da el orden en que se guardaron, para poder citar un registro concreto. | No. Es la llave primaria y lo asigna una secuencia. La numeración puede tener huecos, porque un número que se tomó en una transacción que se deshizo no se vuelve a usar; un número que falta no prueba por sí solo que se borró un registro. |
| `momento` | `TIMESTAMPTZ` | 2. ¿Cuándo? | No. Un registro sin hora no sirve como evidencia, y `now()` siempre da una: la hora en que empezó la transacción. |
| `usuario_sesion` | `TEXT` | 1. ¿Quién hizo el cambio? Es el usuario con el que se conectó la sesión, el mismo que la bitácora registra en `user=`. | No. Toda sesión se conecta con un usuario. |
| `usuario_efectivo` | `TEXT` | 1. ¿Quién?, del lado de los privilegios: con los permisos de qué usuario se ejecutó el cambio. | No. Siempre hay un usuario actual. Suele coincidir con `usuario_sesion`; cambia con `SET ROLE` y dentro de una función `SECURITY DEFINER`, que se ejecuta con los privilegios de su dueño. |
| `aplicacion` | `TEXT` | 3. ¿Desde qué aplicación? | Sí. El nombre de la aplicación lo declara el cliente al conectarse, si quiere, y la auditoría no debe depender de él. Si no lo declara, `current_setting` devuelve una cadena vacía, no un nulo. |
| `ip_cliente` | `INET` | 3. ¿Desde qué equipo? | Sí. Una sesión por el socket local no tiene IP, e `inet_client_addr()` devuelve nulo, como el `client_addr` vacío del administrador en la [evidencia 09](09-pg-stat-activity.md). |
| `operacion` | `TEXT` | Qué se hizo: un alta (`INSERT`), una modificación (`UPDATE`) o una baja (`DELETE`). | No. Todo registro corresponde a una operación, y el disparador la escribe siempre (Actividad 11). |
| `id_cliente` | `BIGINT` | A qué cliente le pasó; en el caso de Dirección, al `id = 3`. Es del mismo tipo que `clientes.id`. | La columna lo permite, pero el disparador siempre lo llena, con `NEW.id` o con `OLD.id`. No tiene llave foránea hacia `clientes`, y así conviene: cuando un cliente se borra, sus registros de auditoría tienen que quedarse. |
| `valores_antes` | `JSONB` | 5. ¿Qué valor tenía el RFC antes del cambio? Guarda la fila completa como estaba, con su RFC. | Sí. En un alta no hay valores anteriores. |
| `valores_despues` | `JSONB` | Cómo quedó la fila. Comparada con `valores_antes`, muestra qué columnas cambiaron. | Sí. En una baja no hay valores posteriores. |

La pregunta 4 no la responde esta tabla. Un intento de acceso fallido no llega a cambiar ningún dato, así que el disparador nunca se ejecuta. La responde la bitácora, con las líneas `FATAL:  password authentication failed` de la [evidencia 05](05-accesos.md).

## Pasos y resultados

### 1. Esquema y tabla

En la sesión de administrador, con el bloque de la guía (el mismo de [sql/04-esquema-auditoria.sql](../sql/04-esquema-auditoria.sql)):

```sql
CREATE SCHEMA auditoria;
REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;
CREATE TABLE auditoria.cambios_clientes (
    id_evento        BIGSERIAL PRIMARY KEY,
    momento          TIMESTAMPTZ NOT NULL DEFAULT now(),
    usuario_sesion   TEXT        NOT NULL DEFAULT session_user,
    usuario_efectivo TEXT        NOT NULL DEFAULT current_user,
    aplicacion       TEXT        DEFAULT current_setting('application_name'),
    ip_cliente       INET        DEFAULT inet_client_addr(),
    operacion        TEXT        NOT NULL,
    id_cliente       BIGINT,
    valores_antes    JSONB,
    valores_despues  JSONB
);
```

```text
CREATE SCHEMA
REVOKE
CREATE TABLE
```

El esquema aparte y el `REVOKE` son como los del esquema `dba` en la [evidencia 02](02-colector.md): los objetos de la auditoría quedan separados de los datos del negocio, con sus propios privilegios.

### 2. Privilegios del esquema

```sql
\dn+ auditoria
```

```text
                      List of schemas
   Name    |  Owner   |  Access privileges   | Description
-----------+----------+----------------------+-------------
 auditoria | postgres | postgres=UC/postgres |
(1 row)
```

- `postgres=UC/postgres` se lee `rol=privilegios/quién los otorgó`: el dueño, `postgres`, tiene USAGE (`U`, acceder a lo que hay dentro) y CREATE (`C`, crear objetos dentro).
- PUBLIC no aparece. Si tuviera algún privilegio, saldría una entrada sin nombre antes del `=`, como `=U/postgres`.
- Un esquema recién creado no le da ningún privilegio a PUBLIC: su `Access privileges` sale vacío, que significa «los privilegios por defecto», solo los del dueño. El `REVOKE` no le quitó nada a PUBLIC, pero dejó la lista escrita, y por eso ahora se ve `postgres=UC/postgres`.
- Sin USAGE en el esquema, `app_ventas` y `soporte_ana` no pueden usar nada de lo que hay dentro: un `SELECT` a la tabla les responde `permission denied for schema auditoria`.

### 3. Estructura de la tabla

```sql
\d auditoria.cambios_clientes
```

```text
                                                 Table "auditoria.cambios_clientes"
      Column      |           Type           | Collation | Nullable |                            Default
------------------+--------------------------+-----------+----------+---------------------------------------------------------------
 id_evento        | bigint                   |           | not null | nextval('auditoria.cambios_clientes_id_evento_seq'::regclass)
 momento          | timestamp with time zone |           | not null | now()
 usuario_sesion   | text                     |           | not null | SESSION_USER
 usuario_efectivo | text                     |           | not null | CURRENT_USER
 aplicacion       | text                     |           |          | current_setting('application_name'::text)
 ip_cliente       | inet                     |           |          | inet_client_addr()
 operacion        | text                     |           | not null |
 id_cliente       | bigint                   |           |          |
 valores_antes    | jsonb                    |           |          |
 valores_despues  | jsonb                    |           |          |
Indexes:
    "cambios_clientes_pkey" PRIMARY KEY, btree (id_evento)
```

- `BIGSERIAL` no es un tipo en sí: la columna quedó como `bigint`, con el valor por defecto `nextval(...)`, y PostgreSQL creó la secuencia `auditoria.cambios_clientes_id_evento_seq`. La llave primaria creó el índice `cambios_clientes_pkey`.
- `TIMESTAMPTZ` aparece con su nombre completo, `timestamp with time zone`.
- `session_user` y `current_user` salen en mayúsculas y sin paréntesis porque son palabras clave del estándar SQL, no funciones comunes.
- Las columnas sin `not null` son las que la tabla de diseño marca como «puede ser nulo». `operacion` es `not null` y no tiene valor por defecto: el disparador tiene que darla siempre.

## Análisis

**¿Por qué `momento` usa `TIMESTAMPTZ` y no `TIMESTAMP`?**

Porque la hora de un registro de auditoría es evidencia, y tiene que señalar un instante sin ambigüedad. `TIMESTAMPTZ` guarda el instante (internamente en UTC) y lo muestra en la zona horaria de la sesión. `TIMESTAMP` guarda solo la fecha y la hora del reloj, sin la zona, y después no hay forma de saber a qué instante correspondían.

En este laboratorio se nota. El servidor está en `America/Mazatlan` (UTC−7) y la guía muestra sus resultados en UTC. Con `TIMESTAMPTZ`, `12:32:23-07` y `19:32:23+00` se reconocen como el mismo instante. Un `TIMESTAMP` guardaría solo «12:32:23», y quien lo leyera en otro equipo no sabría si son las 12:32 de Mazatlán o las de UTC, con siete horas de diferencia. Lo mismo pasaría si el servidor cambiara de zona horaria o si los registros se pasaran a otro servidor. Además, con `TIMESTAMPTZ` el registro se puede empatar con la bitácora, que también trae la zona en cada línea (`MST`).

**¿Por qué se guarda el registro completo en `JSONB` y no solo la columna que cambió?**

- Porque no se sabe de antemano qué columna va a cambiar. Con la fila completa, el mismo disparador sirve para un cambio de RFC, de correo o de varias columnas a la vez, y para las altas y las bajas, en las que cambia la fila entera.
- Con la fila de antes y la de después, las columnas que cambiaron se obtienen comparándolas, que es lo que hace `sql/06-campos-modificados.sql` en la Actividad 12. Además, la fila anterior completa permite reconstruir cómo estaba el cliente, para corregirlo si el cambio fue indebido.
- Un documento JSON no depende de las columnas de la tabla. En la Actividad 6 se agregó la columna `segmento` a `clientes` (`ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);`). Si la auditoría tuviera una columna por cada columna de `clientes`, habría que modificarla cada vez que cambiara la estructura. Con `JSONB`, cada registro conserva la fila con las columnas que tenía en ese momento, y los registros viejos siguen siendo válidos.
- El costo es espacio, y que cada registro lleva una copia completa de los datos personales del cliente. Eso es lo que plantea la siguiente pregunta.

**La tabla de auditoría también contendrá RFC. ¿Qué implica eso para su clasificación y su control de acceso?**

Que la tabla se clasifica, como mínimo, igual que el RFC en `clientes`. En la Unidad II el RFC quedó con riesgo alto (LAB-01: es un identificador fiscal único y además revela letras del nombre y la fecha de nacimiento) y con acceso restringido a Facturación (LAB-03). Una copia del dato tiene el mismo riesgo que el original. Y la tabla de auditoría junta más que `clientes`: guarda cada RFC que el cliente ha tenido, también los que se corrigieron y los de clientes que ya se dieron de baja.

En el control de acceso implica:

- **Lectura solo para quien audita.** El esquema `auditoria` no da acceso a PUBLIC (paso 2), así que `app_ventas` y `soporte_ana` no pueden leer la tabla. Tampoco Facturación debería leerla: necesita el RFC actual para facturar, no el historial.
- **Escritura solo por el disparador.** Nadie recibe `INSERT`, `UPDATE` ni `DELETE` sobre la tabla. La llena el disparador de la Actividad 11, que se ejecuta con los privilegios de su dueño (`SECURITY DEFINER`). Así, quien cambia un cliente no puede borrar ni corregir su propio registro, y tampoco escribir lo que quiera en las columnas que se llenan solas, como `usuario_sesion` o `ip_cliente`.
- **La misma protección que el original.** En la Unidad II se decidió que el RFC va en una tabla aparte, solo para Facturación y cifrado, y nunca en vistas de otras áreas ni en copias de desarrollo (LAB-03, evidencia 11). Una copia del RFC en claro dentro de la auditoría rompe esa regla si no se protege igual. Lo mismo vale para los respaldos y las exportaciones de la tabla.
- **Retención y derechos ARCO.** El RFC se conserva mientras la persona sea cliente (cinco años en las facturas emitidas, por el art. 30 del CFF), y después se bloquea y se suprime. Si un cliente pide la supresión, su RFC sigue en `valores_antes` y `valores_despues`. La auditoría necesita su propio plazo de conservación, justificado, en lugar de guardar los datos para siempre.

## Conclusión

Un solo registro de `auditoria.cambios_clientes` responde cuatro de las cinco preguntas de Dirección: quién (`usuario_sesion`), cuándo (`momento`), desde qué aplicación y equipo (`aplicacion` e `ip_cliente`) y qué valor tenía el RFC (`valores_antes`). Los intentos fallidos siguen dependiendo de la bitácora. Como la tabla guarda copias completas de las filas, con sus datos personales, se creó en un esquema sin acceso público. Fuera del administrador, lo único que escribirá en ella es el disparador de la Actividad 11.

## Actividad 11 — La función y el disparador

Sección 17 de la guía. Para esta actividad la guía solo pide el script, [sql/05-funcion-disparador.sql](../sql/05-funcion-disparador.sql), así que sus preguntas se responden aquí.

### 1. Función y disparador

En la misma sesión de administrador, con el bloque de la guía:

```sql
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
REVOKE ALL ON FUNCTION auditoria.registrar_cambio_cliente() FROM PUBLIC;
CREATE TRIGGER trg_auditoria_clientes
AFTER INSERT OR UPDATE OR DELETE ON clientes
FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio_cliente();
```

```text
CREATE FUNCTION
REVOKE
CREATE TRIGGER
```

- PostgreSQL le pasa a la función `TG_OP` (la operación), `OLD` (la fila como estaba) y `NEW` (la fila como quedó). Con ellos, la función inserta un registro en `auditoria.cambios_clientes` y solo llena `operacion`, `id_cliente` y los valores; las demás columnas las llenan sus valores por defecto.
- `AFTER INSERT OR UPDATE OR DELETE … FOR EACH ROW`: el disparador se ejecuta después de cada alta, modificación o baja, una vez por cada fila afectada.
- `SET search_path = pg_catalog, public` fija dónde busca la función los nombres que no llevan esquema, como `to_jsonb`. Así nadie puede hacer que use un objeto con el mismo nombre creado en otro esquema.

### 2. Verificación

```sql
SELECT tgname, tgenabled, tgrelid::regclass FROM pg_trigger WHERE NOT tgisinternal;
SELECT proname, prosecdef, proacl, proconfig FROM pg_proc WHERE proname = 'registrar_cambio_cliente';
```

```text
         tgname         | tgenabled | tgrelid
------------------------+-----------+----------
 trg_auditoria_clientes | O         | clientes
(1 row)

         proname          | prosecdef |        proacl         |             proconfig
--------------------------+-----------+-----------------------+------------------------------------
 registrar_cambio_cliente | t         | {postgres=X/postgres} | {"search_path=pg_catalog, public"}
(1 row)
```

- El disparador está en `clientes` y la `O` indica que está habilitado, igual que en la guía. `NOT tgisinternal` deja fuera los disparadores que PostgreSQL crea por su cuenta, como los de las llaves foráneas.
- La segunda consulta no viene en la guía; se agregó para ver cómo quedó la función:
  - `prosecdef` en `t`: es `SECURITY DEFINER`.
  - `proacl` en `{postgres=X/postgres}`: solo su dueño tiene el privilegio de ejecutarla (`X` es EXECUTE). Una función recién creada tiene esta columna vacía, que significa los privilegios por defecto, y esos incluyen EXECUTE para PUBLIC.
  - `proconfig`: el `search_path` fijo con el que se ejecuta.

### 3. La creación en la bitácora

```sql
SELECT num, linea FROM dba.bitacora
WHERE linea LIKE '%statement:%' AND linea LIKE '%auditoria%'
ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
 130 | 2026-10-29 12:49:41.837 MST [940] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE SCHEMA auditoria;
 131 | 2026-10-29 12:49:41.846 MST [940] user=postgres db=comercial app=psql client=[local] LOG:  statement: REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;
 132 | 2026-10-29 12:49:41.850 MST [940] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE TABLE auditoria.cambios_clientes (
 146 | 2026-10-29 12:57:57.628 MST [940] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE OR REPLACE FUNCTION auditoria.registrar_cambio_cliente()
 169 | 2026-10-29 12:57:57.647 MST [940] user=postgres db=comercial app=psql client=[local] LOG:  statement: REVOKE ALL ON FUNCTION auditoria.registrar_cambio_cliente() FROM PUBLIC;
 170 | 2026-10-29 12:57:57.649 MST [940] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE TRIGGER trg_auditoria_clientes
(6 rows)
```

- Quedaron las seis sentencias, todas de la sesión 940, la del administrador por el socket local (`client=[local]`): las tres de la Actividad 10 a las 12:49:41 y las tres de esta actividad a las 12:57:57.
- La búsqueda solo trae la primera línea de cada sentencia. El resto está en las líneas siguientes, que empiezan con tabulador: la tabla ocupa de la 132 a la 143, la función de la 146 a la 168 y el disparador de la 170 a la 172.

### Análisis

**¿Por qué se ejecuta `REVOKE ALL ON FUNCTION ... FROM PUBLIC` si el disparador seguirá funcionando para `app_ventas`?**

Porque PostgreSQL le da a PUBLIC el privilegio de ejecutar cualquier función nueva, a diferencia de los esquemas y las tablas, y esta función es `SECURITY DEFINER`: trabaja con los privilegios de `postgres`, el superusuario. Nadie necesita llamarla directamente, así que no tiene por qué quedar abierta a todos (menor privilegio). Es un segundo candado: hoy el esquema `auditoria` ya está cerrado a PUBLIC, pero si algún día se le diera acceso al esquema a otro rol, por ejemplo para revisar la auditoría, la función seguiría cerrada.

El disparador sigue funcionando porque PostgreSQL revisa el privilegio de ejecutar la función cuando se crea el disparador, no cada vez que se dispara. Quien cambia `clientes` solo necesita su permiso sobre la tabla; en el caso de `app_ventas`, el de `UPDATE`. Además, una función de disparador no se puede llamar como una función común: `SELECT auditoria.registrar_cambio_cliente();` responde `trigger functions can only be called as triggers`.

**¿Qué pasaría si la función no fuera `SECURITY DEFINER`? (hipótesis antes de la Actividad 12)**

El `UPDATE` de `app_ventas` fallaría completo. Sin `SECURITY DEFINER`, la función se ejecutaría con los privilegios de quien hizo el cambio, y `app_ventas` no tiene acceso al esquema `auditoria`, así que el `INSERT` del registro respondería `permission denied for schema auditoria`. Como el disparador corre en la misma transacción que el cambio, el error deshace también el `UPDATE` de `clientes`: el cliente no cambiaría y no quedaría ningún registro. Para que funcionara sin `SECURITY DEFINER` habría que darle a `app_ventas` acceso al esquema y permiso de `INSERT` en la tabla de auditoría, y entonces podría escribir ahí registros por su cuenta, con lo que quisiera en cada columna.

Con `SECURITY DEFINER` se espera otra consecuencia: dentro de la función, `current_user` es el dueño, así que `usuario_efectivo` debería decir `postgres` en todos los registros, aunque el cambio lo haga `app_ventas`. Se comprueba en la Actividad 12.

**Consulta `dba.bitacora`. ¿Quedó registrada la creación del esquema, la tabla, la función y el disparador? ¿Por qué?**

Sí, las cuatro, y también los dos `REVOKE` (paso 3): seis sentencias, cada una con su hora, el PID 940, el usuario `postgres` y `client=[local]`. Quedaron porque `log_statement` está en `'mod'` desde la Actividad 7, y `'mod'` registra todo lo que registra `'ddl'` (`CREATE`, `ALTER`, `DROP`, `GRANT` y `REVOKE`) más las sentencias que modifican datos. Con `'none'`, el valor por defecto, no habría quedado nada.

Para la auditoría esto importa porque la bitácora guarda el código completo de la función (líneas 146 a 168). Si alguien la cambiara después con otro `CREATE OR REPLACE FUNCTION`, o desactivara el disparador con `ALTER TABLE … DISABLE TRIGGER`, también quedaría registrado, con su hora y su usuario. La excepción es un superusuario que apague antes el registro de su propia sesión con `SET log_statement = 'none'`, que no deja rastro.

### Conclusión

El disparador `trg_auditoria_clientes` quedó habilitado en `clientes` y ejecuta una función `SECURITY DEFINER` cerrada a PUBLIC. Desde ahora, cada alta, modificación o baja de un cliente deja un registro en `auditoria.cambios_clientes`, sin que la aplicación tenga que hacer nada y sin que `app_ventas` pueda escribir en la auditoría por su cuenta. La creación de todo quedó en la bitácora, con el código completo de la función.

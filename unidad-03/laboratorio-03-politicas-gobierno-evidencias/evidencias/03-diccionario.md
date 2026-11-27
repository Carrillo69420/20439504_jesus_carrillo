# Evidencia 03 — Diccionario de datos operativo dentro del motor

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 3 (sección 9 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 24 de noviembre de 2026

## Objetivo

Guardar dentro del motor el significado de la tabla `clientes` y de cada una de sus columnas, consultarlo junto con su estructura, y completar fuera del motor lo que el motor no conoce: la clasificación, la finalidad, los controles y las reglas de calidad de cada columna.

## Pasos y resultados

Los pasos 1 a 3 se ejecutaron en la sesión de administrador, y el 4, en PowerShell. Las sentencias están en [sql/02-comentarios-diccionario.sql](../sql/02-comentarios-diccionario.sql); aquí van como se escribieron en `psql`, cada una en una línea.

### 1. Los comentarios

```sql
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
```

```text
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
COMMENT
```

Salió un `COMMENT` por sentencia: uno para la tabla y diez para sus columnas. Los seis primeros comentarios son los de la guía. Los de `telefono`, `ciudad`, `codigo_postal`, `fecha_alta` y `segmento` siguen el mismo formato (qué es el dato, si es personal y para qué se usa), con la finalidad que les dio la Unidad II. `segmento` es la excepción: se agregó en el LAB-01 como ejemplo de cambio de estructura ([evidencia 06](../../laboratorio-01-bitacoras-auditoria/evidencias/06-privilegios-estructura.md)), sin finalidad ni valores definidos. Por eso su comentario lo dice y deja la decisión a la Gerencia Comercial, su propietaria.

### 2. El diccionario

```sql
SELECT c.ordinal_position AS pos, c.column_name AS columna, c.data_type AS tipo, c.character_maximum_length AS longitud, c.is_nullable AS acepta_nulos, c.column_default AS valor_por_defecto, col_description('public.clientes'::regclass, c.ordinal_position) AS descripcion FROM information_schema.columns c WHERE c.table_schema = 'public' AND c.table_name = 'clientes' ORDER BY c.ordinal_position;
```

```text
 pos |    columna    |       tipo        | longitud | acepta_nulos |          valor_por_defecto           |                                                            descripcion
-----+---------------+-------------------+----------+--------------+--------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------
   1 | id            | bigint            |          | NO           | nextval('clientes_id_seq'::regclass) | Identificador interno del cliente. Generado por el sistema.
   2 | nombre        | character varying |      120 | NO           |                                      | Nombre completo. Dato personal identificador directo.
   3 | correo        | character varying |      150 | NO           |                                      | Correo de contacto. Dato personal. Uso: notificaciones al cliente.
   4 | telefono      | character varying |       20 | YES          |                                      | Teléfono de contacto. Dato personal. Uso: contacto con el cliente.
   5 | rfc           | character varying |       13 | YES          |                                      | RFC del cliente. Dato personal. Uso: facturación. Cambios auditados en auditoria.cambios_clientes.
   6 | edad          | integer           |          | YES          |                                      | Edad en años cumplidos. Dato personal. Uso: analítica agregada.
   7 | ciudad        | character varying |       80 | YES          |                                      | Ciudad del cliente. Dato personal. Uso: estadísticas por ciudad, solo en conteos.
   8 | codigo_postal | character varying |       10 | YES          |                                      | Código postal del cliente. Dato personal. Uso: región para estadísticas y, si es el del domicilio fiscal, facturación.
   9 | fecha_alta    | date              |          | YES          | CURRENT_DATE                         | Fecha de alta del cliente; por omisión, el día del registro. Dato personal. Uso: antigüedad del cliente y retención de sus datos.
  10 | segmento      | character varying |       20 | YES          |                                      | Segmento comercial del cliente. Dato personal. Uso y valores válidos: pendientes de definir por la Gerencia Comercial.
(10 rows)
```

- Las seis primeras columnas del resultado salen de `information_schema.columns`, la estructura que el motor conoce, y la última, de los comentarios del paso 1. `col_description` recibe la tabla y el número de la columna, y `ordinal_position` es ese número.
- La estructura confirma dos comentarios: `id` lo genera la secuencia `clientes_id_seq`, y `fecha_alta` toma por omisión `CURRENT_DATE`, el día del registro. Solo `id`, `nombre` y `correo` son obligatorios (`acepta_nulos` es `NO`).
- La estructura no sustituye a una regla de calidad. `rfc` es `character varying(13)`, que solo fija la longitud máxima; por eso la tabla aceptó el RFC de 12 caracteres del registro 7 (hallazgo C2 de la [evidencia 01](01-calidad.md)).

### 3. ¿Quedaron en la bitácora?

```sql
SHOW log_statement;
SELECT num, substr(linea, 1, 23) AS momento, substring(linea from 'user=([^ ]*)') AS usuario, substring(linea from 'statement: (COMMENT ON [A-Z]+ [^ ]+)') AS sentencia FROM dba.bitacora WHERE linea LIKE '%statement: COMMENT%' ORDER BY num;
```

```text
 log_statement
---------------
 mod
(1 row)

 num |         momento         | usuario  |                sentencia
-----+-------------------------+----------+------------------------------------------
  17 | 2026-11-24 09:08:59.541 | postgres | COMMENT ON TABLE clientes
  18 | 2026-11-24 09:08:59.554 | postgres | COMMENT ON COLUMN clientes.id
  19 | 2026-11-24 09:08:59.556 | postgres | COMMENT ON COLUMN clientes.nombre
  20 | 2026-11-24 09:08:59.558 | postgres | COMMENT ON COLUMN clientes.correo
  21 | 2026-11-24 09:08:59.560 | postgres | COMMENT ON COLUMN clientes.rfc
  22 | 2026-11-24 09:08:59.562 | postgres | COMMENT ON COLUMN clientes.edad
  23 | 2026-11-24 09:08:59.563 | postgres | COMMENT ON COLUMN clientes.telefono
  24 | 2026-11-24 09:08:59.564 | postgres | COMMENT ON COLUMN clientes.ciudad
  25 | 2026-11-24 09:08:59.565 | postgres | COMMENT ON COLUMN clientes.codigo_postal
  26 | 2026-11-24 09:08:59.566 | postgres | COMMENT ON COLUMN clientes.fecha_alta
  27 | 2026-11-24 09:08:59.567 | postgres | COMMENT ON COLUMN clientes.segmento
(11 rows)
```

Las once sentencias están en la bitácora, en las líneas 17 a 27 del archivo de hoy, con el usuario y la hora. Entre la primera y la última hay 26 milisegundos porque se pegaron juntas. La consulta solo muestra el inicio de cada sentencia; en la bitácora está completa, con el texto del comentario.

### 4. Exportación a CSV

En los comandos se usó la ruta completa de la carpeta del laboratorio; aquí se abrevia con `...`:

```powershell
docker exec dba-u3-pg psql -U postgres -d comercial --csv -o /tmp/diccionario-clientes.csv -c "SELECT c.column_name AS columna, c.data_type AS tipo, c.character_maximum_length AS longitud, c.is_nullable AS acepta_nulos, col_description('public.clientes'::regclass, c.ordinal_position) AS descripcion FROM information_schema.columns c WHERE c.table_schema = 'public' AND c.table_name = 'clientes' ORDER BY c.ordinal_position"
docker cp dba-u3-pg:/tmp/diccionario-clientes.csv "...\evidencias\diccionario-clientes.csv"
```

```text
Successfully copied 1.21kB (transferred 3.07kB) to ...\evidencias\diccionario-clientes.csv
```

La consulta es la de la guía. La guía guarda el resultado con `>` desde la carpeta del laboratorio; aquí `psql` está dentro del contenedor, y en PowerShell 5.1 `>` guarda la salida en UTF-16. Con `-o`, el archivo se crea dentro del contenedor y `docker cp` lo copia tal cual, como en el LAB-01 ([evidencia 15](../../laboratorio-01-bitacoras-auditoria/evidencias/15-cronologia.md)).

[diccionario-clientes.csv](diccionario-clientes.csv) tiene 11 renglones, el encabezado y uno por columna, en UTF-8. `psql` puso entre comillas las tres descripciones que llevan comas (`ciudad`, `codigo_postal` y `fecha_alta`), como pide el formato CSV, para que la coma no se confunda con un separador.

### 5. Lo que el motor no conoce

| Columna | Clasificación (Unidad II) | Finalidad | Control aplicado | ¿Cambios auditados? | Regla de calidad |
| --- | --- | --- | --- | --- | --- |
| id | Dato personal de forma indirecta; protección media | Ubicar el registro del cliente y relacionarlo con otras tablas | Sustituido por un token en la tabla de Analítica (U2) | Sí, LAB-01 Parte B | Lo asigna la secuencia; no se captura |
| nombre | Dato personal, identificador directo; protección alta | Saber con quién se trata y ponerlo en sus facturas | Excluido de la tabla de Analítica (U2) | Sí, LAB-01 Parte B | Obligatorio |
| correo | Dato personal, identificador directo; protección alta | Contactar al cliente y responder sus solicitudes | Vista enmascarada para soporte (U2) | Sí, LAB-01 Parte B | Obligatorio, con formato de correo y sin duplicados aunque cambien las mayúsculas (C1 y C4) |
| telefono | Dato personal, identificador directo; protección alta | Contactar al cliente | Vista enmascarada para soporte (U2) | Sí, LAB-01 Parte B | 10 dígitos (C6) |
| rfc | Dato personal, identificador directo; protección alta | Emitir facturas | Vista enmascarada para soporte (U2); cifrado probado en una tabla de demostración (LAB-02 de la U2) | Sí, LAB-01 Parte B | Formato RFC (C2); obligatorio si el cliente factura (C3) |
| edad | Dato personal que contribuye a identificar; protección media | Estadísticas por rango de edad | En la tabla de Analítica, ligada a un token y no al cliente (U2) | Sí, LAB-01 Parte B | Entre 18 y 120 años (C5) |
| ciudad | Dato personal que contribuye a identificar; protección media | Estadísticas por ciudad | En la tabla de Analítica, ligada a un token (U2) | Sí, LAB-01 Parte B | Un solo nombre válido por ciudad, de una lista que falta definir (C8) |
| codigo_postal | Dato personal que contribuye a identificar; protección media | Estadísticas por región y, si es el del domicilio fiscal, la factura | En la tabla de Analítica, ligado a un token (U2) | Sí, LAB-01 Parte B | 5 dígitos (C7) |
| fecha_alta | Dato personal en menor grado; protección baja | Saber desde cuándo es cliente y desde cuándo se tienen sus datos | En la tabla de Analítica, ligada a un token (U2) | Sí, LAB-01 Parte B | Sin regla; la pone el servidor |
| segmento | Sin clasificar: no existía en la Unidad II | Sin definir | Ninguno | Sí, LAB-01 Parte B | Sin regla: faltan los valores válidos |

- **Clasificación y finalidad.** Salen del [informe del LAB-01](../../../unidad-02/laboratorio-01-proteccion-datos/informe.md) y de la [evidencia 01 del LAB-03](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/01-inventario-datos.md) de la Unidad II.
- **Los controles de la Unidad II no están en este servidor.** Se aplicaron en `dba-practica`, el servidor de esa unidad. En `dba-u3-pg`, `soporte_ana` tiene `SELECT` sobre la tabla misma, así que ve los datos sin enmascarar, y en el LAB-01 consultó el RFC de María García ([informe del LAB-01](../../laboratorio-01-bitacoras-auditoria/informe.md)). Es un hallazgo para el expediente (Actividad 9).
- **Cambios auditados.** El disparador `trg_auditoria_clientes` guarda la fila completa antes y después del cambio, con `to_jsonb(OLD)` y `to_jsonb(NEW)` ([LAB-01, sql/05](../../laboratorio-01-bitacoras-auditoria/sql/05-funcion-disparador.sql)). Por eso cubre todas las columnas, también `segmento`, que no existía en la Unidad II. Lo hace mientras esté encendido: en la Actividad 14 del LAB-01, el administrador lo apagó, cambió el RFC del cliente 3 y lo volvió a encender, y ese cambio no quedó en la auditoría ([evidencia 13 del LAB-01](../../laboratorio-01-bitacoras-auditoria/evidencias/13-manipulacion.md)).
- **Reglas de calidad.** Son las de la [evidencia 01](01-calidad.md), de C1 a C8. Ninguna está en el motor como restricción: cada una la incumple el registro 7 o el 8, y la tabla aceptó los dos. La pregunta 2 de esa evidencia propone la restricción con que se aplicaría cada regla.

## Preguntas

**1. ¿Qué ventaja tiene guardar el significado en `COMMENT` en lugar de solo en un documento aparte?**

Que el significado queda pegado al objeto que describe:

- Lo ve quien consulte la tabla, sin buscar otro documento: con `\d+ clientes` en `psql`, en una herramienta gráfica o con la consulta del paso 2, que junta la estructura y el significado en un solo resultado.
- Sigue al objeto. Según la documentación de `COMMENT`, cuando se elimina un objeto, su comentario se elimina con él, así que el diccionario no describe columnas que ya no existen. Y `pg_dump` incluye los comentarios, salvo que se use su opción `--no-comments`, así que un respaldo lleva el diccionario y se restaura con la base.
- Cada cambio queda registrado. Cambiar un comentario es una sentencia, que queda en la bitácora con el usuario y la hora (paso 3).

Un documento aparte se desactualiza sin que nadie lo note: puede seguir describiendo una columna que ya cambió, y no dice quién lo editó.

**2. ¿Quedaron registrados los `COMMENT` en la bitácora? ¿Con qué nivel de `log_statement`?**

Sí. Las once sentencias están en las líneas 17 a 27 de la bitácora, con `log_statement = 'mod'` (paso 3). Según la documentación de PostgreSQL 16, `ddl` registra las sentencias de definición de datos, como `CREATE`, `ALTER` y `DROP`, y `mod` registra las mismas más las que modifican datos: `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` y `COPY FROM`. `COMMENT` no está entre las que modifican datos, así que si quedó con `mod` es porque PostgreSQL la cuenta como sentencia de definición: cambia la descripción de un objeto en el catálogo, no los datos de una tabla. Se deduce que con `ddl` también habría quedado, aunque no se probó; con `none` no habría quedado.

La bitácora guarda cada sentencia completa, con el texto del comentario. Lo que se escriba en un comentario queda también en la bitácora.

**3. ¿Qué información del diccionario debe mantenerse fuera del motor? ¿Por qué?**

1. **Lo que no debe leer cualquiera.** La documentación de `COMMENT` advierte que no hay ningún mecanismo de seguridad para ver los comentarios: cualquier usuario conectado a la base ve todos los de esa base, y recomienda no poner en ellos información crítica para la seguridad. En `comercial` eso incluye a `app_ventas` y a `soporte_ana`. Dónde se guarda la clave con que se cifra el RFC, qué columna tiene un control débil o un hallazgo con datos de un cliente no van en un comentario, y menos sabiendo que el comentario también queda en la bitácora (pregunta 2).
2. **Lo que necesita gente sin acceso a la base.** Auditoría interna no tiene cuenta en ningún servidor, y Facturación y Analítica no la tienen en `dba-u3-pg` ([evidencia 02](02-responsables.md)). Para ellas el diccionario tiene que existir fuera del motor, como el CSV del paso 4 y la tabla del paso 5. Esa copia también evita depender del servidor: si se pierde, el diccionario que vive en el catálogo se pierde con él.
3. **Las decisiones y su historia.** Quién aprobó la clasificación de cada columna y cuándo, el fundamento de cada plazo de conservación (Actividad 5), las reglas de calidad acordadas y el seguimiento de sus hallazgos. Un comentario guarda un solo texto: al cambiarlo, el anterior desaparece del catálogo, y solo queda en la bitácora mientras esta se conserve. Esas decisiones necesitan su propio registro, con fecha y responsable.

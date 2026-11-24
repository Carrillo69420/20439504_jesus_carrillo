# Evidencia 01 — Calidad de datos desde la operación

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 1 (sección 7 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 24 de noviembre de 2026

## Objetivo

Detectar problemas de calidad en los datos de clientes con verificaciones sencillas, registrar cada hallazgo y escalarlo a quien decide la corrección.

## Pasos y resultados

Todo se ejecutó en la sesión de administrador. Las sentencias están en [sql/01-verificaciones-calidad.sql](../sql/01-verificaciones-calidad.sql); aquí van como se escribieron en `psql`, en una sola línea.

### 1. Dos registros capturados con errores

```sql
INSERT INTO clientes (nombre, correo, telefono, rfc, edad, ciudad, codigo_postal) VALUES
('Ana Lopez', 'ANA.LOPEZ@example.test', '6671234567', 'LOAA850315AB', 41, 'Culiacan', '80000'),
('Jorge Díaz', 'sin-correo', '667', NULL, -3, 'Culiacán', '8000');
```

```text
INSERT 0 2
```

El servidor les asignó los `id` 7 y 8. El 6 fue de Pedro Ruiz, el cliente que se dio de alta y de baja en el LAB-01 (Actividad 13), y un `id` ya usado no se vuelve a asignar. Con estos dos, la tabla tiene 7 clientes.

### 2. Verificaciones de la guía

#### Posibles duplicados por correo

```sql
SELECT lower(correo) AS correo_normalizado, count(*) AS registros, string_agg(id::text, ', ') AS ids FROM clientes GROUP BY lower(correo) HAVING count(*) > 1;
```

```text
   correo_normalizado   | registros | ids
------------------------+-----------+------
 ana.lopez@example.test |         2 | 1, 7
(1 row)
```

El registro 7 se capturó con el correo en mayúsculas. Escrito así no es igual al del cliente 1, pero `lower()` pasa los dos a minúsculas y resultan el mismo correo. Puede ser la misma persona dada de alta dos veces.

#### RFC con formato no válido o ausente

```sql
SELECT id, nombre, rfc FROM clientes WHERE rfc IS NULL OR rfc !~ '^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$';
```

```text
 id |   nombre   |     rfc
----+------------+--------------
  7 | Ana Lopez  | LOAA850315AB
  8 | Jorge Díaz |
(2 rows)
```

El RFC del 7 tiene 12 caracteres: cuatro letras, seis dígitos y dos caracteres más. El patrón pide tres al final, así que le falta uno. El 8 no tiene RFC. La expresión regular solo revisa el formato: no comprueba que el RFC exista ni sustituye las reglas del SAT.

#### Correo con formato no válido

```sql
SELECT id, nombre, correo FROM clientes WHERE correo !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$';
```

```text
 id |   nombre   |   correo
----+------------+------------
  8 | Jorge Díaz | sin-correo
(1 row)
```

`sin-correo` no tiene `@` ni dominio: es un texto de relleno en lugar del correo.

#### Edad fuera de rango

```sql
SELECT id, nombre, edad FROM clientes WHERE edad IS NOT NULL AND (edad < 18 OR edad > 120);
```

```text
 id |   nombre   | edad
----+------------+------
  8 | Jorge Díaz |   -3
(1 row)
```

Una edad negativa es imposible. El rango de 18 a 120 años es la regla que usa la guía.

#### Completitud

```sql
SELECT count(*) AS total, count(*) FILTER (WHERE telefono IS NULL) AS sin_telefono, count(*) FILTER (WHERE rfc IS NULL) AS sin_rfc FROM clientes;
```

```text
 total | sin_telefono | sin_rfc
-------+--------------+---------
     7 |            0 |       1
(1 row)
```

Ningún cliente tiene el teléfono vacío y uno no tiene RFC, el 8. Que un campo esté lleno no significa que el dato sirva: el teléfono del 8 tiene tres dígitos, como muestra la siguiente consulta.

### 3. Verificaciones agregadas

No vienen en la guía. Se agregaron porque el `INSERT` trae también un teléfono, un código postal y una ciudad con errores, y ninguna de las consultas anteriores los detecta.

```sql
SELECT id, nombre, telefono, codigo_postal FROM clientes WHERE telefono !~ '^[0-9]{10}$' OR codigo_postal !~ '^[0-9]{5}$';
```

```text
 id |   nombre   | telefono | codigo_postal
----+------------+----------+---------------
  8 | Jorge Díaz | 667      | 8000
(1 row)
```

Un teléfono en México tiene 10 dígitos y un código postal tiene 5.

```sql
SELECT ciudad, count(*) AS registros FROM clientes GROUP BY ciudad ORDER BY ciudad;
```

```text
   ciudad   | registros
------------+-----------
 Culiacan   |         1
 Culiacán   |         4
 Los Mochis |         1
 Mazatlán   |         1
(4 rows)
```

`Culiacan` y `Culiacán` son la misma ciudad escrita de dos formas, y un reporte por ciudad las contaría por separado. Según el `INSERT`, el registro sin acento es el 7.

### 4. Hallazgos

| # | Hallazgo | Registros | Regla de calidad | ¿Quién decide la corrección? | Acción propuesta |
| --- | --- | --- | --- | --- | --- |
| C1 | Posible cliente duplicado | 1, 7 | Unicidad del correo | Gerencia Comercial | Confirmar con el cliente si es la misma persona; si lo es, la Gerencia decide qué registro se conserva |
| C2 | RFC incompleto | 7 | Formato del RFC | Gerencia Comercial | Pedir al cliente su RFC completo |
| C3 | RFC ausente | 8 | Completitud del RFC | Gerencia Comercial | Pedir el RFC si el cliente factura; si no, decidir si puede quedar vacío |
| C4 | Correo no válido | 8 | Formato del correo | Gerencia Comercial | Pedir un correo válido |
| C5 | Edad fuera de rango | 8 | Edad entre 18 y 120 años | Gerencia Comercial | Pedir la edad correcta y, mientras, dejar el registro fuera de la analítica |
| C6 | Teléfono incompleto | 8 | Teléfono de 10 dígitos (agregada) | Gerencia Comercial | Pedir el número completo |
| C7 | Código postal incompleto | 8 | Código postal de 5 dígitos (agregada) | Gerencia Comercial | Confirmar el código con el cliente |
| C8 | Ciudad escrita de dos formas | 7 | Un solo nombre válido por ciudad (agregada) | Gerencia Comercial | Definir la lista de ciudades válidas y corregir el 7 cuando se apruebe |

En todos decide la Gerencia Comercial porque es la propietaria de los datos de clientes (sección 4.2 de la guía). El valor correcto lo da el cliente; el DBA, que es el custodio, no lo deduce.

### 5. Escalamiento

El DBA no corrige ni borra estos registros. Los reporta a la Gerencia Comercial con la tabla anterior, y cada corrección que ella apruebe se hace con una solicitud de cambio (Actividad 7) y con la auditoría encendida, para que quede registrada. Los registros 7 y 8 se conservan sin cambios, como pide la guía, porque forman parte de los hallazgos del expediente.

## Preguntas

**1. ¿Por qué el DBA no debe corregir por su cuenta el RFC del registro 7?**

Porque el DBA es custodio del dato, no propietario: lo opera y lo protege, pero no decide su valor. Sabe que al RFC le falta un carácter, pero no sabe cuál. Si lo adivina, cambia un error visible por uno que pasa la verificación de formato y llega a las facturas. El valor correcto tiene que venir del cliente, a través de la Gerencia Comercial. Además, un cambio sin solicitud es justo lo que la unidad busca detectar: en el LAB-01, el RFC de María García cambió y no quedó registro de quién lo cambió ni por qué.

**2. ¿Qué restricción (CHECK, UNIQUE) habría evitado cada hallazgo? ¿Quién debería aprobar agregarla?**

| Hallazgo | Restricción |
| --- | --- |
| C1 | Un índice único sobre `lower(correo)`. Un `UNIQUE` sobre `correo` no basta, porque los dos correos difieren en las mayúsculas |
| C2 | `CHECK (rfc ~ '^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$')` |
| C3 | `NOT NULL` en `rfc`, solo si la Gerencia decide que todo cliente debe tenerlo. El `CHECK` de C2 no lo evita, porque un `CHECK` que da nulo se considera cumplido |
| C4 | `CHECK (correo ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')` |
| C5 | `CHECK (edad BETWEEN 18 AND 120)` |
| C6 | `CHECK (telefono ~ '^[0-9]{10}$')` |
| C7 | `CHECK (codigo_postal ~ '^[0-9]{5}$')` |
| C8 | Ni `CHECK` ni `UNIQUE`: haría falta una tabla de ciudades válidas y una llave foránea hacia ella |

La regla de negocio la fija la Gerencia Comercial, como propietaria; por ejemplo, si el RFC es obligatorio o si se aceptan clientes menores de edad. Agregar la restricción es un cambio en producción, así que necesita una solicitud aprobada por el comité de cambios (Actividad 7) y la ejecuta el DBA. Antes hay que resolver estos hallazgos: al agregar un `CHECK`, PostgreSQL revisa las filas que ya existen y rechaza la restricción si alguna no la cumple, y el índice único no se puede crear mientras haya duplicados.

**3. Si el DBA corrige un dato, ¿qué mecanismo del LAB-01 (Parte B) dejará evidencia del cambio?**

El disparador `trg_auditoria_clientes`. Se ejecuta después de cada `INSERT`, `UPDATE` o `DELETE` sobre `clientes` y guarda un renglón en `auditoria.cambios_clientes` con el usuario de la sesión, el momento, la aplicación, la IP, la operación, el `id` del cliente y la fila antes y después del cambio. Ahí se vería que fue el DBA, cuándo, y qué RFC había antes. Además, con `log_statement = 'mod'`, el `UPDATE` queda en la bitácora (Parte A).

El disparador tiene dos límites. No registra quién autorizó la corrección ni por qué; eso lo tiene que aportar la solicitud de cambio. Y el administrador lo puede apagar y volver a encender sin que la tabla de auditoría lo note, como se vio en la Actividad 14 del LAB-01. Que esté encendido se comprueba en la evidencia E3 (Actividad 8).

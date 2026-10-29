# Evidencia 06 — Cambios de privilegios y de estructura

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Script: [`sql/03-privilegios-estructura.sql`](../sql/03-privilegios-estructura.sql)
- Fecha: 29 de octubre de 2026

## Objetivo

Comprobar que, con `log_statement = 'ddl'`, la bitácora registra los cambios de privilegios y de estructura con su autor, y ver qué pasa cuando una sentencia lleva una contraseña escrita.

## Pasos y resultados

### 1. Privilegios y estructura

En la sesión de administrador:

```sql
REVOKE UPDATE ON clientes FROM soporte_ana;
GRANT UPDATE ON clientes TO app_ventas;
ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);
```

```text
REVOKE
GRANT
ALTER TABLE
```

Ninguna dio error, aunque `soporte_ana` no tenía UPDATE y `app_ventas` ya lo tenía desde la sección 6.5. Como explica la guía, una revisión periódica de privilegios suele aplicar revocaciones preventivas como esta, y también deben quedar registradas.

### 2. Un rol con la contraseña escrita (sección 12.1)

Las sentencias de la guía:

```sql
CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
DROP ROLE rol_temporal;
```

El `DROP ROLE` se ejecutó primero por error, antes de crear el rol:

```text
ERROR:  role "rol_temporal" does not exist
```

Después se ejecutaron las dos en orden, desde un archivo temporal (`\i /tmp/rol-temporal.sql`, borrado al terminar):

```text
CREATE ROLE
DROP ROLE
```

En esta evidencia, la contraseña de práctica de la guía aparece como `<REDACTED>`, porque el repositorio es público. En la bitácora del servidor quedó completa.

### 3. Las sentencias en la bitácora

```sql
SELECT linea FROM dba.bitacora WHERE linea LIKE '%statement:%' ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
 2026-10-29 11:20:18.913 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: REVOKE UPDATE ON clientes FROM soporte_ana;
 2026-10-29 11:20:18.918 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: GRANT UPDATE ON clientes TO app_ventas;
 2026-10-29 11:20:18.920 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);
 2026-10-29 11:20:25.157 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: DROP ROLE rol_temporal;
 2026-10-29 11:23:43.107 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
 2026-10-29 11:23:43.114 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: DROP ROLE rol_temporal;
(6 rows)
```

- Las seis líneas son de la misma sesión: el proceso 227, el usuario `postgres`, la base `comercial`, la aplicación `psql` y el cliente `[local]`, que es el socket del contenedor. Es la sesión de administrador que se abrió para la Actividad 5.
- Cada sentencia aparece completa, tal como se escribió, con todo y punto y coma. La guía las muestra sin él.
- La guía muestra cinco líneas. Aquí hay seis por el `DROP ROLE` que falló (paso 4).
- La contraseña quedó en texto claro, y borrar el rol no la borra de la bitácora.

### 4. La historia de `rol_temporal`

Para ver todo lo que la bitácora registró sobre el rol, se buscó su nombre:

```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%rol_temporal%' ORDER BY num;
```

```text
  36 | 2026-10-29 11:20:25.157 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: DROP ROLE rol_temporal;
  37 | 2026-10-29 11:20:25.157 MST [227] user=postgres db=comercial app=psql client=[local] ERROR:  role "rol_temporal" does not exist
  38 | 2026-10-29 11:20:25.157 MST [227] user=postgres db=comercial app=psql client=[local] STATEMENT:  DROP ROLE rol_temporal;
  41 | 2026-10-29 11:23:43.107 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
  42 | 2026-10-29 11:23:43.114 MST [227] user=postgres db=comercial app=psql client=[local] LOG:  statement: DROP ROLE rol_temporal;
(5 rows)
```

- **Líneas 36 a 38.** El `DROP ROLE` que falló dejó tres líneas. La 36 es la sentencia, que se registra al recibirla, antes de ejecutarla, así que queda aunque después falle. La 37 es el error, y la 38 repite la sentencia que lo causó, porque `log_min_error_statement` vale `error` por defecto. Los errores se revisan en la Actividad 8.
- **Líneas 39 y 40.** No mencionan el rol: son un checkpoint de las 11:22:56.
- **Líneas 41 y 42.** La creación, con la contraseña, y el borrado. El rol existió 7 milisegundos, y su contraseña se queda en la bitácora.

Buscar el nombre de un objeto da su historia completa y en orden: qué se intentó, qué falló y qué se hizo.

## Análisis

**¿Qué tipo de evento es cada una de las tres primeras sentencias (privilegio o estructura)?**

| Sentencia | Tipo de evento | Qué cambia |
| --- | --- | --- |
| `REVOKE UPDATE ON clientes FROM soporte_ana` | Privilegio | Le quita a `soporte_ana` el permiso de modificar `clientes` (aquí no lo tenía) |
| `GRANT UPDATE ON clientes TO app_ventas` | Privilegio | Le da a `app_ventas` el permiso de modificar `clientes` (aquí ya lo tenía) |
| `ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20)` | Estructura | Agrega la columna `segmento` a la tabla |

Las dos primeras cambian quién puede hacer qué, y la tercera cambia la tabla misma. Las de la sección 12.1, `CREATE ROLE` y `DROP ROLE`, crean y eliminan una cuenta, así que también cambian quién puede entrar al servidor.

**¿Por qué GRANT y REVOKE quedan registrados con `log_statement = 'ddl'`?** Porque `log_statement` solo tiene cuatro niveles (`none`, `ddl`, `mod` y `all`), y PostgreSQL cuenta GRANT y REVOKE entre las sentencias de definición, junto con CREATE, ALTER y DROP. No tocan los datos de la tabla: cambian el catálogo del sistema, donde se guardan los permisos de cada objeto. En la teoría se les suele llamar DCL (lenguaje de control de datos), pero `log_statement` no tiene un nivel aparte para ellas.

Para la auditoría es una ventaja: `ddl` es el nivel más bajo que registra los cambios de permisos, sin registrar cada consulta ni cada cambio de datos. Es justo lo que faltaba en la Actividad 3, donde un GRANT seguido de un REVOKE no habría dejado rastro. Ahora quedarían los dos, con quién los ejecutó y desde dónde.

**Si la bitácora contiene contraseñas, ¿quién debería poder leerla? Relaciónalo con la gestión de secretos de la Unidad II.** Solo quien la necesita para su trabajo, que son el administrador del servidor y el auditor. Una bitácora que guarda contraseñas es tan sensible como las contraseñas mismas. En este servidor ya está restringida de dos formas: el archivo pertenece al usuario `postgres` del contenedor, con permisos `-rw-------`, y para leer la vista `dba.bitacora` hace falta ser superusuario o recibir dos permisos explícitos (evidencia 02). Pero la bitácora también sale del servidor: en respaldos, en exportaciones como la de la Actividad 16, que sustituye esta contraseña por `<REDACTED>`, o en herramientas de monitoreo. Cada copia tiene que protegerse igual.

Es lo mismo que pasó en el LAB-02 de la Unidad II con la clave de cifrado ([evidencia 03](../../../unidad-02/laboratorio-02-cifrado-credenciales/evidencias/03-gestion-claves.md)): la consulta que falló con la clave incorrecta quedó completa en el log del servidor, y la clave también quedó en el historial de `psql`. Por eso la política de claves de ese laboratorio ([evidencia 10](../../../unidad-02/laboratorio-02-cifrado-credenciales/evidencias/10-politica-claves.md)) pide proteger el historial y los logs del servidor como información sensible (regla 4) y dar por comprometido cualquier secreto real que aparezca en un log, aunque después se borre (regla 8). Aplicado aquí, una contraseña real que llegara a la bitácora tendría que cambiarse. La regla 3 agrega otro punto: administrar la base no debe dar acceso a las claves. Si las contraseñas llegan a la bitácora, cualquier administrador que la lea las conoce.

Lo mejor es que la contraseña nunca llegue a la bitácora. Por eso en la sección 6.5 se usó `\password`, que calcula el resumen SCRAM en el cliente y solo envía ese resumen. Aun así, el resumen tampoco debería quedar a la vista: no permite entrar directamente, pero sirve para intentar adivinar la contraseña probando valores fuera del servidor.

## Conclusión

Con `ddl`, la bitácora ya registra quién cambió permisos, estructura o cuentas, cuándo y desde dónde, con el texto exacto de cada sentencia, incluso de las que fallan. Pero ese texto exacto también guarda los secretos que se escriban en él: la contraseña de `rol_temporal` sigue en la bitácora aunque el rol ya no exista. Por eso la bitácora debe protegerse como información sensible, y las contraseñas deben asignarse de forma que no lleguen a ella, como con `\password`.

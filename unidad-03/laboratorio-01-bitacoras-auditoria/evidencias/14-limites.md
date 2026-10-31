# Evidencia 14 — Límites: lecturas y volumen

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 15 (sección 21 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 31 de octubre de 2026

## Objetivo

Ver dos límites de lo que se configuró: qué deja una lectura de datos sensibles y qué deja un cambio masivo, en la bitácora y en la auditoría.

## Pasos y resultados

Los números de línea son los del archivo de bitácora del 31 de octubre ([evidencia 11](11-incidente-auditado.md)).

### 1. Una lectura de datos sensibles

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://soporte_ana@127.0.0.1/comercial" -c "SELECT nombre, rfc, telefono FROM clientes WHERE id = 3"
```

```text
Password:
    nombre    |      rfc      |  telefono
--------------+---------------+------------
 María García | GAMA780912GHI | 6679990000
(1 row)
```

### 2. Un cambio masivo y los conteos

```sql
UPDATE clientes SET segmento = 'regular';
SELECT count(*) AS lineas_bitacora FROM dba.bitacora
WHERE linea LIKE '%statement: UPDATE clientes SET segmento%';
SELECT operacion, count(*) FROM auditoria.cambios_clientes GROUP BY operacion ORDER BY operacion;
SELECT count(*) AS lecturas_soporte FROM dba.bitacora
WHERE linea LIKE '%user=soporte_ana%SELECT nombre, rfc%';
```

```text
UPDATE 5
 lineas_bitacora
-----------------
               1
(1 row)

 operacion | count
-----------+-------
 DELETE    |     1
 INSERT    |     1
 UPDATE    |     6
(3 rows)

 lecturas_soporte
------------------
                0
(1 row)
```

- Una sola sentencia dejó una línea en la bitácora (la 55) y cinco registros en la auditoría, los eventos 4 a 8, uno por cliente. Por eso `UPDATE` pasó de 1 a 6.
- La lectura del paso 1 no aparece: no existe disparador para `SELECT`, y `mod` no registra consultas.

### 3. Lo único que dejó la lectura

```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%user=soporte_ana%' ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
  50 | 2026-10-31 10:07:37.088 MST [197] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="soporte_ana" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
  51 | 2026-10-31 10:07:37.088 MST [197] user=soporte_ana db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=soporte_ana database=comercial application_name=psql
  52 | 2026-10-31 10:07:37.090 MST [197] user=soporte_ana db=comercial app=psql client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.006 user=soporte_ana database=comercial host=127.0.0.1 port=58792
(3 rows)
```

Se sabe que `soporte_ana` se conectó a las 10:07:37 y que su sesión duró 6 milisegundos, pero no qué consultó. La línea 49 (`connection received`) no sale porque en ese momento todavía no se conocía al usuario.

### 4. El historial del RFC dentro de la auditoría

```sql
SELECT id_evento, operacion, valores_antes ->> 'rfc' AS rfc_antes, valores_despues ->> 'rfc' AS rfc_despues
FROM auditoria.cambios_clientes WHERE id_cliente = 3 ORDER BY id_evento;
```

```text
 id_evento | operacion |   rfc_antes   |  rfc_despues
-----------+-----------+---------------+---------------
         1 | UPDATE    | GAMA780912XYZ | GAMA780912ZZZ
         8 | UPDATE    | GAMA780912GHI | GAMA780912GHI
(2 rows)
```

El evento 8 es el cambio masivo al llegar a María García, y no le cambió el RFC. Pero su `rfc_antes` es `GAMA780912GHI`, y el evento 1 había terminado en `GAMA780912ZZZ`. Como cada registro guarda la fila completa, el siguiente cambio deja a la vista que entre los eventos 1 y 8 el RFC cambió sin dejar registro ([evidencia 13](13-manipulacion.md)).

## Análisis

**Cómo se podrían registrar las lecturas**

| Alternativa | Ventaja | Desventaja |
| --- | --- | --- |
| `log_statement = 'all'` | No requiere instalar nada | Registra todas las consultas de todas las tablas |
| Entregar el dato solo mediante una función que registre su uso | Control preciso | Requiere cambiar la aplicación |
| pgaudit con auditoría de objeto (Parte C de la guía, no realizada) | Registra lecturas por tabla y por columna | Requiere instalar una extensión |

**Si `clientes` tuviera un millón de registros, ¿qué ocurriría con la auditoría tras un UPDATE sin WHERE?**

La bitácora seguiría con una línea, y la auditoría recibiría un millón de registros, porque el disparador es `FOR EACH ROW`: se ejecuta una vez por fila.

Cada registro guarda dos copias de la fila. La de Pedro Ruiz mide 217 caracteres ([evidencia 12](12-altas-bajas.md)), así que, con las demás columnas, un registro ronda los 600 bytes. Con un millón serían unos 600 MB, más su índice, por una sola sentencia. Es un cálculo aproximado, y tiene estas consecuencias:

- **Tiempo.** Cada fila hace además un `INSERT`, así que el `UPDATE` tarda más, y como todo va en una sola transacción, retiene sus bloqueos hasta terminar.
- **Espacio.** Crecen la tabla, los respaldos y los archivos de recuperación. Si el disco se llena, las escrituras fallan y el servidor puede detenerse.
- **Investigación.** Un millón de registros casi iguales pueden enterrar el evento que importa.
- **Privacidad.** Son un millón de copias más del RFC y del teléfono de los clientes.

Apagar el disparador durante el cambio masivo evita el costo, pero deja el mismo hueco de la [evidencia 13](13-manipulacion.md), así que tendría que ser un mantenimiento autorizado y documentado.

**Propón quién podría autorizar la depuración de `auditoria.cambios_clientes`.**

No el DBA por sí solo, porque la tabla también registra sus propios cambios. Siguiendo la [matriz de gobierno de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md):

| Papel | Quién | Qué hace |
| --- | --- | --- |
| Aprueba la política | Dirección | Aprueba el plazo de conservación de la auditoría |
| Autoriza cada depuración | Responsable de privacidad, con el área jurídica | Confirma que el plazo venció y que ninguna investigación o reclamación pendiente necesita esos registros |
| Ejecuta | DBA | Borra solo el rango autorizado |
| Revisa | Alguien distinto del DBA, como auditoría interna | Comprueba que se borró solo ese rango |

Cada depuración debe dejar constancia, fuera de esa tabla, de la fecha, el rango de `id_evento`, cuántos renglones, quién autorizó y quién ejecutó, sin copiar los datos borrados.

**¿Por qué `log_statement = 'all'` puede convertir la bitácora en un nuevo depósito de datos sensibles?**

Porque la bitácora guarda el texto de cada sentencia, con los valores que lleva. Ya pasa con `mod`: la línea 28 tiene el nombre, el correo y el RFC de Pedro Ruiz ([evidencia 12](12-altas-bajas.md)), y la contraseña del `CREATE ROLE` de la [evidencia 06](06-privilegios-estructura.md) también quedó ahí. Con `all` se sumarían todas las consultas: un `SELECT` con `WHERE rfc = '...'` dejaría el RFC buscado, y quedaría el historial de qué usuario consultó a qué cliente. No guardaría el resultado de la consulta, pero sí todo lo que se escriba en ella.

Además, esa copia queda menos protegida que el dato original:

- Es un archivo de texto: no le aplican los permisos por tabla o por columna, las vistas ni el enmascaramiento de la Unidad II.
- Se copia a respaldos, a sistemas externos y a exportaciones como la de la Actividad 16.
- También es un tratamiento de datos (LFPDPPP, art. 2, fr. XIX), así que necesita su propio plazo de conservación, como ya señalaba la [arquitectura del LAB-03](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/15-arquitectura.md).

**Otro límite: lo que se deshace**

Una sentencia que se deshace con `ROLLBACK` sí queda en la bitácora, porque se registra antes de ejecutarse, pero su registro de auditoría desaparece con la transacción. Como la secuencia de `id_evento` no retrocede, queda un hueco en la numeración. Por eso un hueco en `id_evento` no prueba por sí solo que alguien borró registros.

## Conclusión

La bitácora y la auditoría cubren cosas distintas, y las dos tienen límites. La lectura de datos sensibles solo dejó una conexión de 6 milisegundos: no se sabe qué leyó Ana. Un solo `UPDATE` dejó una línea en la bitácora y un registro por fila en la auditoría, y con un millón de filas serían cientos de megabytes. Registrar más no es gratis: ocupa espacio y crea copias de los datos que hay que proteger y depurar. Por eso qué registrar, cuánto conservar y quién depura se tiene que decidir en una política, no solo en la configuración.

## Referencias

- Guía del LAB-01 de la Unidad III, sección 21.
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículo 2, fracción XIX. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf

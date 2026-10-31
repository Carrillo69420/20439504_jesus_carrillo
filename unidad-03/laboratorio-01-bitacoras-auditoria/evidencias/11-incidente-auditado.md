# Evidencia 11 — El incidente auditado

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 12 (sección 18 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 31 de octubre de 2026

## Objetivo

Repetir el cambio de RFC de María García con el disparador activo y comprobar que ahora sí se puede saber quién lo hizo, cuándo, desde dónde, qué campo cambió y qué valor tenía antes. También, comprobar que la aplicación no puede leer su propia auditoría.

## Pasos y resultados

El servidor se detuvo el 29 de octubre y se volvió a arrancar el 31 a las 09:42:51. Al arrancar, PostgreSQL abrió un archivo de bitácora nuevo, `postgresql-2026-10-31_094251.log`, y la vista `dba.bitacora` solo lee el archivo vigente. Los números de línea de esta evidencia son los de ese archivo, que empieza otra vez en 1. El archivo del 29 de octubre sigue en la misma carpeta y se exporta en la Actividad 16. En esa exportación van primero las 181 líneas del 29 de octubre, así que ahí cada línea de esta evidencia lleva su número más 181 ([evidencia 15](15-cronologia.md)).

### 1. La aplicación cambia el RFC

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://app_ventas@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET rfc = 'GAMA780912ZZZ' WHERE id = 3"
```

```text
Password:
UPDATE 1
```

Es el mismo tipo de cambio de las Actividades 3 y 7, con la misma cuenta. La diferencia es que ahora está activo el disparador de la Actividad 11.

### 2. La aplicación intenta leer la auditoría

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://app_ventas@127.0.0.1/comercial" -c "SELECT * FROM auditoria.cambios_clientes"
```

```text
Password:
ERROR:  permission denied for schema auditoria
LINE 1: SELECT * FROM auditoria.cambios_clientes
                      ^
```

`app_ventas` no tiene ningún privilegio sobre el esquema `auditoria`, así que ni siquiera llega a la tabla. A diferencia del paso 1, esta conexión no declara `application_name`; esa diferencia se usa en el análisis.

### 3. El registro de auditoría

En la sesión de administrador. `\x` presenta cada columna en su propio renglón, y repetirlo lo desactiva:

```sql
\x
SELECT id_evento, momento, usuario_sesion, usuario_efectivo, aplicacion, ip_cliente, operacion, id_cliente
FROM auditoria.cambios_clientes ORDER BY id_evento;
\x
```

```text
-[ RECORD 1 ]----+------------------------------
id_evento        | 1
momento          | 2026-10-31 09:50:08.326789-07
usuario_sesion   | app_ventas
usuario_efectivo | postgres
aplicacion       | app-ventas-web
ip_cliente       | 127.0.0.1
operacion        | UPDATE
id_cliente       | 3
```

- `usuario_sesion` es `app_ventas`, la cuenta que se conectó y se autenticó. Esta es la columna que responde quién.
- `usuario_efectivo` es `postgres` porque dentro de una función `SECURITY DEFINER`, `current_user` es el dueño de la función. Si la auditoría guardara solo ese dato, todos los cambios parecerían hechos por `postgres`.
- `id_evento` es 1 porque es el primer cambio en `clientes` desde que se creó el disparador.
- `momento` termina en `-07` porque el servidor usa la hora del Pacífico de México (`TZ=America/Mazatlan`).

### 4. Qué campo cambió

La consulta está en [sql/06-campos-modificados.sql](../sql/06-campos-modificados.sql):

```sql
SELECT a.id_evento, a.momento, a.usuario_sesion, a.ip_cliente,
       d.key                     AS campo,
       a.valores_antes ->> d.key AS antes,
       d.value #>> '{}'          AS despues
FROM auditoria.cambios_clientes a
CROSS JOIN LATERAL jsonb_each(a.valores_despues) d
WHERE a.operacion = 'UPDATE'
  AND a.valores_antes -> d.key IS DISTINCT FROM d.value
ORDER BY a.id_evento;
```

```text
 id_evento |            momento            | usuario_sesion | ip_cliente | campo |     antes     |    despues
-----------+-------------------------------+----------------+------------+-------+---------------+---------------
         1 | 2026-10-31 09:50:08.326789-07 | app_ventas     | 127.0.0.1  | rfc   | GAMA780912XYZ | GAMA780912ZZZ
(1 row)
```

| Parte | Qué hace |
| --- | --- |
| `jsonb_each(a.valores_despues)` | Convierte el documento en filas, una por campo, con las columnas `key` y `value` |
| `CROSS JOIN LATERAL` | Aplica esa función a cada registro de auditoría |
| `->` | Saca un campo como JSON; el `WHERE` lo usa para comparar JSON contra JSON |
| `->>` y `#>> '{}'` | Sacan el valor como texto, sin las comillas de JSON |
| `IS DISTINCT FROM` | Compara sin perder la fila cuando uno de los lados es nulo |

Cada registro guarda al cliente completo antes y después del cambio. La consulta compara los dos campo por campo y solo deja el que cambió. Aquí aparece lo que la bitácora no tenía en la Actividad 7: el valor anterior.

### 5. Lo que dejó `app_ventas` en la bitácora

```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%user=app_ventas%' ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
  13 | 2026-10-31 09:50:08.325 MST [85] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="app_ventas" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
  14 | 2026-10-31 09:50:08.325 MST [85] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=app_ventas database=comercial application_name=app-ventas-web
  15 | 2026-10-31 09:50:08.326 MST [85] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: UPDATE clientes SET rfc = 'GAMA780912ZZZ' WHERE id = 3
  16 | 2026-10-31 09:50:08.341 MST [85] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.022 user=app_ventas database=comercial host=127.0.0.1 port=54454
  20 | 2026-10-31 09:53:37.269 MST [111] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="app_ventas" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
  21 | 2026-10-31 09:53:37.269 MST [111] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=app_ventas database=comercial application_name=psql
  22 | 2026-10-31 09:53:37.271 MST [111] user=app_ventas db=comercial app=psql client=127.0.0.1 ERROR:  permission denied for schema auditoria at character 15
  23 | 2026-10-31 09:53:37.271 MST [111] user=app_ventas db=comercial app=psql client=127.0.0.1 STATEMENT:  SELECT * FROM auditoria.cambios_clientes
  24 | 2026-10-31 09:53:37.271 MST [111] user=app_ventas db=comercial app=psql client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.006 user=app_ventas database=comercial host=127.0.0.1 port=57768
(9 rows)
```

| Líneas | Qué son |
| --- | --- |
| 13 y 14 | La conexión del paso 1, autenticada con `scram-sha-256`, con `application_name=app-ventas-web` |
| 15 | El UPDATE, con la sentencia completa |
| 16 | La desconexión, 22 milisegundos después de conectarse |
| 20 y 21 | La conexión del paso 2, ahora con `application_name=psql` |
| 22 y 23 | El intento rechazado: el error y la sentencia que lo provocó |
| 24 | La desconexión |

Las líneas 12 y 19 (`connection received`) no salen porque en ese momento todavía no se conoce al usuario: dicen `user=[unknown]`.

Las dos fuentes se escriben por separado y coinciden en lo que tienen en común, hasta en el milisegundo. Cada una tiene algo que a la otra le falta:

| Qué se quiere saber | Bitácora | Auditoría |
| --- | --- | --- |
| Quién | `user=app_ventas` | `usuario_sesion` |
| Cuándo | 09:50:08.326 | 09:50:08.326789 |
| Desde dónde | `client=127.0.0.1` | `ip_cliente` |
| Con qué aplicación | `app=app-ventas-web` | `aplicacion` |
| Qué sentencia se pidió | Sí, completa (línea 15) | No |
| Qué valor había antes | No | Sí, en `valores_antes` |
| El intento de leer la auditoría | Sí (líneas 22 y 23) | No, solo registra cambios en `clientes` |

## Análisis

**Compara la hipótesis de la Actividad 11 con este resultado.**

La hipótesis ([evidencia 10](10-diseno-auditoria.md), segunda parte) decía dos cosas:

1. **Con `SECURITY DEFINER`, `usuario_efectivo` diría `postgres` aunque el cambio lo hiciera `app_ventas`.** Se cumplió: el registro dice `usuario_sesion = app_ventas` y `usuario_efectivo = postgres`.
2. **Sin `SECURITY DEFINER`, el `UPDATE` de `app_ventas` fallaría completo.** Los pasos 1 y 2 la respaldan: `app_ventas` no puede entrar por su cuenta al esquema `auditoria`, y aun así su `UPDATE` dejó un registro ahí, porque quien escribió fue la función con los privilegios de su dueño. Con `SECURITY INVOKER`, la función escribe con los privilegios de `app_ventas`: el `UPDATE` responde `permission denied for schema auditoria` y el RFC no cambia. La función de este servidor no se modificó para mostrarlo.

**Escribe la sentencia UPDATE que restauraría el valor anterior.**

```sql
UPDATE clientes SET rfc = 'GAMA780912XYZ' WHERE id = 3;
```

El valor sale de la columna `antes` del paso 4. Antes de ejecutarla habría que confirmar que el RFC actual sigue siendo `GAMA780912ZZZ`; con `AND rfc = 'GAMA780912ZZZ'` en el `WHERE`, la sentencia no pisaría un cambio posterior. La restauración también queda auditada, como cualquier otro cambio, con el usuario que la ejecute. No se ejecutó, porque la secuencia de cambios del laboratorio continúa en la Actividad 14.

**¿Qué columna conserva más valor para una investigación: `aplicacion` o `ip_cliente`? ¿Cuál puede falsificar el cliente con más facilidad?**

`ip_cliente` conserva más valor, porque la toma el servidor de la conexión de red (`inet_client_addr()`), mientras que `aplicacion` es lo que el cliente dice de sí mismo. Esta misma actividad lo muestra: `app_ventas`, desde la misma dirección, aparece con `application_name=app-ventas-web` en la línea 14 y con `application_name=psql` en la línea 21, y lo único que cambió fue el texto de la cadena de conexión. Cualquiera que tenga la contraseña puede declararse `app-ventas-web`; de hecho, el paso 1 se hizo desde `psql`, no desde una aplicación de ventas. Por eso `aplicacion` es la más fácil de falsificar: sirve para distinguir aplicaciones legítimas, pero no es evidencia de identidad.

`ip_cliente` también tiene límites:

- Identifica una máquina, no a una persona.
- Aquí dice `127.0.0.1` porque la conexión nace dentro del contenedor. Si hubiera un intermediario, como un balanceador o un pool de conexiones, mostraría la dirección del intermediario.
- Queda vacía en las conexiones por socket local (Actividad 13).

Tampoco `usuario_sesion` dice quién estaba detrás: `app_ventas` es una cuenta de toda la aplicación. Para saber qué persona hizo el cambio habría que cruzar este registro con los de la propia aplicación.

## Conclusión

Con el disparador, el cambio de RFC ya no es un hueco como en la Actividad 3: `app_ventas` cambió el RFC del cliente 3 de `GAMA780912XYZ` a `GAMA780912ZZZ` el 31 de octubre a las 09:50:08, desde `127.0.0.1`, y se puede revertir sin buscar en un respaldo. La aplicación no puede leer ese registro, y su intento de hacerlo quedó en la bitácora. La auditoría y la bitácora se complementan: solo la auditoría tiene el valor anterior, y solo la bitácora tiene la sentencia y los intentos rechazados. Lo que ninguna de las dos resuelve es qué persona estaba detrás de la cuenta `app_ventas`.

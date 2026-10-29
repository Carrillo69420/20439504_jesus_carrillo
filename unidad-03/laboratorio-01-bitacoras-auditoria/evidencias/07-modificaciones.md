# Evidencia 07 — Modificaciones de datos: ddl frente a mod

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 7 (sección 13 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 29 de octubre de 2026

## Objetivo

Comparar lo que registra la bitácora cuando `app_ventas` modifica un dato con `log_statement = 'ddl'` y con `log_statement = 'mod'`, y ver qué le sigue faltando para poder revertir un cambio.

## Pasos y resultados

### 1. Los primeros intentos: contraseña rechazada

Los primeros cuatro intentos de conectarse como `app_ventas` fallaron:

| Hora | Líneas de la bitácora | Qué se intentó | Nivel en ese momento |
| --- | --- | --- | --- |
| 11:33:22 | 46 a 48 | UPDATE del RFC | `ddl` |
| 11:34:05 | 55 a 57 | UPDATE del teléfono y SELECT | `mod` |
| 11:39:45 | 64 a 66 | UPDATE del RFC | `ddl` |
| 11:43:22 | 67 a 69 | UPDATE del RFC | `ddl` |

En los cuatro, el servidor rechazó la contraseña, así que ninguna sentencia se ejecutó y ni el RFC ni el teléfono cambiaron. Cada intento dejó tres líneas: `connection received`, `FATAL: password authentication failed for user "app_ventas"` y el DETAIL con la regla 119 de `pg_hba.conf`, igual que el intento con contraseña incorrecta de la Actividad 5 ([evidencia 05](05-accesos.md)).

La contraseña que se tecleaba no era la que se le había asignado a `app_ventas` en la sección 6.5. Se le asignó una contraseña nueva, en la sesión de administrador:

```text
comercial=# \password app_ventas
Enter new password for user "app_ventas":
Enter it again:
```

La bitácora lo registró en la línea 72:

```text
2026-10-29 11:49:31.350 MST [484] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER USER app_ventas PASSWORD 'SCRAM-SHA-256$<resumen>'
```

`\password` envía el resumen SCRAM y no la contraseña, así que la contraseña no llegó a la bitácora. El resumen sí quedó, y por eso aquí aparece como `<resumen>`. En la exportación de la Actividad 16 también se tapa, igual que la contraseña de `rol_temporal` ([evidencia 06](06-privilegios-estructura.md)).

Como el primer intento falló cuando ya se había subido el nivel a `mod` (11:33:38), se regresó a `ddl` (11:39:36) para repetir la actividad en orden. Esos dos cambios aparecen en el paso 5.

### 2. El UPDATE del incidente con `ddl`

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://app_ventas@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET rfc = 'GAMA780912XYZ' WHERE id = 3"
```

```text
Password:
UPDATE 1
```

La guía pone la contraseña dentro de la cadena de conexión. Aquí se usó `-W`, que hace que `psql` la pida antes de conectarse: no queda escrita en el comando y no deja el intento sin contraseña que apareció en la Actividad 5.

```sql
SELECT linea FROM dba.bitacora WHERE linea LIKE '%user=app_ventas%' ORDER BY num DESC LIMIT 3;
```

Resultado, sin la fila del encabezado:

```text
 2026-10-29 11:49:46.248 MST [517] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.014 user=app_ventas database=comercial host=127.0.0.1 port=53816
 2026-10-29 11:49:46.239 MST [517] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=app_ventas database=comercial application_name=app-ventas-web
 2026-10-29 11:49:46.239 MST [517] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authenticated: identity="app_ventas" method=scram-sha-256 (/var/lib/postgresql/data/pg_hba.conf:119)
(3 rows)
```

Aparecen la conexión y la desconexión de `app_ventas`, pero no el UPDATE. Con `ddl`, la bitácora dice que `app_ventas` estuvo conectada 14 milisegundos, no qué hizo en ese tiempo.

### 3. Cambio de nivel a `mod`

```sql
ALTER SYSTEM SET log_statement = 'mod';
SELECT pg_reload_conf();
```

```text
ALTER SYSTEM
 pg_reload_conf
----------------
 t
(1 row)
```

### 4. Una modificación y una consulta con `mod`

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://app_ventas@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET telefono = '6679990000' WHERE id = 3" -c "SELECT nombre, rfc FROM clientes WHERE id = 3"
```

```text
Password:
UPDATE 1
    nombre    |      rfc
--------------+---------------
 María García | GAMA780912XYZ
(1 row)
```

Cada `-c` es una sentencia distinta: `psql` las ejecuta en orden, en la misma conexión, y termina. La consulta confirma que el RFC del paso 2 sí cambió, aunque la bitácora no lo registró.

### 5. Lo que registró la bitácora

```sql
SELECT linea FROM dba.bitacora
WHERE linea LIKE '%log_statement%' OR linea LIKE '%user=app_ventas%statement:%'
ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
 2026-10-29 10:53:23.997 MST [1] user= db= app= client= LOG:  parameter "log_statement" changed to "ddl"
 2026-10-29 11:33:38.531 MST [398] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER SYSTEM SET log_statement = 'mod';
 2026-10-29 11:33:38.541 MST [1] user= db= app= client= LOG:  parameter "log_statement" changed to "mod"
 2026-10-29 11:39:36.188 MST [413] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER SYSTEM SET log_statement = 'ddl';
 2026-10-29 11:39:36.194 MST [1] user= db= app= client= LOG:  parameter "log_statement" changed to "ddl"
 2026-10-29 11:51:02.283 MST [524] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER SYSTEM SET log_statement = 'mod';
 2026-10-29 11:51:02.289 MST [1] user= db= app= client= LOG:  parameter "log_statement" changed to "mod"
 2026-10-29 11:51:13.931 MST [543] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: UPDATE clientes SET telefono = '6679990000' WHERE id = 3
(8 rows)
```

| Filas del resultado | Hora | Qué son |
| --- | --- | --- |
| 1 | 10:53:23 | El cambio a `ddl` de la Actividad 4. El `ALTER SYSTEM` de entonces no aparece, porque el nivel todavía era `none` |
| 2 y 3 | 11:33:38 | El primer cambio a `mod`, antes de notar que la contraseña fallaba (paso 1) |
| 4 y 5 | 11:39:36 | El regreso a `ddl` para repetir la actividad |
| 6 y 7 | 11:51:02 | El cambio a `mod` del paso 3 |
| 8 | 11:51:13 | El UPDATE del teléfono |

- La guía muestra cuatro filas, que aquí son la 1, la 6, la 7 y la 8. Las otras cuatro son los cambios de nivel del paso 1.
- Ahora sí aparece todo lo que faltaba en la Actividad 3: quién (`app_ventas`), cuándo (11:51:13.931), desde dónde (127.0.0.1), con qué aplicación (`app-ventas-web`) y qué sentencia, completa.
- El SELECT que leyó el RFC no aparece: con `mod`, las lecturas no se registran.
- La línea muestra el teléfono nuevo, pero no el que había antes.
- Esta vez los `ALTER SYSTEM` sí aparecen, porque cuando se ejecutaron el nivel ya incluía `ddl`.
- Cada cambio de nivel deja dos líneas. La primera es la sentencia, con el usuario y la sesión que la ejecutó (procesos 398, 413 y 524). La segunda es la confirmación del proceso 1, el proceso principal del servidor, que es el que aplica la configuración y por eso no tiene usuario. Juntas dicen quién cambió la bitácora y desde cuándo vale el cambio.
- Los `ALTER SYSTEM` aparecen con punto y coma porque se escribieron en `psql`, igual que en la evidencia 06. El UPDATE no lo lleva, porque se pasó con `-c` sin él.

## Análisis

**¿Qué nivel habría registrado la lectura del RFC? ¿Qué costo tendría en un servidor con miles de consultas por minuto?**

El nivel `all`, el único que registra también los SELECT. Habría dejado una línea con `statement: SELECT nombre, rfc FROM clientes WHERE id = 3`, que dice quién consultó el RFC del cliente 3, aunque no qué datos le regresó el servidor.

El costo es que cada consulta se vuelve una línea. La del UPDATE de este laboratorio mide 172 caracteres; con el salto de línea, unos 173 bytes. Con líneas de ese tamaño:

| Consultas por minuto | Por minuto | Por día | Un archivo de 10 MB se llena en |
| --- | --- | --- | --- |
| 1,000 | unos 170 KB | unos 250 MB | una hora, aproximadamente |
| 10,000 | unos 1.7 MB | unos 2.5 GB | unos 6 minutos |

Es un cálculo aproximado: las consultas reales suelen ser más largas, y cada conexión nueva suma sus propias líneas. Los 10 MB son el tamaño al que el colector empieza un archivo nuevo (`log_rotation_size`), que este servidor tiene con su valor por defecto. Como la vista `dba.bitacora` solo lee el archivo vigente ([evidencia 02](02-colector.md)), con 10,000 consultas por minuto solo mostraría los últimos minutos.

Además del espacio, escribir cada línea es trabajo extra para el mismo servidor que atiende las consultas. Los eventos importantes, como un GRANT o un acceso fallido, quedarían enterrados entre miles de SELECT. Y la bitácora guardaría los valores que viajan en las consultas, como un RFC buscado en un WHERE, así que sería todavía más sensible. Por eso `all` no es práctico para auditar lecturas de forma permanente. Para registrar solo las lecturas de ciertas tablas o columnas está la extensión pgaudit, que es la Parte C de la guía y no se hizo en este laboratorio.

**¿Qué le falta a esta bitácora para revertir el cambio con certeza?**

1. **El valor anterior.** La fila 8 dice que el teléfono quedó en `6679990000`, pero no cuál tenía. Para revertirlo habría que buscarlo en un respaldo.
2. **Las filas afectadas.** Se registra la condición (`WHERE id = 3`), no las filas que cambiaron. Aquí era una sola, pero con una condición más amplia no se sabría cuáles filas la cumplían en ese momento ni cuántas eran.
3. **Si el cambio se confirmó.** La sentencia se registra al recibirla. Un UPDATE que después se deshace con ROLLBACK deja la misma línea que uno confirmado, y con `mod` no se registran ni el BEGIN ni el ROLLBACK.
4. **Los cambios de antes de `mod`.** El cambio de RFC del paso 2 no dejó ninguna línea, así que la bitácora no da nada para revertirlo.

La bitácora registra lo que se pidió, no lo que cambió. La Parte B lo resuelve con una tabla de auditoría y un disparador que guardan, por cada fila modificada, el valor anterior y el nuevo, quién lo hizo y cuándo. Como el disparador trabaja dentro de la misma transacción, si el cambio se deshace, su registro de auditoría también se deshace.

## Conclusión

Con `mod`, la bitácora ya muestra quién modificó un dato, cuándo, desde dónde, con qué aplicación y con qué sentencia, mientras que con `ddl` el mismo UPDATE solo dejó una conexión de 14 milisegundos. Pero sigue sin mostrar las lecturas, el valor anterior ni si el cambio se confirmó: sirve para saber que alguien cambió un dato, no para revertirlo. Para eso hace falta la auditoría a nivel de dato de la Parte B. También quedó claro que cada cambio de configuración de la bitácora se registra con su autor, incluidos los dos cambios de nivel de más que provocaron los intentos fallidos.

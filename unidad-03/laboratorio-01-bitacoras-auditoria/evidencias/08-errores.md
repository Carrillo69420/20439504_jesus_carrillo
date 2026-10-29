# Evidencia 08 — Errores y operaciones rechazadas

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 8 (sección 14 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 29 de octubre de 2026

## Objetivo

Comprobar qué deja la bitácora cuando una operación se rechaza: un usuario que intenta algo para lo que no tiene permiso y un administrador que intenta borrar un rol que todavía tiene privilegios.

## Pasos y resultados

### 1. La contraseña de `soporte_ana`

La contraseña que se le había asignado a `soporte_ana` en la sección 6.5 tampoco era la de práctica de la guía. Como con `app_ventas` en la [evidencia 07](07-modificaciones.md), se le asignó de nuevo antes de empezar, en la sesión de administrador:

```text
comercial=# \password soporte_ana
Enter new password for user "soporte_ana":
Enter it again:
```

Quedó en la línea 93 de la bitácora como `ALTER USER soporte_ana PASSWORD 'SCRAM-SHA-256$<resumen>'`: el resumen, no la contraseña.

### 2. Los privilegios de `clientes`, antes de intentar el DROP

```text
comercial=# \dp clientes
                                  Access privileges
 Schema |   Name   | Type  |     Access privileges     | Column privileges | Policies
--------+----------+-------+---------------------------+-------------------+----------
 public | clientes | table | postgres=arwdDxt/postgres+|                   |
        |          |       | app_ventas=rw/postgres   +|                   |
        |          |       | soporte_ana=r/postgres    |                   |
(1 row)
```

- `postgres`, el dueño de la tabla, tiene todos los privilegios (`arwdDxt`).
- `app_ventas` tiene `r` (SELECT) y `w` (UPDATE).
- `soporte_ana` solo tiene `r`, como se le dio en la sección 6.5. El `REVOKE` de la Actividad 6 le quitaba un UPDATE que no tenía.
- Lo que va después de `/` es quién otorgó el privilegio, y el `+` al final de un renglón solo indica que la celda sigue abajo.

Se revisó antes del paso 4 porque, si `soporte_ana` no tuviera ningún privilegio ni fuera dueña de nada, el `DROP ROLE` sí la habría borrado.

### 3. `soporte_ana` intenta borrar un cliente

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://soporte_ana@127.0.0.1/comercial" -c "DELETE FROM clientes WHERE id = 5"
```

```text
Password:
ERROR:  permission denied for table clientes
```

Como en la evidencia 07, la contraseña se pidió con `-W` en lugar de escribirla en la cadena de conexión, como hace la guía.

### 4. El administrador intenta borrar el rol

```text
comercial=# DROP ROLE soporte_ana;
ERROR:  role "soporte_ana" cannot be dropped because some objects depend on it
DETAIL:  privileges for table clientes
```

### 5. Lo que registró la bitácora

```sql
SELECT linea FROM dba.bitacora
WHERE linea ~ '(ERROR|STATEMENT|DETAIL):  (permission|privileges|role|DELETE|DROP)'
ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
 2026-10-29 11:20:25.157 MST [227] user=postgres db=comercial app=psql client=[local] ERROR:  role "rol_temporal" does not exist
 2026-10-29 11:20:25.157 MST [227] user=postgres db=comercial app=psql client=[local] STATEMENT:  DROP ROLE rol_temporal;
 2026-10-29 11:59:07.891 MST [611] user=soporte_ana db=comercial app=psql client=127.0.0.1 ERROR:  permission denied for table clientes
 2026-10-29 11:59:07.891 MST [611] user=soporte_ana db=comercial app=psql client=127.0.0.1 STATEMENT:  DELETE FROM clientes WHERE id = 5
 2026-10-29 11:59:26.273 MST [619] user=postgres db=comercial app=psql client=[local] ERROR:  role "soporte_ana" cannot be dropped because some objects depend on it
 2026-10-29 11:59:26.273 MST [619] user=postgres db=comercial app=psql client=[local] DETAIL:  privileges for table clientes
 2026-10-29 11:59:26.273 MST [619] user=postgres db=comercial app=psql client=[local] STATEMENT:  DROP ROLE soporte_ana;
(7 rows)
```

- La guía muestra cinco filas, que aquí son de la 3 a la 7. Las dos primeras son el `DROP ROLE rol_temporal` que falló en la Actividad 6, porque el rol todavía no existía ([evidencia 06](06-privilegios-estructura.md)).
- Cada error deja su línea `ERROR` y la sentencia que lo causó (`STATEMENT`), más un `DETAIL` cuando el servidor da una explicación. La línea `STATEMENT` se escribe porque `log_min_error_statement` vale `error`, sin importar el valor de `log_statement`.
- Las líneas de error llevan el mismo prefijo que las demás: quién (`soporte_ana`), desde dónde (127.0.0.1) y con qué aplicación. Aquí es `psql`, porque esta cadena de conexión no lleva `application_name`.
- Con `mod`, cada sentencia aparece una vez más, al recibirse y antes de fallar: `LOG:  statement: DELETE FROM clientes WHERE id = 5` en la línea 98 y `LOG:  statement: DROP ROLE soporte_ana;` en la 104. El filtro no las muestra porque `~` distingue mayúsculas de minúsculas: busca `STATEMENT:` y esas líneas dicen `statement:`.
- En el archivo, el intento de `soporte_ana` ocupa las líneas 95 a 101. Primero están la conexión (95 a 97) y la sentencia (98). Después vienen el error (99), la sentencia que lo causó (100) y la desconexión (101), 6 milisegundos después de conectarse.

## Análisis

**¿El intento de `soporte_ana` causó algún daño? ¿Por qué debe auditarse de todos modos?**

No. El servidor revisó los privilegios antes de ejecutar el DELETE y lo rechazó sin tocar la tabla. Aun así debe auditarse, porque un intento rechazado también es información:

- Muestra que la cuenta intentó algo que no le corresponde. Puede ser un error de la persona, curiosidad o alguien más usando sus credenciales, y la bitácora es lo que permite preguntar y averiguarlo.
- Varios intentos seguidos forman un patrón, igual que los accesos fallidos que se contaron en la Actividad 5: alguien probando qué puede hacer cada cuenta.
- Demuestra que el privilegio mínimo funciona. En una auditoría, el rechazo registrado es la prueba de que `soporte_ana` no puede borrar clientes.
- Si algún día se le diera ese permiso por error, el mismo intento sí borraría el registro. El historial de intentos ayuda a reconstruir lo que pasó.

**¿Qué diferencia hay entre un error de autorización (esta actividad) y uno de autenticación (Actividad 5)?**

| | Autenticación (Actividad 5) | Autorización (esta actividad) |
| --- | --- | --- |
| Pregunta que responde | ¿Quién eres? | ¿Qué puedes hacer? |
| Cuándo falla | Al conectarse, antes de abrir la sesión | Dentro de la sesión, al ejecutar una sentencia |
| Nivel en la bitácora | `FATAL`: el servidor cierra la conexión | `ERROR`: solo se rechaza esa sentencia y la sesión sigue |
| Qué queda | `connection received`, `FATAL` y `DETAIL`, nunca una sentencia | La conexión autenticada, la sentencia, `ERROR` y `STATEMENT` |
| Qué lo decide | `pg_hba.conf` y la contraseña | Los privilegios (GRANT y REVOKE) |

En la Actividad 5, la cuenta no pudo demostrar quién era y no llegó a pedir nada. Aquí `soporte_ana` sí lo demostró (línea 96, `connection authenticated` con `scram-sha-256`), y lo que se rechazó fue una operación concreta. Por eso solo el error de autorización dice qué se intentó hacer.

**¿Qué indica el error de DROP ROLE sobre el orden correcto para dar de baja a un usuario?**

Que un rol no se puede borrar mientras algo dependa de él: los privilegios que se le dieron, como el SELECT de `soporte_ana` sobre `clientes`, o los objetos de los que es dueño. PostgreSQL lo impide para que no queden privilegios ni objetos ligados a un rol que ya no existe. Por eso el orden es primero quitar lo que depende del rol y después borrarlo:

1. `ALTER ROLE soporte_ana NOLOGIN;` para cortarle el acceso mientras se hace lo demás.
2. `REASSIGN OWNED BY soporte_ana TO postgres;` para pasarle a otro rol los objetos de los que es dueña.
3. `DROP OWNED BY soporte_ana;` para quitarle los privilegios que le queden. Los pasos 2 y 3 se repiten en cada base del servidor.
4. `DROP ROLE soporte_ana;`

En este caso bastaría con `REVOKE SELECT ON clientes FROM soporte_ana;` antes del `DROP ROLE`, porque el DETAIL dice que ese privilegio es lo único que la detiene. Estas sentencias no se ejecutaron, porque `soporte_ana` se sigue usando en el laboratorio. Con `ddl` o `mod`, todos esos pasos quedan en la bitácora, así que la baja de un usuario también se puede auditar.

## Conclusión

Los errores dejan rastro aunque `log_statement` no registre la sentencia: `ERROR`, `DETAIL` y `STATEMENT` dicen quién intentó qué, desde dónde y por qué se rechazó. Un intento rechazado no causa daño, pero es información de auditoría: muestra qué intentó cada cuenta y prueba que los privilegios funcionan. El error del `DROP ROLE` muestra además que PostgreSQL no deja borrar una cuenta con privilegios pendientes. Dar de baja a un usuario es un procedimiento en orden, y cada paso queda registrado.

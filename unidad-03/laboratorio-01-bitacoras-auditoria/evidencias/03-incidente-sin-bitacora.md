# Evidencia 03 — Incidente sin bitácora

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 3 (sección 9 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 29 de octubre de 2026

## Objetivo

Simular el cambio de RFC que reportó facturación y comprobar si, con la bitácora como quedó en la Actividad 2, se puede saber quién lo hizo.

## Pasos y resultados

### 1. El cambio

En PowerShell, por red y como la aplicación de ventas:

```powershell
docker exec -it dba-u3-pg psql "postgresql://app_ventas@127.0.0.1/comercial?application_name=app-ventas-web" -c "UPDATE clientes SET rfc = 'GAMA780912XXX' WHERE id = 3"
```

```text
Password for user app_ventas:
UPDATE 1
```

A diferencia del comando de la guía, la contraseña no va en la URI. `psql` la pidió, así que no quedó escrita en el comando ni en el historial de la terminal.

### 2. La búsqueda en la bitácora

En la sesión de administrador:

```sql
SELECT linea FROM dba.bitacora
WHERE linea ILIKE '%update%' OR linea LIKE '%app_ventas%';
```

```text
 linea
-------
(0 rows)
```

No aparece el UPDATE, ni siquiera la conexión de `app_ventas`.

### 3. Lo que sí hay

Dos consultas más, para ver qué contiene la bitácora y comprobar que el cambio ocurrió:

```sql
SELECT num, linea FROM dba.bitacora ORDER BY num;
SELECT id, nombre, rfc FROM clientes WHERE id = 3;
```

Resultado de la primera, sin la fila del encabezado:

```text
   1 | 2026-10-29 10:32:55.591 MST [1] LOG:  starting PostgreSQL 16.15 (Debian 16.15-1.pgdg13+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
   2 | 2026-10-29 10:32:55.592 MST [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
   3 | 2026-10-29 10:32:55.592 MST [1] LOG:  listening on IPv6 address "::", port 5432
   4 | 2026-10-29 10:32:55.596 MST [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
   5 | 2026-10-29 10:32:55.601 MST [30] LOG:  database system was shut down at 2026-10-29 10:32:55 MST
   6 | 2026-10-29 10:32:55.607 MST [1] LOG:  database system is ready to accept connections
   7 | 2026-10-29 10:37:55.690 MST [28] LOG:  checkpoint starting: time
   8 | 2026-10-29 10:37:58.320 MST [28] LOG:  checkpoint complete: wrote 29 buffers (0.2%); 0 WAL file(s) added, 0 removed, 0 recycled; write=2.614 s, sync=0.007 s, total=2.631 s; sync files=24, longest=0.003 s, average=0.001 s; distance=106 kB, estimate=106 kB; lsn=0/19A52D0, redo lsn=0/19A5298
(8 rows)
```

```text
 id |    nombre    |      rfc
----+--------------+---------------
  3 | María García | GAMA780912XXX
(1 row)
```

La bitácora sí funciona: tiene las seis líneas del arranque y dos de un checkpoint de las 10:37, que es el guardado a disco que el servidor hace cada cinco minutos cuando hubo cambios. Después no hay nada. En cambio, el RFC sí cambió: en la sección 6.5 era `GAMA780912GHI` y ahora es `GAMA780912XXX`. El dato cambió y no quedó ningún registro de quién lo cambió, ni de cuándo ni desde dónde.

## Análisis

**¿Puedes demostrar quién modificó el RFC?** No. Se sabe que fue `app_ventas` solo porque el cambio se simuló así, pero el servidor no guarda nada que lo pruebe. La bitácora no tiene la conexión ni la sentencia, y la tabla solo tiene el valor nuevo: no dice quién lo escribió, ni cuándo, ni cuál era el anterior. Con los permisos actuales, el cambio pudo hacerlo `app_ventas` o el administrador `postgres`, y no hay manera de saber cuál de los dos fue.

**¿Puedes demostrar que el cambio no lo hizo `soporte_ana`?** Tampoco. Hoy `soporte_ana` solo tiene SELECT sobre `clientes`, así que con su propia cuenta no podría hacer el UPDATE. Pero eso describe los permisos de ahora, no los del momento del cambio: con `log_statement = none`, un GRANT seguido de un REVOKE no habría dejado rastro. Y si conocía la contraseña de `app_ventas`, pudo usar esa cuenta. Sin bitácora solo queda un argumento («no tenía permiso»), no una prueba.

**Los privilegios de la Unidad II, ¿impidieron el cambio? ¿Debían impedirlo?** No lo impidieron, y no debían. `app_ventas` tiene UPDATE sobre `clientes` porque la aplicación de ventas actualiza datos de clientes. El cambio fue una operación permitida, hecha con una cuenta legítima. Los privilegios deciden quién puede hacer algo, pero no dejan constancia de lo que se hizo. Eso le toca a la auditoría: en un incidente como este, la pregunta no es si se podía, sino quién lo hizo, cuándo y qué valor había antes.

**¿Qué tendría que haber estado configurado antes del incidente?**

- El registro de conexiones (`log_connections` y `log_disconnections`), para saber qué cuenta entró, cuándo y desde dónde (Actividad 4).
- Un prefijo de línea con el usuario, la base, la aplicación y el cliente (`%u`, `%d`, `%a` y `%h` en `log_line_prefix`), para que cada línea diga quién la generó (Actividad 4).
- El registro de las sentencias que modifican datos (`log_statement = 'mod'`), para que el UPDATE quedara escrito con su texto (Actividad 7).
- Una auditoría a nivel de dato, con una tabla y un disparador que guarden el valor anterior y el nuevo (Actividades 10 y 11). Aun con `mod`, la bitácora del servidor guarda la sentencia, pero no el RFC que había antes.

## Conclusión

Con la configuración que había, el incidente no se puede investigar: el dato cambió y el servidor no guardó nada sobre ese cambio. Activar la bitácora ahora sirve para lo que pase de aquí en adelante, pero no para este cambio. Lo que no se registró en su momento ya no se puede reconstruir.

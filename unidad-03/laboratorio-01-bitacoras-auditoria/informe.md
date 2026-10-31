# Informe del LAB-01 — Bitácoras y auditoría del dato en PostgreSQL

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad III, temas 3.1 Auditoría de bases de datos y 3.2 Bitácoras y trazabilidad
- Fechas: 29 y 31 de octubre de 2026

Este informe sigue los puntos de la sección 28 de la guía y agrega la verificación final (sección 26) y las preguntas de reflexión (sección 29). Los comandos y resultados completos están en las [evidencias](evidencias/). Los números de línea son los de [bitacora-lab01.log](evidencias/bitacora-lab01.log). La Parte C (pgaudit) es opcional y no se realizó.

## 1. Despliegue y situación inicial

El servidor se creó en Docker con la imagen `postgres:16` (versión 16.15), en el contenedor `dba-u3-pg`, con la base `comercial`, el volumen `dba-u3-pg-data` y la zona horaria `America/Mazatlan`. El comando y sus diferencias con la guía están en el [README](README.md). Se cargaron los cinco clientes ficticios de la Unidad II y las cuentas `app_ventas` y `soporte_ana`. Las reglas por TCP de `pg_hba.conf` pasaron de `trust` a `scram-sha-256`, porque con `trust` ningún acceso puede fallar por contraseña.

Esto es lo que registraba por defecto ([evidencia 01](evidencias/01-configuracion-inicial.md)):

| Parámetro | Valor | Consecuencia |
| --- | --- | --- |
| `logging_collector` | `off` | La bitácora la guardaba Docker, no el servidor |
| `log_connections` y `log_disconnections` | `off` | No quedaba rastro de quién entraba o salía |
| `log_statement` | `none` | No se registraba ninguna sentencia que funcionara |
| `log_line_prefix` | `%m [%p] ` | Cada línea solo decía la hora y el proceso |

Por eso no se podía responder a Dirección. En la Actividad 3 se cambió el RFC de María García cuando solo se había activado el colector, y la bitácora no guardó la sentencia ni la conexión ([evidencia 03](evidencias/03-incidente-sin-bitacora.md)). Solo quedó el valor nuevo en la tabla.

## 2. Configuración aplicada

Los cambios se hicieron con `ALTER SYSTEM`, que guarda el valor en `postgresql.auto.conf`.

| Parámetro | Valor final | ¿Cómo se aplica? | Por qué |
| --- | --- | --- | --- |
| `logging_collector` | `on` | Reinicio | El servidor guarda su propia bitácora en archivos dentro del directorio de datos, sin depender de Docker |
| `log_connections` | `on` | Recarga | Registra cada conexión que llega y cada una que se autoriza |
| `log_disconnections` | `on` | Recarga | Registra el fin de cada sesión y su duración |
| `log_line_prefix` | `%m [%p] user=%u db=%d app=%a client=%h ` | Recarga | Cada línea dice cuándo, qué proceso, quién, en qué base, con qué aplicación y desde dónde |
| `log_statement` | `mod` | Recarga | Registra los cambios de estructura, de privilegios y de datos |

`logging_collector` pide reinicio porque el colector se conecta a la salida de los procesos cuando el servidor arranca. Los demás se aplican con `pg_reload_conf()`. Como esa función solo envía una señal, los valores se revisan en una consulta aparte, y `log_connections` y `log_disconnections` se comprueban desde una sesión nueva.

Para `log_statement` se probó primero `ddl`, que no registra los `UPDATE`: el mismo cambio solo dejó una conexión de 14 milisegundos ([evidencia 07](evidencias/07-modificaciones.md)). No se usó `all` porque también guardaría todas las consultas y los valores que llevan ([evidencia 14](evidencias/14-limites.md)).

## 3. Eventos observados

Una línea de la bitácora se lee así (línea 196):

```text
2026-10-31 09:50:08.326 MST [85] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: UPDATE clientes SET rfc = 'GAMA780912ZZZ' WHERE id = 3
```

Gracias al prefijo, esa sola línea dice cuándo, qué proceso, qué cuenta, en qué base, con qué aplicación y desde dónde. Este es un ejemplo de cada tipo de evento:

| Tipo | Líneas | Qué muestra | Qué no demuestra |
| --- | --- | --- | --- |
| Acceso fallido | 20 | `app_ventas` dio una contraseña incorrecta el 29/10 a las 11:00:33, desde 127.0.0.1 | Quién lo intentó ni si fue un error o un ataque: el usuario es solo el nombre que dio el cliente |
| Usuario inexistente | 23 y 24 | El mismo `FATAL`, y el `DETAIL` agrega que el rol no existe. Al cliente no se le dice | Lo mismo que el anterior |
| Acceso exitoso | 27 a 30 | `app_ventas` se autenticó con `scram-sha-256`, por la línea 119 de `pg_hba.conf`, y salió a los 17 milisegundos | Qué persona usó la cuenta: prueba que se conocía la contraseña. `app-ventas-web` lo declara el cliente |
| Privilegio | 34 | `postgres` ejecutó `GRANT UPDATE ON clientes TO app_ventas` | Que haya funcionado: la sentencia se registra antes de ejecutarse, y lo que falla deja un `ERROR` después |
| Estructura | 35 | `postgres` agregó la columna `segmento` a `clientes` | Qué persona fue: `postgres` entró por el socket con `trust` |
| Datos | 196 | `app_ventas` cambió el RFC del cliente 3 | El valor anterior ni si el cambio se confirmó: eso lo da la auditoría (evento 1) |
| Error | 98 a 100 | `soporte_ana` intentó `DELETE FROM clientes WHERE id = 5` y se rechazó por falta de permiso | La intención. Sí demuestra que el privilegio funcionó |
| Configuración | 80 y 83 | `postgres` ejecutó `ALTER SYSTEM SET log_statement = 'mod'`, y el proceso principal registró el cambio | Por sí sola, la línea 83 no dice quién lo pidió: la escribe el proceso principal, sin usuario |

## 4. Auditoría del dato

La bitácora dice qué sentencia se ejecutó, pero no cómo estaba el dato. Para eso se creó la tabla `auditoria.cambios_clientes`, en un esquema sin acceso para PUBLIC, y el disparador `trg_auditoria_clientes`, que agrega un registro por cada fila que cambia en `clientes` ([evidencia 10](evidencias/10-diseno-auditoria.md)).

| Campos | Qué responden |
| --- | --- |
| `usuario_sesion` y `usuario_efectivo` | Quién |
| `momento` | Cuándo |
| `aplicacion` e `ip_cliente` | Desde dónde |
| `operacion` e `id_cliente` | Qué se hizo y a qué cliente |
| `valores_antes` y `valores_despues` | Cómo estaba y cómo quedó la fila completa |

**`SECURITY DEFINER`.** La función del disparador se ejecuta con los privilegios de su dueño. Por eso `app_ventas` deja un registro en un esquema al que no puede entrar. Sin `SECURITY DEFINER`, su `UPDATE` falla completo con `permission denied for schema auditoria`, porque el disparador corre en la misma transacción.

**`session_user`.** Dentro de esa función, `current_user` es el dueño, `postgres`, así que todos los cambios parecerían suyos. `session_user` conserva la cuenta que se conectó. Por eso, en el evento 1, `usuario_sesion` es `app_ventas` y `usuario_efectivo` es `postgres`.

**El incidente auditado.** `app_ventas` cambió el RFC del cliente 3 de `GAMA780912XYZ` a `GAMA780912ZZZ` el 31/10 a las 09:50:08, desde 127.0.0.1 con `app-ventas-web` ([evidencia 11](evidencias/11-incidente-auditado.md)). La bitácora (línea 196) y la auditoría (evento 1) coinciden, y como el registro guarda el valor anterior, el cambio se puede revertir sin buscar en un respaldo. La aplicación tampoco puede leer ese registro: su intento se rechazó y quedó en las líneas 203 y 204.

## 5. Limitaciones

- **Lecturas.** `soporte_ana` consultó el RFC de María García y solo quedó una conexión de 6 milisegundos (líneas 231 a 233). `mod` no registra los `SELECT`, y el disparador no se activa con lecturas ([evidencia 14](evidencias/14-limites.md)).
- **Volumen.** Un `UPDATE` sin `WHERE` dejó una línea en la bitácora (236) y cinco registros en la auditoría (eventos 4 a 8). Con un millón de filas serían cerca de 600 MB más por una sola sentencia, según un cálculo aproximado.
- **Administrador con control total.** `postgres` apagó el disparador, cambió el RFC y lo volvió a encender en 3 milisegundos, y la auditoría no registró nada (líneas 226 a 228, [evidencia 13](evidencias/13-manipulacion.md)). Lo detectó la bitácora, pero un superusuario también puede apagar el registro de su sesión con `SET log_statement = 'none'`: esa orden no se registra y lo que haga después tampoco, así que solo queda su conexión.
- **Cuenta y persona.** La bitácora y la auditoría identifican una cuenta, no a una persona: varias personas pueden compartir `app_ventas`, y `postgres` entra por el socket con `trust`.

## 6. Riesgos de la bitácora

- **Secretos expuestos.** La línea 41 guardó en claro la contraseña del `CREATE ROLE` de la Actividad 6, aunque ese rol ya se borró, y las líneas 72, 93, 113 y 114 guardaron resúmenes SCRAM de `\password`. **El archivo se exportó con la contraseña y los resúmenes sustituidos** por `<REDACTED>` antes de salir del servidor, y se revisó que no quedara ninguno ([evidencia 15](evidencias/15-cronologia.md)). Los archivos originales del servidor todavía los tienen, así que también hay que protegerlos.
- **Pérdida.** La bitácora vive en el volumen `dba-u3-pg-data`: si se borra el volumen, se pierde junto con los datos. También se pierde si nadie conserva los archivos: el servidor abrió uno nuevo al arrancar el 31 de octubre, y la consulta de la guía habría dejado fuera las 181 líneas del 29. Por eso se exportaron los dos archivos, con su hash, y se guardaron fuera del servidor.
- **Acceso de terceros.** Quien lea la bitácora ve los datos escritos en las sentencias, como el correo y el RFC de Pedro Ruiz (línea 209). En el servidor, `dba.bitacora` solo la lee un superusuario ([evidencia 02](evidencias/02-colector.md)). La copia exportada está en un repositorio público, lo que solo es aceptable porque los clientes son ficticios, los secretos están tapados y la única IP de cliente que aparece es 127.0.0.1. Con datos reales tendría acceso restringido.

NIST SP 800-92 advierte de estos riesgos en sus secciones 2.3.2 y 5.1.2, como se detalla en la [evidencia 15](evidencias/15-cronologia.md).

## 7. Cronología y conclusión

La [evidencia 15](evidencias/15-cronologia.md) reconstruye 31 eventos en orden y responde a Dirección. Este es el resultado para los cuatro cambios del RFC:

| Cambio | ¿Quién? | ¿Valor anterior? |
| --- | --- | --- |
| Actividad 3 | No hay evidencia | No hay evidencia |
| Actividad 7 | No hay evidencia | No hay evidencia |
| Actividad 12 | `app_ventas`, según la bitácora y la auditoría | `GAMA780912XYZ` |
| Actividad 14 | `postgres`, solo según la bitácora | `GAMA780912ZZZ`, por deducción |

**¿Con esta configuración puede demostrarse quién cambió un dato sensible y qué valor tenía antes?**

Sí, con límites. Desde que `log_statement` está en `mod` y el disparador está activo, la Actividad 12 se responde completa, con dos fuentes que coinciden. Los límites son tres: se demuestra la cuenta y no a la persona, solo cubre lo ocurrido después de configurarla, y quien controla el servidor puede evitarla, como en la Actividad 14. Por eso la evidencia tiene que salir del servidor y la tiene que revisar alguien distinto de quien lo administra.

## 8. Verificación final (sección 26)

Se ejecutó el 31 de octubre de 2026, al terminar las actividades, en una sesión nueva de administrador.

### Parte A

```sql
SELECT name, setting, source FROM pg_settings
WHERE name IN ('logging_collector', 'log_connections', 'log_disconnections', 'log_statement', 'log_line_prefix');
```

```text
        name        |                 setting                 |       source
--------------------+-----------------------------------------+--------------------
 log_connections    | on                                      | configuration file
 log_disconnections | on                                      | configuration file
 log_line_prefix    | %m [%p] user=%u db=%d app=%a client=%h  | configuration file
 log_statement      | mod                                     | configuration file
 logging_collector  | on                                      | configuration file
(5 rows)
```

Los cinco parámetros tienen el valor y el origen esperados. Los eventos se buscaron en la bitácora exportada, desde la carpeta `evidencias/`:

```powershell
Select-String -Path bitacora-lab01.log -CaseSensitive -Pattern 'password authentication failed','Role "usuario_inexistente"','\[182\]','statement: (GRANT|REVOKE) UPDATE','statement: ALTER TABLE clientes ADD','statement: UPDATE clientes SET rfc','permission denied','STATEMENT:  (DELETE|SELECT \*)','parameter "log_statement" changed','(DIS|EN)ABLE TRIGGER'
```

`-CaseSensitive` hace falta para que `STATEMENT:` no coincida con cada `statement:`. Salieron 31 líneas, entre ellas las que pide la guía:

| Evento | Líneas | ¿Se cumple? |
| --- | --- | --- |
| Acceso fallido por contraseña incorrecta | 20 | Sí |
| Acceso fallido por usuario inexistente | 23 y 24 | Sí |
| Acceso exitoso con su desconexión | 27 a 30 | Sí |
| `REVOKE`, `GRANT` y `ALTER TABLE` | 33, 34 y 35 | Sí |
| `UPDATE` con usuario, IP y aplicación | 196 | Sí |
| Error de permisos con su sentencia | 99 y 100 | Sí |
| Cambio de configuración (`parameter ... changed to ...`) | 15 | Sí |

### Parte B

```sql
SELECT tgname, tgenabled, tgrelid::regclass FROM pg_trigger WHERE NOT tgisinternal;
SELECT operacion, count(*) FROM auditoria.cambios_clientes GROUP BY operacion ORDER BY operacion;
SELECT id_evento, operacion, usuario_sesion, aplicacion, ip_cliente FROM auditoria.cambios_clientes WHERE usuario_sesion = 'app_ventas' ORDER BY id_evento;
\dn+ auditoria
```

```text
         tgname         | tgenabled | tgrelid
------------------------+-----------+----------
 trg_auditoria_clientes | O         | clientes
(1 row)

 operacion | count
-----------+-------
 DELETE    |     1
 INSERT    |     1
 UPDATE    |     6
(3 rows)

 id_evento | operacion | usuario_sesion |   aplicacion   | ip_cliente
-----------+-----------+----------------+----------------+------------
         1 | UPDATE    | app_ventas     | app-ventas-web | 127.0.0.1
(1 row)

                      List of schemas
   Name    |  Owner   |  Access privileges   | Description
-----------+----------+----------------------+-------------
 auditoria | postgres | postgres=UC/postgres |
(1 row)
```

| Qué pide la guía | Resultado | ¿Se cumple? |
| --- | --- | --- |
| El esquema `auditoria` no tiene acceso para PUBLIC | Solo aparece `postgres=UC/postgres`; PUBLIC saldría como una entrada que empieza con `=` | Sí |
| El disparador está habilitado | `tgenabled = O` | Sí |
| La auditoría contiene un `UPDATE`, un `INSERT` y un `DELETE` | 6, 1 y 1 | Sí |
| El `UPDATE` de `app_ventas` muestra `usuario_sesion = app_ventas` | Evento 1 | Sí |
| La bitácora registra la desactivación y reactivación del disparador | Líneas 226 y 228 | Sí |

`dba-u3-pg` no se eliminó, porque el LAB-03 continúa sobre este servidor.

## 9. Preguntas de reflexión

**¿Por qué la auditoría no puede configurarse después de un incidente para investigarlo?**

Porque solo registra lo que ocurre desde que se enciende. El RFC de la Actividad 3 cambió antes de configurar la bitácora y la auditoría, y encenderlas después no recuperó nada: de ese cambio todavía no hay registro de quién lo hizo, cuándo ni qué valor había antes. La auditoría tiene que estar activa antes de que haga falta.

**¿Por qué conviene que la bitácora la administre el propio servidor y no el mecanismo de despliegue?**

Con `logging_collector` apagado, Docker decide cuánto se conserva y, si se borra el contenedor, la bitácora se pierde con él. Con el colector, los archivos quedan en el directorio de datos, que aquí está en un volumen, y se leen con la misma consulta en Docker, en Windows o en Linux. Eso no la protege de quien administra el servidor, y por eso también hay que sacarla de ahí.

**¿Por qué el prefijo de línea es tan importante como el nivel de `log_statement`?**

`log_statement` decide qué se registra, y el prefijo decide qué dice cada línea sobre quién lo hizo. Con el prefijo de fábrica, la línea 196 solo tendría la hora, el proceso y la sentencia. Para saber el usuario, la aplicación o la IP habría que buscar la conexión de ese proceso.

**¿Qué diferencia práctica hay entre registrar la sentencia y registrar el cambio en el dato?**

La sentencia dice lo que se pidió, y el cambio dice lo que le pasó al dato. La bitácora guarda también lo que falló o se deshizo, pero en una sola línea y sin el valor anterior (línea 236). La auditoría guarda un registro por fila, con sus valores antes y después (eventos 4 a 8), pero solo de lo que sí cambió. La primera sirve para saber quién intentó qué, y la segunda para saber qué cambió y poder revertirlo.

**¿Qué evidencia ofrece `pg_stat_activity` que no ofrece la bitácora, y viceversa?**

`pg_stat_activity` muestra lo que está pasando ahora, incluso lo que `mod` no registra, como el `SELECT pg_sleep(90)` del reporte ([evidencia 09](evidencias/09-pg-stat-activity.md)). Pero cuando la sesión termina, su fila desaparece. La bitácora no dice qué consultó ese reporte, pero conserva quién se conectó, desde dónde, cuándo y cuánto duró, además de los accesos fallidos y los errores. Las dos se relacionan con el PID.

**Si el administrador puede cambiar `log_statement` a `none` y desactivar el disparador, ¿quién audita al administrador?**

Dentro del servidor, nadie, porque controla el dato y lo que lo vigila. Lo tiene que hacer alguien de otra área, con evidencia que el administrador no pueda tocar: la bitácora enviada a un sistema externo, el hash guardado lejos de él y una revisión periódica contra los cambios autorizados. También ayuda que cada administrador use una cuenta con su nombre. Eso no impide el abuso, pero lo hace visible.

## Referencias

- Guía del LAB-01 de la Unidad III, secciones 26, 28 y 29.
- NIST. SP 800-92: Guide to Computer Security Log Management, septiembre de 2006: https://csrc.nist.gov/pubs/sp/800/92/final
- Manual de PostgreSQL, «Error Reporting and Logging»: https://www.postgresql.org/docs/current/runtime-config-logging.html
- Manual de PostgreSQL, «The Cumulative Statistics System» (`pg_stat_activity`): https://www.postgresql.org/docs/current/monitoring-stats.html
- Manual de PostgreSQL 16, «Trigger Functions»: https://www.postgresql.org/docs/16/plpgsql-trigger.html

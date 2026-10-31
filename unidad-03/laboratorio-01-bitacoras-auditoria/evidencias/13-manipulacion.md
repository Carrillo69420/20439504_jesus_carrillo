# Evidencia 13 — Intentar manipular la auditoría

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 14 (sección 20 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 31 de octubre de 2026

## Objetivo

Comprobar quién puede alterar la auditoría: si la cuenta de la aplicación puede borrarla o apagar el disparador, y qué pasa cuando lo hace un administrador.

## Pasos y resultados

Los números de línea son los del archivo de bitácora del 31 de octubre ([evidencia 11](11-incidente-auditado.md)).

### 1. La aplicación intenta borrar su rastro

```powershell
docker exec -it dba-u3-pg psql -W "postgresql://app_ventas@127.0.0.1/comercial?application_name=app-ventas-web" -c "DELETE FROM auditoria.cambios_clientes" -c "ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes"
```

```text
Password:
ERROR:  permission denied for schema auditoria
LINE 1: DELETE FROM auditoria.cambios_clientes
                    ^
ERROR:  must be owner of table clientes
```

Los dos `-c` usan la misma conexión, por eso la contraseña se pidió una sola vez. La aplicación no puede borrar registros de la auditoría, porque no tiene acceso al esquema, ni apagar el disparador, porque eso solo lo puede hacer el dueño de la tabla o un superusuario.

### 2. El administrador cambia un dato sin dejar registro

```sql
ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes;
UPDATE clientes SET rfc = 'GAMA780912GHI' WHERE id = 3;
ALTER TABLE clientes ENABLE TRIGGER trg_auditoria_clientes;
SELECT count(*) FROM auditoria.cambios_clientes;
```

```text
ALTER TABLE
UPDATE 1
ALTER TABLE
 count
-------
     3
(1 row)
```

El `UPDATE` funcionó y el conteo sigue en 3: son los mismos registros de las Actividades 12 y 13. `DISABLE TRIGGER` apaga el disparador sin borrarlo y `ENABLE TRIGGER` lo vuelve a encender, así que al terminar todo se ve normal y la tabla de auditoría no avisa nada.

### 3. Lo que registró la bitácora

```sql
SELECT num, linea FROM dba.bitacora
WHERE linea ~ 'statement: (DELETE FROM auditoria|ALTER TABLE clientes (DIS|EN)ABLE|UPDATE clientes SET rfc = .GAMA780912GHI)'
ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
  36 | 2026-10-31 10:04:56.378 MST [167] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: DELETE FROM auditoria.cambios_clientes
  39 | 2026-10-31 10:04:56.378 MST [167] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes
  45 | 2026-10-31 10:05:15.746 MST [175] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes;
  46 | 2026-10-31 10:05:15.748 MST [175] user=postgres db=comercial app=psql client=[local] LOG:  statement: UPDATE clientes SET rfc = 'GAMA780912GHI' WHERE id = 3;
  47 | 2026-10-31 10:05:15.749 MST [175] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER TABLE clientes ENABLE TRIGGER trg_auditoria_clientes;
(5 rows)
```

`~` compara contra una expresión regular: `(A|B)` significa «A o B» y `.` significa cualquier carácter, que aquí ocupa el lugar de la comilla simple. La guía busca solo el `ALTER TABLE` y el `UPDATE`; se agregó el `DELETE` para ver juntos los dos intentos de la aplicación.

| Línea | Usuario | Qué pasó |
| --- | --- | --- |
| 36 | `app_ventas` | Intentó borrar la auditoría. Se rechazó: el error está en las líneas 37 y 38 |
| 39 | `app_ventas` | Intentó apagar el disparador. Se rechazó: el error está en las líneas 40 y 41 |
| 45 | `postgres` | Apagó el disparador |
| 46 | `postgres` | Cambió el RFC del cliente 3 |
| 47 | `postgres` | Volvió a encender el disparador |

- Una línea con `statement:` no significa que la sentencia funcionó, porque se registra antes de ejecutarse. Lo que distingue a las líneas 36 y 39 es el `ERROR` que viene después.
- Las líneas 45 a 47 son de la misma sesión (PID 175) y ocurrieron en 3 milisegundos, porque se pegaron juntas.

### 4. La auditoría ya no coincide con el dato

```sql
SELECT c.id, c.rfc AS rfc_actual, a.valores_despues ->> 'rfc' AS ultimo_rfc_auditado
FROM clientes c JOIN auditoria.cambios_clientes a ON a.id_cliente = c.id
WHERE c.id = 3 ORDER BY a.id_evento DESC LIMIT 1;
```

```text
 id |  rfc_actual   | ultimo_rfc_auditado
----+---------------+---------------------
  3 | GAMA780912GHI | GAMA780912ZZZ
(1 row)
```

`ORDER BY a.id_evento DESC LIMIT 1` se queda con el registro de auditoría más reciente de ese cliente. Si todos los cambios estuvieran auditados, los dos valores serían iguales.

### Qué aporta cada mecanismo y quién lo puede alterar

| Mecanismo | Qué aporta | Quién lo puede apagar o alterar |
| --- | --- | --- |
| Tabla de auditoría | El detalle del dato, antes y después | El dueño de la tabla o un superusuario |
| Bitácora del servidor | La constancia de que el mecanismo se desactivó | Quien controle el servidor |

## Análisis

**¿Qué evidencia permite detectar que hubo un cambio sin auditar?**

1. **La bitácora (líneas 45 a 47).** Muestra quién apagó el disparador, cuándo y qué hizo mientras estaba apagado, con el valor nuevo. Es la única de las tres que dice quién fue. Cualquier `UPDATE clientes` de la bitácora sin su registro de auditoría es un cambio sin auditar.
2. **La diferencia entre la auditoría y el dato (paso 4).** El RFC actual no es el último valor auditado. No depende de la bitácora y se puede revisar cada cierto tiempo con una consulta, pero solo dice que algo cambió, no quién ni cuándo, y solo sirve para clientes que ya tienen algún registro de auditoría.
3. **El salto dentro de la auditoría.** El siguiente cambio al mismo cliente deja el hueco a la vista: en la [evidencia 14](14-limites.md), el evento 1 termina en `GAMA780912ZZZ` y el evento 8 empieza en `GAMA780912GHI`.

La bitácora tampoco es definitiva: un superusuario puede apagar el registro de su propia sesión con `SET log_statement = 'none'`, que no deja rastro ([evidencia 10](10-diseno-auditoria.md)). En ese caso solo quedarían las otras dos: se sabría que el dato cambió, pero no quién lo hizo.

**¿Qué control administrativo (no técnico) reduciría este riesgo?**

Un procedimiento de cambios con revisión independiente. Apagar un disparador de auditoría tiene usos legítimos, como una carga masiva, así que no se puede prohibir del todo. Pero debe pedirse por escrito, con un folio, el motivo, la hora y quién lo aprueba, y alguien distinto del DBA debe revisar cada cierto tiempo la bitácora contra esos folios: un `DISABLE TRIGGER` sin folio es un incidente. El procedimiento no impide el cambio, pero quien lo intente sabe que se va a revisar, y da un criterio para distinguir lo normal de lo anormal.

También ayudaría que cada administrador use una cuenta con su nombre. Hoy la línea 46 dice `postgres`, que no distingue a una persona de otra.

**Relaciona esta actividad con el principio de separación de funciones de la Unidad II.**

En la Unidad II, la separación de funciones significó que cada rol tuviera solo el acceso que necesita para su trabajo: analítica con los datos y sin el mapa de seudonimización ([LAB-01](../../../unidad-02/laboratorio-01-proteccion-datos/informe.md)), y la cuenta de la aplicación aparte de la del DBA ([LAB-04](../../../unidad-02/laboratorio-04-hardening/README.md)). El paso 1 muestra que esa separación funciona para la aplicación: `app_ventas` puede cambiar clientes, pero no tocar la auditoría.

El paso 2 muestra dónde se acaba: el administrador opera la base y además controla el mecanismo que lo vigila. Nada dentro del propio servidor protege contra alguien con control total, porque también puede alterar la bitácora. Por eso las organizaciones envían las bitácoras a un sistema externo administrado por otra área y separan a quien opera la base de quien custodia la evidencia. Es lo que ya proponía la [arquitectura del LAB-03](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/15-arquitectura.md): los registros los revisa alguien distinto del DBA, y conviene enviarlos también fuera de la base.

## Conclusión

La aplicación no puede borrar la auditoría ni apagar el disparador, y sus dos intentos quedaron registrados. El administrador sí pudo: cambió el RFC del cliente 3 de `GAMA780912ZZZ` a `GAMA780912GHI` a las 10:05:15 sin que la auditoría lo registrara. Lo detectan la bitácora, que dice quién fue, y la diferencia entre la auditoría y el dato, que dice que algo pasó. Ningún control dentro del servidor basta contra un administrador con control total: hace falta que la evidencia salga del servidor y que la revise otra persona.

# Evidencia 12 — Altas y bajas

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 13 (sección 19 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 31 de octubre de 2026

## Objetivo

Comprobar que la auditoría también registra las altas y las bajas, y ver qué queda de un cliente después de borrarlo.

## Pasos y resultados

Los números de línea son los del archivo de bitácora del 31 de octubre ([evidencia 11](11-incidente-auditado.md)).

### 1. Alta y baja de un cliente

Como administrador:

```sql
INSERT INTO clientes (nombre, correo, rfc, edad, ciudad, codigo_postal)
VALUES ('Pedro Ruiz', 'pedro.ruiz@example.test', 'RUPE950101AAA', 30, 'Guasave', '81000');
```

```text
INSERT 0 1
```

```sql
DELETE FROM clientes WHERE nombre = 'Pedro Ruiz';
```

```text
DELETE 1
```

### 2. Lo que registró la auditoría

```sql
SELECT id_evento, usuario_sesion, aplicacion, ip_cliente, operacion, id_cliente,
       valores_antes ->> 'rfc' AS rfc_antes, valores_despues ->> 'rfc' AS rfc_despues
FROM auditoria.cambios_clientes ORDER BY id_evento;
```

```text
 id_evento | usuario_sesion |   aplicacion   | ip_cliente | operacion | id_cliente |   rfc_antes   |  rfc_despues
-----------+----------------+----------------+------------+-----------+------------+---------------+---------------
         1 | app_ventas     | app-ventas-web | 127.0.0.1  | UPDATE    |          3 | GAMA780912XYZ | GAMA780912ZZZ
         2 | postgres       | psql           |            | INSERT    |          6 |               | RUPE950101AAA
         3 | postgres       | psql           |            | DELETE    |          6 | RUPE950101AAA |
(3 rows)
```

- El evento 1 es el cambio de RFC de la [evidencia 11](11-incidente-auditado.md); los eventos 2 y 3 son el alta y la baja de esta actividad.
- Un alta no tiene valor anterior y una baja no tiene valor posterior. Por eso `rfc_antes` está vacío en el evento 2 y `rfc_despues` en el 3.
- La consulta solo muestra el RFC, pero la función guarda la fila completa: `to_jsonb(NEW)` en el alta y `to_jsonb(OLD)` en la baja ([sql/05-funcion-disparador.sql](../sql/05-funcion-disparador.sql)).

El registro de la baja lo confirma:

```sql
SELECT valores_antes FROM auditoria.cambios_clientes WHERE id_evento = 3;
```

Resultado, sin la fila del encabezado:

```text
 {"id": 6, "rfc": "RUPE950101AAA", "edad": 30, "ciudad": "Guasave", "correo": "pedro.ruiz@example.test", "nombre": "Pedro Ruiz", "segmento": null, "telefono": null, "fecha_alta": "2026-10-31", "codigo_postal": "81000"}
(1 row)
```

Además de lo que se escribió en el `INSERT`, trae el `id` y la `fecha_alta`, que puso el servidor, y `segmento` y `telefono`, que quedaron nulos.

### 3. Pedro Ruiz en la bitácora

```sql
SELECT num, linea FROM dba.bitacora WHERE linea LIKE '%INSERT INTO clientes%' OR linea LIKE '%Pedro Ruiz%' ORDER BY num;
```

Resultado, sin la fila del encabezado:

```text
  27 | 2026-10-31 09:58:15.892 MST [118] user=postgres db=comercial app=psql client=[local] LOG:  statement: INSERT INTO clientes (nombre, correo, rfc, edad, ciudad, codigo_postal)
  28 |         VALUES ('Pedro Ruiz', 'pedro.ruiz@example.test', 'RUPE950101AAA', 30, 'Guasave', '81000');
  29 | 2026-10-31 09:58:23.769 MST [118] user=postgres db=comercial app=psql client=[local] LOG:  statement: DELETE FROM clientes WHERE nombre = 'Pedro Ruiz';
(3 rows)
```

- El `INSERT` se escribió en dos renglones, y la bitácora lo guarda igual. La línea 28 es la continuación, sin prefijo, y por eso la búsqueda lleva dos condiciones.
- Con `log_statement = 'mod'`, la bitácora guarda el texto de la sentencia, con todos los valores que se escribieron en ella.

## Análisis

**El cliente Pedro Ruiz ya no existe en `clientes`. ¿Dónde queda evidencia de que existió y de sus datos?**

En dos lugares de este servidor:

1. **La tabla de auditoría.** El evento 2 guarda en `valores_despues` la fila completa del alta, y el evento 3 la guarda en `valores_antes`. No es solo lo que se escribió en el `INSERT`: también el `id`, la `fecha_alta` y los campos que quedaron vacíos.
2. **La bitácora.** Las líneas 27 y 28 traen los valores del `INSERT`: nombre, correo, RFC, edad, ciudad y código postal. La línea 29 trae el `DELETE`, con el nombre en su condición.

De ahí pueden pasar a otras copias: un respaldo de la base incluye la tabla de auditoría, y la bitácora exportada en la Actividad 16 llevará esas líneas al repositorio. Aquí no importa porque Pedro Ruiz es un cliente ficticio, pero con datos reales serían copias que también habría que cuidar.

**¿Por qué `ip_cliente` está vacía en los eventos 2 y 3?**

Porque el administrador entró por el socket local y no por la red (`client=[local]` en las líneas 27 y 29), y en ese caso `inet_client_addr()` devuelve nulo. No es un dato que se perdió: el vacío significa que la conexión nació dentro del servidor.

Eso también limita lo que se puede afirmar sobre estos eventos. La regla `local` de `pg_hba.conf` está en `trust` ([README](../README.md)), así que `usuario_sesion = postgres` solo dice qué nombre se usó. Al socket se llega entrando al contenedor, y sin contraseña.

**La política de retención de la Unidad II pedía eliminar datos cuando ya no fueran necesarios. ¿Qué conflicto aparece? ¿Quién debe resolverlo?**

El `DELETE` quitó a Pedro Ruiz de `clientes`, pero sus datos siguen completos en la auditoría y en la bitácora. Ahí chocan dos necesidades legítimas:

- **Privacidad.** Conservar también es tratar (LFPDPPP, art. 2, fr. XIX), y los datos que dejan de ser necesarios se suprimen, previo bloqueo en su caso, al concluir su plazo de conservación (art. 10). La [política de retención del LAB-03 de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/10-retencion.md) concluyó que el plazo se aplica en todas las copias, y estas son dos copias más.
- **Evidencia.** La auditoría sirve precisamente porque conserva los valores. Si sus registros se borran junto con el cliente, ya no se puede demostrar quién lo dio de baja ni qué datos tenía.

Un borrado que no llega a las copias no cumple la política, y uno que llega a todas destruye la evidencia.

El DBA no lo resuelve solo. Según la [matriz de gobierno de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md), el área jurídica fija los plazos de conservación y de bloqueo, el responsable de privacidad decide si procede cada solicitud de cancelación y Dirección aprueba la política. El DBA es el custodio: avisa que estas copias existen, propone cómo tratarlas y aplica lo que se decida.

Lo que tendrían que decidir:

- **Un renglón nuevo en la tabla de retención** para la auditoría y otro para la bitácora, con su finalidad, su fundamento y su plazo.
- **Si estas copias funcionan como un bloqueo** (art. 2, fr. III): los datos se conservan sin usarse para otra cosa, solo para determinar responsabilidades, hasta la prescripción, y después se suprimen. El esquema `auditoria`, cerrado a la aplicación, ya va en ese sentido.
- **Cuánto guardar en cada registro.** Hoy un `UPDATE` del teléfono guarda también el RFC dos veces. Guardar solo los campos que cambiaron se acercaría más a la proporcionalidad (art. 12), aunque una baja sí necesita la fila completa para poder revertirse.

Cada depuración debe dejar constancia de la fecha, las tablas, cuántos renglones y quién la hizo, sin copiar los datos borrados.

## Conclusión

La auditoría registra altas y bajas con la fila completa, así que borrar a un cliente de `clientes` no borra sus datos del servidor: quedan en `auditoria.cambios_clientes` y en la bitácora. Eso permite demostrar lo ocurrido, y también choca con la retención de la Unidad II. Cuánto tiempo conservar esas copias no es una decisión técnica: la toman el área jurídica y el responsable de privacidad, y el DBA la aplica.

## Referencias

- Guía del LAB-01 de la Unidad III, sección 19.
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 (fracciones III y XIX), 10 y 12. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf

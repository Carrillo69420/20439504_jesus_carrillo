# Evidencia 10 — Respuesta a Dirección

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 10 (sección 16 de la guía)
- Fuentes: las evidencias 02, 03, 05, 07, 08 y 09 de este laboratorio y los archivos exportados en la Actividad 8
- Fecha: 13 de noviembre de 2026

## Objetivo

Responder las preguntas de Dirección de la sección 5 de la guía solo con la evidencia de este laboratorio. El área de facturación reportó que cambió el RFC de María García (`_id: 3`) en `comercial.clientes`. Donde no hay evidencia, se escribe «No hay evidencia con esta edición» y se explica el motivo técnico.

Las horas están en UTC, como las registra el servidor, y entre paréntesis en la hora de Culiacán (UTC−7).

## Resumen

| Pregunta | Respuesta |
| --- | --- |
| ¿Quién cambió el RFC? | Actividad 2: No hay evidencia con esta edición. Actividad 3: la cuenta `app_ventas` |
| ¿Cuándo y desde qué aplicación? | Actividad 2: No hay evidencia con esta edición. Actividad 3: a las 17:52:12 (10:52:12), desde `app-ventas-web` |
| ¿Qué valor tenía antes? | No hay evidencia con esta edición, en ninguna de las dos actividades |
| ¿Cambió alguien los privilegios de `app_ventas`? | Sí: recibió `dbAdmin` entre las 18:45:15 y las 18:46:46 (11:45:15 y 11:46:46). Quién lo hizo y el momento exacto: No hay evidencia con esta edición |

## Respuestas

### 1. ¿Quién cambió el RFC de María García en la Actividad 2? ¿Y en la Actividad 3?

**Actividad 2: No hay evidencia con esta edición.** El perfilador estaba en el nivel 0, el que trae MongoDB por omisión, y no registró nada. La bitácora de `mongod` tampoco guardó la operación ([evidencia 02](02-incidente-sin-perfilado.md)). De la tienda solo quedaron sus conexiones en [`bitacora-mongod.log`](bitacora-mongod.log): a las 17:33:50 (10:33:50), un cliente que se presentó como `app-ventas-web` abrió cuatro conexiones, y tres se autenticaron como `app_ventas` (`conn16`, `conn17` y `conn18`). Ningún evento dice qué hicieron esas conexiones, así que no se puede afirmar que el cambio fue suyo.

**Actividad 3: la cuenta `app_ventas`, la de la tienda.** El perfilador estaba en nivel 2 y registró el `update` del documento `_id: 3` con el usuario `app_ventas@comercial` ([evidencia 03](03-perfilador.md)). Ese usuario lo verificó el servidor al autenticar la conexión. Lo que no dice es qué persona usaba la cuenta: cualquiera que tenga su contraseña aparecería igual.

### 2. ¿Cuándo y desde qué aplicación?

**Actividad 2: No hay evidencia con esta edición.** Sin un documento del perfilador no queda el momento del cambio. Solo se sabe a qué hora se conectó la tienda, que no es lo mismo.

**Actividad 3: a las 17:52:12.541 (10:52:12), desde `app-ventas-web`, con el cliente `127.0.0.1`** ([evidencia 03](03-perfilador.md)). El nombre de la aplicación lo declara el propio cliente en su cadena de conexión, así que dice cómo se presentó, no qué programa era ([evidencia 05](05-accesos-mongod.md)). El cliente es `127.0.0.1` porque los comandos se ejecutaron dentro del contenedor.

### 3. ¿Qué valor tenía antes?

**No hay evidencia con esta edición, en ninguna de las dos actividades.** El documento del perfilador de la Actividad 3 guarda el filtro (`q: { _id: 3 }`) y el cambio (`u: { $set: { rfc: "GAMA780912XYZ" } }`), es decir, el valor nuevo, no el que había ([evidencia 03](03-perfilador.md)). De la Actividad 2 no quedó ni siquiera el valor nuevo ([evidencia 02](02-incidente-sin-perfilado.md)). La bitácora tampoco registró ninguno de los dos cambios: sus dos líneas «Slow query» son de la Actividad 4 ([evidencia 08](08-conservacion.md)).

Los valores se conocen solo porque los da la guía: el RFC original de la sección 6.3 era `GAMA780912GHI`, la Actividad 2 lo cambió a `GAMA780912XXX` y la Actividad 3 a `GAMA780912XYZ`. En un incidente real, sin esos datos, el valor anterior tendría que salir de un respaldo o de un registro que guarde el documento completo, como el disparador del LAB-01 en PostgreSQL. La auditoría nativa de Enterprise o Atlas tampoco lo guarda ([evidencia 09](09-comparacion.md)).

### 4. ¿Cambió alguien los privilegios de `app_ventas`?

**Sí: recibió el rol `dbAdmin` sobre `comercial` entre las 18:45:15 y las 18:46:46 (11:45:15 y 11:46:46).** Lo muestran las dos instantáneas del control compensatorio de la Actividad 7: en la primera, `app_ventas` tenía `readWrite`, y en la segunda, `readWrite` y `dbAdmin` ([evidencia 07](07-privilegios-control-compensatorio.md)).

**Quién lo hizo y el momento exacto: No hay evidencia con esta edición.** El `grantRolesToUser` no dejó ningún documento en `system.profile`, aunque el perfilador estaba en nivel 2 sin filtro, ni ninguna línea en la bitácora: ninguno de los dos mecanismos de Community registró el cambio. `tomada_por` dice quién tomó cada instantánea, no quién cambió los roles. La revocación del rol, al final de la Actividad 7, tampoco quedó registrada, y como no se tomó otra instantánea después, de ella no queda ni siquiera el intervalo. En MongoDB, según su documentación, solo la auditoría nativa de Enterprise o Atlas registraría los dos cambios con su autor ([evidencia 09](09-comparacion.md)).

## Conclusión

Con la configuración por omisión, la de la Actividad 2, el cambio del RFC no dejó evidencia: solo se ve que la tienda se conectó. Con el perfilador en nivel 2 se sabe qué cuenta hizo el cambio, cuándo y desde qué aplicación, pero no el valor anterior. El cambio de privilegios no lo registraron ni el perfilador ni la bitácora: solo lo detectó el control compensatorio, que dice qué cambió entre dos instantáneas, pero no quién lo hizo ni cuándo exactamente.

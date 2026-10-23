# Evidencia 05 — Análisis de una finalidad secundaria

LAB-03, Actividad 5 (sección 11 de la guía). No tiene script ni capturas: es un análisis de la propuesta con lo que ya se sabe de la tabla `clientes` y de las Actividades 1 a 4.

## Objetivo

Decidir si la empresa puede usar los datos de sus clientes para una finalidad nueva, «enviar promociones personalizadas basadas en la edad, ciudad y comportamiento de compra», y qué tendría que revisar antes de hacerlo.

## Procedimiento

No se modificó la base. La propuesta se comparó con cuatro fuentes:

1. Las finalidades del escenario (sección 6 de la guía): Atención al cliente, Facturación y Analítica con información agrupada. Ninguna es enviar publicidad, así que se supone que el aviso de privacidad solo menciona esas tres.
2. La matriz de la [evidencia 01](01-inventario-datos.md), que dice qué campos necesita cada proceso.
3. Lo que ya se construyó en las Actividades 2 a 4 (una tabla mínima, una vista y permisos por rol) y en el LAB-01 (token y correo enmascarado).
4. Los artículos 6, 7, 9, 11, 12, 15 y 58 de la LFPDPPP, que dicen qué pasa cuando cambia la finalidad.

Para saber si la base guarda compras, se listaron sus tablas con una consulta de solo lectura:

```sql
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;
```

Devuelve siete tablas (`clientes`, `clientes_soporte`, `clientes_protegidos`, `usuarios_insegura`, `usuarios_segura`, `analitica.clientes` y `pii.mapa_cliente`) y dos vistas (`v_analitica_clientes` y `v_clientes_soporte`). Ninguna guarda compras.

## Resultado

### 1. ¿El hecho de que la organización ya tenga los datos significa automáticamente que puede utilizarlos para cualquier finalidad?

No. Los datos se recabaron para atender al cliente, facturar y hacer estadísticas agrupadas, y la LFPDPPP limita su tratamiento a las finalidades del aviso de privacidad. Para usarlos en algo distinto, la empresa tiene que obtener otra vez el consentimiento del cliente (art. 11). Cambiar de forma sustancial la finalidad original sin cumplir ese artículo es una infracción (art. 58, fracción IX).

También cuenta lo que espera el cliente. Quien dio su correo para que la empresa lo atienda confía en que se usará para eso, no para armar su perfil y mandarle publicidad. La ley pide privilegiar esa «expectativa razonable de privacidad» (art. 6).

Tener los datos solo significa que técnicamente se pueden leer. Es lo mismo que se vio con el DBA en la evidencia 01: tener acceso no es tener una finalidad.

### 2. ¿Qué preguntas debería realizar la organización antes de implementar este tratamiento?

| Pregunta | Por qué importa |
| --- | --- |
| ¿Las promociones están en el aviso de privacidad? | Si no están, hay que actualizar el aviso, comunicar el cambio y obtener el consentimiento (arts. 11 y 15, fracciones III y VI). Puede ser tácito si el cliente recibe el aviso nuevo y no se opone (art. 7). |
| ¿Cómo puede negarse el cliente y cómo se respeta eso en la base? | El aviso debe ofrecer opciones para limitar el uso de los datos (art. 15, fracción IV), y el consentimiento se puede revocar en cualquier momento (art. 7). La base tiene que saber quién aceptó y quién no. |
| ¿Qué datos hacen falta de verdad y con qué detalle? | Solo los necesarios, adecuados y relevantes para la finalidad (art. 12). |
| ¿De dónde saldría el «comportamiento de compra»? | La base no guarda compras. Habría que reunir datos nuevos de cada cliente, y el aviso debe decir qué datos se tratan (art. 15, fracción II). |
| ¿Se puede hacer con información agrupada? | Los datos disociados ya no identifican a nadie y no requieren consentimiento (art. 9, fracción III). Sirven para decidir las promociones, pero no para enviarlas. |
| ¿Quién verá los datos y quién mandará los mensajes? | Si Marketing o un proveedor de correo reciben la información, los datos salen del área que los cuida y se crean copias nuevas. |
| ¿Cuánto tiempo se guardarán los grupos y las listas de envío? | Cada copia necesita su propio plazo y alguien que la borre al terminar (Actividades 8 y 10). |
| ¿Quién aprueba el tratamiento? | La empresa, con su área jurídica o de privacidad. Al DBA le toca poner los controles, no decidir la finalidad. |

### 3. ¿Qué datos serían realmente necesarios?

El tratamiento tiene dos partes, y no necesitan lo mismo:

- **Decidir qué promoción va a qué grupo.** Basta con la ciudad, el rango de edad y un resumen de las compras (por ejemplo, la categoría que más compra y cada cuánto), no cada ticket con fecha, monto y sucursal. Para esta parte no hace falta saber quién es cada persona: se puede trabajar con el token del LAB-01 en lugar del id.
- **Enviar la promoción.** Hace falta un medio de contacto, el correo, y solo el de los clientes que aceptaron. El nombre es opcional, para el saludo.

| Campo | ¿Se necesita? | Motivo |
| --- | --- | --- |
| id | No; basta el token | El token permite unir el grupo con el envío sin exponer el id (LAB-01). |
| nombre | Opcional, solo para enviar | La segmentación no lo usa. |
| correo | Sí, solo para enviar y solo de quien aceptó | Es el medio para mandar la promoción. |
| telefono | No | Solo si el cliente pidió recibir promociones por mensaje. |
| rfc | No | Su única finalidad es facturar, y además trae la fecha de nacimiento. |
| edad | Solo el rango | Para una promoción por edad basta el rango, como en la Actividad 3. |
| ciudad | Sí | Para las promociones por ciudad. |
| codigo_postal | No | La ciudad ya da la ubicación, y el código completo señala a cada cliente (evidencia 01). |
| fecha_alta | No | La propuesta no habla de antigüedad. |
| Comportamiento de compra | Sí, resumido | No existe en la base; antes hay que decidir qué se guarda y con qué detalle. |

### 4. ¿Necesitaría el área de marketing acceso directo a clientes?

No. Con SELECT sobre `clientes`, Marketing vería los nueve campos de todos los clientes, incluidos el RFC, el teléfono y la edad exacta, y también los de quienes no aceptaron promociones. Es el mismo caso del rol `analista` en la Actividad 4: recibió una vista, y la tabla le negó el acceso.

Lo que sí podría recibir:

- **Para decidir las promociones:** conteos por ciudad y rango de edad, sin nombres ni correos.
- **Para enviarlas:** no necesita ver la lista. El envío lo puede hacer un proceso o un sistema de correo que tome los correos de una vista con solo los clientes que aceptaron.

Hay que cuidar el tamaño de los grupos. En la vista de la Actividad 4, Culiacán tiene 3 clientes en el rango 30-44, pero Los Mochis y Mazatlán tienen uno cada uno. Una promoción para «Mazatlán, 45-59» le llegaría solo a María, así que ese grupo es, en realidad, su perfil individual.

### 5. ¿Qué controles técnicos podrían limitar la información entregada?

| Control | Qué limita | Dónde ya se usó |
| --- | --- | --- |
| Una vista con solo los campos necesarios y solo los clientes que aceptaron | Las columnas y los renglones que se entregan | Actividad 4 (`v_analitica_clientes`) |
| Un rol `marketing` con SELECT solo sobre esa vista y sin permiso sobre `clientes` | Quién consulta qué | Actividad 4 (rol `analista`) |
| Un registro del consentimiento por finalidad: quién aceptó promociones, cuándo y si lo retiró | Que solo se usen los datos de quien aceptó | Es nuevo; se retoma en las Actividades 9 y 12 |
| Rangos y conteos en lugar de valores exactos | El detalle de cada dato | Actividad 3 |
| Un tamaño mínimo de grupo: no entregar grupos de una o dos personas | Que un grupo señale a alguien | Anonimización del LAB-01 |
| El token en lugar del id para unir el grupo con el envío | La identificación de cada persona | LAB-01 (`analitica.clientes` y `pii.mapa_cliente`) |
| El correo enmascarado en reportes y pantallas | La exposición del dato | LAB-01 (`v_clientes_soporte`) |
| Un plazo para borrar los grupos y las listas de envío | Las copias que se acumulan | Actividades 8 y 10 |

## Análisis

1. **La propuesta mezcla dos tratamientos.** Decidir qué promociones hacer se resuelve con información agrupada, que no identifica a nadie. Enviar una promoción personalizada no: hay que saber a quién mandarla. Por eso la segunda parte necesita consentimiento, y la primera puede hacerse sin tocar datos personales.
2. **El comportamiento de compra es un dato nuevo.** No está en la base, así que la propuesta no solo cambia la finalidad de los datos que ya existen: también pide reunir datos nuevos sobre los hábitos de cada cliente. Eso es más invasivo que la edad o la ciudad y debe declararse en el aviso de privacidad.
3. **Los grupos pequeños se vuelven perfiles.** Con cinco clientes, dos de los tres grupos por ciudad y rango tienen una sola persona. En una base real pasa lo mismo al combinar criterios: cada filtro adicional achica el grupo hasta que señala a alguien.
4. **Hoy la base no podría cumplirlo.** Ningún campo dice quién aceptó recibir promociones, así que no hay forma de filtrar por consentimiento ni de respetar a quien lo retire. Antes de cualquier campaña, la base necesita ese registro.
5. **La decisión no es del DBA.** El DBA puede decir qué datos hacen falta y poner los controles, pero aprobar una finalidad nueva y actualizar el aviso le toca a la empresa, con su área jurídica o de privacidad.

## Conclusión

Tener los datos no da permiso de usarlos para cualquier cosa. Las promociones personalizadas son una finalidad nueva: requieren actualizar el aviso de privacidad y obtener el consentimiento de los clientes. Aun con ese consentimiento, Marketing no necesita la tabla `clientes`: le bastan conteos por ciudad y rango de edad para decidir, y un envío controlado con el correo de quienes aceptaron. Las vistas, los roles y los rangos de las Actividades 2 a 4 sirven para entregar solo eso; lo que falta es un registro de consentimiento por finalidad.

## Referencias

- Guía del LAB-03, secciones 6 y 11, y la [evidencia 01](01-inventario-datos.md).
- LAB-01: token, mapa y vista con el correo enmascarado ([informe](../../laboratorio-01-proteccion-datos/informe.md)).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 6, 7, 9, 11, 12, 15 y 58. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf

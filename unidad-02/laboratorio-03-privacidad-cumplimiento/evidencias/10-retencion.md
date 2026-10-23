# Evidencia 10 — Política de retención

LAB-03, Actividad 10 (sección 16 de la guía). No tiene script ni capturas: se analiza la política propuesta con la LFPDPPP, el CFF y lo que se encontró en las Actividades 1 a 8.

## Objetivo

Evaluar la política «Conservar todos los datos de clientes indefinidamente porque podrían ser útiles en el futuro» y definir qué debe determinar y documentar la empresa para fijar un periodo de retención.

## Procedimiento

No se ejecutaron comandos. La política se revisó con tres fuentes:

1. La LFPDPPP (artículos 2, 5, 10, 11, 12, 19, 24, 25, 31 y 58) y el artículo 30 del CFF.
2. La columna de retención de la [evidencia 01](01-inventario-datos.md) y los dos huecos que dejó pendientes: la tabla no dice si la persona sigue siendo cliente ni cuándo dejó de serlo, y la edad se desactualiza.
3. Lo encontrado en las Actividades 7 y 8: una copia que se quedó con el correo anterior y los datos de una sola persona repetidos en muchos lugares.

## Resultado

### Pregunta 1. ¿Es compatible con el principio de minimización?

No. Minimizar es tratar solo los datos necesarios para una finalidad concreta, y «podrían ser útiles en el futuro» no es una finalidad: es la falta de una. En la LFPDPPP esta idea corresponde al principio de proporcionalidad (art. 5): el tratamiento debe ser el necesario, adecuado y relevante para las finalidades del aviso de privacidad (art. 12).

Además, conservar también es tratar: la ley incluye la conservación y el almacenamiento en la definición de tratamiento (art. 2, fracción XIX). Una base que guarda datos sin finalidad los está tratando sin finalidad. La ley también lo dice de forma directa: los datos que dejan de ser necesarios para las finalidades del aviso deben suprimirse, previo bloqueo en su caso, cuando concluye su plazo de conservación (art. 10). «Indefinidamente» es lo contrario de un plazo.

Si un día aparece ese uso «útil», será una finalidad nueva y habrá que obtener otra vez el consentimiento (art. 11), como con las promociones de la Actividad 5.

### Pregunta 2. ¿Qué riesgos genera conservar información innecesaria?

- **Una fuga expone más datos y a más personas.** Si nunca se borra a nadie, `clientes` acumula el RFC, el teléfono y el correo de todos los que alguna vez compraron. Cada excliente conservado es una persona más afectada, y las vulneraciones que afecten de forma significativa a los titulares se les deben informar de inmediato (art. 19).
- **Los datos se vuelven inexactos.** La ley pide datos exactos y actualizados (art. 10), y mantener datos inexactos es una infracción (art. 58, fracción VI). En este laboratorio ya se ve dos veces: la edad de Ana dejará de ser cierta en marzo de 2027, y la copia de soporte se quedó con su correo anterior (Actividad 7).
- **Aparece la tentación de usarlos para algo que nadie autorizó.** Las promociones de la Actividad 5 son justo eso: datos que «ya se tienen» buscando una finalidad nueva.
- **Responder a los derechos ARCO cuesta más.** La empresa tiene 20 días hábiles para comunicar su respuesta (arts. 2, fracción VIII, y 31). Para una sola persona, la Actividad 8 encontró datos en cuatro tablas además de `clientes`, en tres archivos del contenedor, en el repositorio, en GitHub y en OneDrive; con años de datos acumulados, la búsqueda solo crece.
- **La base se vuelve más pesada.** Más renglones significan tablas e índices más grandes, respaldos más tardados y más trabajo para VACUUM. En esta materia, seguridad y desempeño van del mismo lado: guardar menos es más seguro y más rápido.
- **Hay sanciones.** Tratar datos en contra de los principios de la ley es una infracción (art. 58, fracción IV), y una política escrita de «conservar todo» sería la prueba.

### Pregunta 3. ¿Qué debería determinar la organización antes de establecer un periodo de retención?

1. **La finalidad de cada dato y cuándo se cumple.** Es la matriz de la evidencia 01: el correo sirve mientras haya un cliente a quien contactar; el RFC, mientras haya facturas que emitir.
2. **Las leyes que obligan a conservar algo.** El CFF obliga a conservar la documentación fiscal cinco años (art. 30), y las facturas llevan el nombre, el RFC y el código postal fiscal del cliente. La LFPDPPP también fija un máximo: los datos sobre el incumplimiento de obligaciones contractuales se eliminan a los 72 meses (art. 10).
3. **Los plazos de prescripción.** El bloqueo dura lo mismo que el plazo de prescripción de las acciones que pueden surgir de la relación con el cliente (arts. 2, fracción III, y 24). Ese plazo lo determina el área jurídica, no el DBA.
4. **El evento que inicia el conteo y si la base lo registra.** Puede ser el fin de la relación, la fecha de una factura o la de una declaración. Hoy `clientes` no tiene ningún campo que diga si la persona sigue siendo cliente ni cuándo dejó de serlo, así que ningún plazo que empiece «al terminar la relación» se puede aplicar con una consulta.
5. **Qué pasa al vencer el plazo.** Los datos se bloquean, se suprimen o se disocian. Los datos disociados ya no se pueden asociar a nadie (art. 2, fracción IX), así que sirven para conservar solo las estadísticas.
6. **Dónde están las copias.** El plazo debe aplicarse en todas, incluidos los respaldos, que necesitan su propia rotación (mapa de la Actividad 8).
7. **Quién decide, quién ejecuta y quién revisa.** El área jurídica o de privacidad fija los plazos, el DBA los aplica en la base y avisa si algo lo impide, y alguien revisa que se cumplan.

### Pregunta 4. ¿Qué información debería documentarse para justificar el periodo seleccionado?

Una tabla de retención, con un renglón por cada grupo de datos y estas columnas:

| Columna | Qué responde |
| --- | --- |
| Datos | ¿Qué campos cubre el renglón? |
| Finalidad | ¿Para qué se conservan? |
| Fundamento | ¿Qué ley o qué necesidad del negocio justifica el plazo? |
| Plazo | ¿Cuánto tiempo? |
| Inicio del conteo | ¿Desde qué evento, y en qué campo de la base se registra? |
| Al vencer | ¿Se bloquean, se suprimen o se disocian? |
| Copias | ¿Dónde más están y cómo se limpian? |
| Responsables | ¿Quién aprobó, quién ejecuta y cuándo se revisa la política? |

Además, cada depuración debe dejar constancia: fecha, tablas, cuántos renglones y quién la hizo, sin copiar los datos borrados.

Con lo que se sabe hoy, la tabla para `clientes` quedaría así:

| Datos | Finalidad | Fundamento | Plazo | Inicio del conteo | Al vencer |
| --- | --- | --- | --- | --- | --- |
| nombre, rfc y codigo_postal fiscal de las facturas emitidas | Documentación fiscal | CFF, art. 30; LFPDPPP, art. 25, fr. II | Cinco años | Presentación de la declaración relacionada | Supresión |
| correo y telefono | Contactar al cliente | LFPDPPP, arts. 10 y 24 | Mientras sea cliente, más el bloqueo que fije el área jurídica | Fin de la relación (hoy no se registra) | Bloqueo y luego supresión |
| edad, ciudad y codigo_postal | Estadísticas | LFPDPPP, arts. 2, fr. IX, y 12 | Mientras sea cliente | Fin de la relación (hoy no se registra) | Solo quedan conteos disociados |
| id y fecha_alta | Ubicar el registro | LFPDPPP, art. 10 | Mientras exista el registro | — | Se suprimen con el registro |
| Copias: `clientes_soporte`, registros de sesión y exportaciones | Uso temporal | Ninguno propio | Mientras se usen | Fin de su uso | Supresión |

### Lo que le falta a la tabla para aplicar cualquier plazo

La evidencia 01 dejó dos huecos pendientes, y los dos afectan la retención:

1. **No hay forma de saber quién ya no es cliente.** `fecha_alta` dice cuándo empezó la relación, pero ningún campo dice si sigue ni cuándo terminó. Con la tabla actual, el DBA solo podría aplicar dos políticas: borrar a todos o no borrar a nadie, y «conservar todo» termina siendo la única opción práctica, aunque no sea legal.
2. **La edad caduca.** Ana López tiene 41 años en la tabla, cumplirá 42 el 15 de marzo de 2027 y la tabla seguirá diciendo 41. Mientras más tiempo se conserve, más inexacto es el dato (art. 10), y conservarlo indefinidamente garantiza que estará mal.

La forma de corregir los dos en el diseño de la tabla se propone en la Actividad 12.

## Análisis

1. **Conservar no es neutral.** Guardar un dato «por si acaso» parece no hacer nada, pero tiene los mismos riesgos que usarlo: puede filtrarse, desactualizarse y usarse para otra cosa.
2. **No hay un solo plazo.** Un mismo cliente tiene datos con plazos distintos: los de sus facturas se quedan cinco años por el CFF, y su correo y su teléfono dependen del fin de la relación y del bloqueo que fije el área jurídica. «Todo indefinidamente» es la política más fácil de aplicar y la más riesgosa.
3. **La retención se aplica en todas las copias.** Si se depura `clientes` pero quedan `clientes_soporte`, los registros de sesión y los respaldos (mapa de la Actividad 8), la política no se cumplió.
4. **El DBA propone y ejecuta; no decide.** Los plazos legales los fija el área jurídica y la política la aprueba la empresa. El DBA aporta lo técnico: dónde están los datos, qué campos faltan y cómo depurar sin romper las llaves, como la de `pii.mapa_cliente`.

## Conclusión

La política propuesta no es compatible con la minimización ni con la LFPDPPP: conservar también es tratar, «podrían ser útiles» no es una finalidad y la ley pide suprimir lo que deja de ser necesario. Conservar todo aumenta el daño de una fuga, acumula datos inexactos y hace más lento responder a los derechos ARCO. La empresa debe fijar un plazo por grupo de datos, con su fundamento y el evento que inicia el conteo, documentarlo y aplicarlo en todas las copias. Para eso, la tabla `clientes` necesita como mínimo saber quién sigue siendo cliente y cuándo dejó de serlo.

## Referencias

- Guía del LAB-03, sección 16; evidencias [01](01-inventario-datos.md), [05](05-finalidad-secundaria.md) y [08](08-ciclo-vida.md).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 (fracciones III, VIII, IX y XIX), 5, 10, 11, 12, 19, 24, 25, 31 y 58. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Código Fiscal de la Federación, artículo 30. Texto vigente, última reforma publicada en el DOF el 9 de abril de 2026. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/CFF.pdf

# Evidencia 01 — Inventario y finalidad de los datos

LAB-03, Actividad 1 (sección 7 de la guía). No tiene script ni capturas: la matriz se llenó analizando la tabla `clientes` y los procesos del escenario.

## Objetivo

Hacer un inventario de los nueve campos de la tabla `clientes` y decidir, para cada uno, si es un dato personal, para qué se usa, si de verdad se necesita, quién debe poder verlo y cuánto tiempo conviene conservarlo.

## Procedimiento

No se ejecutaron comandos. La matriz se llenó con tres fuentes:

1. Los nueve campos de la tabla `clientes`, que son los mismos del escenario (sección 6 de la guía) y los de la tabla creada en el LAB-01.
2. Los procesos del escenario y lo que necesita cada uno: Atención al cliente (nombre, correo, teléfono e información básica), Facturación (nombre, RFC y datos fiscales) y Analítica (solo información agrupada, sin identificar a nadie).
3. La clasificación del LAB-01 (apartado 1.1 de su informe), que ya separaba los campos que identifican directamente a una persona de los que solo ayudan a identificarla.

A cada campo se le hicieron cinco preguntas, una por columna:

- **¿Es dato personal?** ¿Es información de una persona identificada o identificable? Es la definición de la guía (sección 4) y de la LFPDPPP (art. 2, fracción V).
- **Finalidad:** ¿qué proceso lo usa y para qué?
- **¿Es necesario?** ¿Ese proceso puede cumplir su finalidad sin el dato o con menos detalle? La LFPDPPP pide tratar solo los datos necesarios, adecuados y relevantes para las finalidades del aviso de privacidad (art. 12).
- **Nivel de acceso:** ¿quién lo necesita para hacer su trabajo?
- **Retención:** ¿hasta cuándo se necesita y hay alguna ley que obligue a conservarlo, como el Código Fiscal de la Federación (CFF) con las facturas?

Para la columna de acceso se usaron tres niveles:

| Nivel | Quién puede verlo |
| --- | --- |
| Restringido | Una sola área: la que usa el dato para su finalidad. |
| Operativo | Las dos áreas que atienden al cliente, Atención al cliente y Facturación, porque ambas usan el dato. |
| Agregado | Analítica, solo en conteos o rangos que no señalan a ninguna persona. |

## Resultado

| Campo | ¿Es dato personal? | Finalidad | ¿Es necesario? | Nivel de acceso | Retención |
| --- | --- | --- | --- | --- | --- |
| id | Sí, de forma indirecta | Ubicar el registro del cliente y relacionarlo con otras tablas | Sí | Operativo: Atención al cliente y Facturación | Mientras exista el registro del cliente |
| nombre | Sí | Saber con quién se trata y ponerlo en sus facturas | Sí | Operativo: Atención al cliente y Facturación | Mientras sea cliente; en las facturas emitidas, cinco años (CFF, art. 30) |
| correo | Sí | Contactar al cliente y responder sus solicitudes | Sí | Restringido: solo Atención al cliente | Mientras sea cliente, más el plazo que fije el área jurídica |
| telefono | Sí | Contactar al cliente | Sí, aunque puede ser opcional | Restringido: solo Atención al cliente | Mientras sea cliente, más el plazo que fije el área jurídica |
| rfc | Sí | Emitir facturas | Solo si el cliente pide factura | Restringido: solo Facturación | Mientras sea cliente; en las facturas emitidas, cinco años (CFF, art. 30) |
| edad | Sí | Estadísticas por rango de edad | No la edad exacta; basta el rango | Agregado: Analítica, en rangos | Mientras sea cliente; después, solo los conteos por rango |
| ciudad | Sí | Estadísticas por ciudad | Sí, para las estadísticas | Agregado: Analítica, en conteos | Mientras sea cliente; después, solo los conteos por ciudad |
| codigo_postal | Sí | Estadísticas por región y, si es el del domicilio fiscal, la factura | Completo solo para facturar; para estadísticas basta la región | Agregado para Analítica (solo la región); completo, restringido a Facturación | Mientras sea cliente; en las facturas emitidas, cinco años (CFF, art. 30) |
| fecha_alta | Sí | Saber desde cuándo es cliente y desde cuándo se tienen sus datos | Sí | Agregado: Analítica, por mes o año | Mientras exista el registro del cliente |

El DBA no aparece en la columna de acceso porque su acceso es técnico: puede ver todos los campos porque administra la base, pero solo los usa para mantenerla funcionando, no para ninguna finalidad del negocio (sección 6 de la guía).

### Justificación por campo

- **id.** Es un dato personal aunque no diga el nombre: dentro de la empresa apunta a un solo cliente y con él se llega a todos sus datos, por eso en el LAB-01 quedó con nivel medio. Es necesario porque Atención al cliente y Facturación lo usan para ubicar el registro correcto sin buscar por nombre, y las aplicaciones lo usan para relacionar al cliente con otras tablas. Analítica no lo recibe, porque con él podría volver a identificar a la persona; por eso en el LAB-01 se cambió por un token. Se conserva mientras exista el registro.
- **nombre.** Identifica directamente a la persona. Atención al cliente lo usa para saber con quién habla, y Facturación porque la factura electrónica (CFDI 4.0) pide el nombre del cliente tal como está inscrito en el RFC. Analítica no lo necesita. En la tabla se conserva mientras la persona sea cliente; en las facturas ya emitidas se queda cinco años, porque son parte de la documentación fiscal que el CFF obliga a conservar (art. 30).
- **correo.** Es distinto para cada cliente y permite contactarlo, por eso en el LAB-01 quedó con nivel alto. Solo Atención al cliente lo necesita. No aparece en la factura, así que no le aplica el plazo del CFF: se conserva mientras la persona sea cliente, y el plazo después de que deje de serlo lo debe fijar el área jurídica en el aviso de privacidad, no el DBA.
- **telefono.** Igual que el correo: identifica a la persona, permite contactarla y solo lo necesita Atención al cliente. Puede ser opcional, porque al cliente también se le puede contactar por correo; de hecho, la columna ya acepta valores vacíos. Lleva la misma retención que el correo.
- **rfc.** Es uno de los datos más delicados de la tabla: es un identificador fiscal único y además trae la fecha de nacimiento (el de Ana López trae 850315, es decir, el 15 de marzo de 1985). Su única finalidad es facturar, porque la factura 4.0 lo pide, así que solo lo ve Facturación y solo hace falta pedírselo a los clientes que piden factura; la columna ya acepta valores vacíos. En las facturas emitidas se conserva cinco años (CFF, art. 30).
- **edad.** En la tabla es un dato personal porque está en el mismo renglón que el nombre. Ningún proceso del escenario necesita la edad exacta: Analítica hace estadísticas y le basta el rango (por ejemplo, 30-44). Además, una edad guardada como número se desactualiza cada año, y la LFPDPPP pide que los datos se mantengan exactos y actualizados (art. 10). Mientras la persona sea cliente se conserva; después, solo deberían quedar los conteos por rango.
- **ciudad.** Sola no identifica, pero en esta tabla hay un solo cliente en Mazatlán y uno solo en Los Mochis, así que en esos casos sí apunta a una persona (LAB-01). Analítica la necesita para contar clientes por ciudad y la recibe solo en conteos. Si un grupo es tan pequeño que señala a alguien, se debe juntar con otro o no mostrarse, como en la anonimización del LAB-01. Se conserva mientras la persona sea cliente; después, solo los conteos.
- **codigo_postal.** Es más preciso que la ciudad: en esta tabla los cinco son distintos, así que cada uno señala a un cliente. Para las estadísticas basta la región, que se obtiene con los primeros dígitos del código. Completo solo lo necesita Facturación, y solo si es el del domicilio fiscal, porque la factura 4.0 pide el código postal del domicilio fiscal del cliente; la tabla no dice si este lo es. Lleva la misma retención que el RFC.
- **fecha_alta.** Es un dato personal porque dice desde cuándo la empresa tiene los datos de esa persona. Es necesario porque es el único campo de la tabla que lo dice, y Analítica puede usarlo agrupado por mes o año para contar altas. Se conserva mientras exista el registro. Por sí solo no basta para calcular la retención: los datos se deben suprimir cuando dejan de ser necesarios (LFPDPPP, art. 10), y eso pasa cuando termina la relación con el cliente, no cuando empieza.

## Análisis

1. **Los nueve campos son datos personales.** Mientras estén juntos en la tabla, cada renglón trae el nombre y el correo de una persona, así que hasta la edad o la fecha de alta son información de alguien identificado. Lo que cambia de un campo a otro no es si es personal, sino qué tan riesgoso es y quién lo necesita. Un dato deja de ser personal solo cuando se separa de los identificadores y se resume en conteos o grupos que no señalan a nadie.
2. **Ningún proceso necesita los nueve campos.** Cada uno usa solo una parte:

   | Proceso | Campos que necesita |
   | --- | --- |
   | Atención al cliente | id, nombre, correo y telefono |
   | Facturación | id, nombre, rfc y, si es el fiscal, codigo_postal |
   | Analítica | edad en rangos, ciudad, región del código postal y fecha_alta por mes o año, siempre agrupados |

   Hoy la tabla junta todo, y cualquier usuario con permiso SELECT sobre `clientes` ve los nueve campos. Eso es lo que se corrige en las Actividades 2 a 4: una tabla mínima para soporte, una vista para Analítica y permisos por finalidad.
3. **Tener acceso no es tener una finalidad.** El DBA puede ver todos los campos porque administra la base, pero eso no le da permiso de usarlos para otra cosa. La LFPDPPP limita el tratamiento a las finalidades del aviso de privacidad y, si se quiere usar un dato para una finalidad distinta, hay que volver a pedir el consentimiento de la persona (art. 11).
4. **La retención no la inventa el DBA.** El único plazo legal confirmado para estos datos es el de la documentación fiscal: el CFF obliga a conservarla cinco años, contados desde que se presenta la declaración con la que tiene relación (art. 30), y las facturas llevan el nombre, el RFC y el código postal fiscal del cliente. Para lo demás, la LFPDPPP pide suprimir los datos que ya no son necesarios, previo bloqueo en su caso, cuando termina su plazo de conservación (art. 10). Ese plazo lo deben fijar el área jurídica y el responsable de privacidad; al DBA le toca aplicarlo en la base y avisar si algo lo impide.
5. **Lo que le falta a la tabla.** Al llenar la matriz salieron dos huecos. El primero es que ningún campo dice si la persona sigue siendo cliente ni cuándo terminó la relación, así que hoy no se puede aplicar con una consulta una regla de «mientras sea cliente». El segundo es que la edad se desactualiza: Ana López tiene 41 años en la tabla, cumplirá 42 el 15 de marzo de 2027 y la tabla seguirá diciendo 41. Los dos son problemas de diseño que se retoman en las Actividades 10 y 12.

## Conclusión

Los nueve campos de `clientes` son datos personales, pero cada proceso necesita solo una parte: Atención al cliente usa los datos de contacto, Facturación usa los datos fiscales y Analítica solo usa información agrupada. Por eso el acceso se debe dar según la finalidad y no porque el dato exista en la tabla. El inventario también muestra que los plazos de conservación dependen de decisiones jurídicas que el DBA no debe inventar; lo que sí le toca es aplicarlas en la base y señalar lo que falta para poder cumplirlas.

## Referencias

- Guía del LAB-03, secciones 4 a 7, y la matriz de clasificación del LAB-01 ([informe, apartado 1.1](../../laboratorio-01-proteccion-datos/informe.md)).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 (fracción V), 10, 11 y 12. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Código Fiscal de la Federación, artículo 30. Texto vigente, última reforma publicada en el DOF el 9 de abril de 2026. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/CFF.pdf
- SAT, esquema del CFDI 4.0 (`cfdv40.xsd`), nodo Receptor: http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd

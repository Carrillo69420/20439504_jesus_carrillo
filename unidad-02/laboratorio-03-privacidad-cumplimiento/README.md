# Laboratorio 03 — Privacidad y cumplimiento

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad II, tema 2.5 — Privacidad, cumplimiento y gobierno de los datos
- Entorno: PostgreSQL 16.15 en Docker (contenedor `dba-practica`, con la base `comercializadora`). Las pruebas que no debían cambiar esa base se hicieron en `dba-ensayo`, un contenedor de práctica armado con los mismos scripts.
- Fecha: 23 de octubre de 2026

Este README es el informe final del laboratorio (sección 26 de la guía), con las preguntas de reflexión de la sección 27 al final. Las actividades con SQL tienen su script en `sql/` y sus capturas en un PDF dentro de `evidencias/`; las de análisis tienen su propio `.md`. Las Actividades 2, 3, 4, 6, 7, 9 y 13 no piden un archivo de análisis, así que sus preguntas se responden aquí.

| Actividad | Script | Evidencia | Apartado |
| --- | --- | --- | --- |
| 1. Inventario y finalidad | — | [01-inventario-datos.md](evidencias/01-inventario-datos.md) | 2 y 3 |
| 2. Minimización | [01-minimizacion.sql](sql/01-minimizacion.sql) | [02-minimizacion.pdf](evidencias/02-minimizacion.pdf) | 4 |
| 3. Separación por finalidad | [02-finalidad.sql](sql/02-finalidad.sql) | [03-finalidad.pdf](evidencias/03-finalidad.pdf) | 3 |
| 4. Control de acceso | [03-control-acceso.sql](sql/03-control-acceso.sql) | [04-control-acceso.pdf](evidencias/04-control-acceso.pdf) | 5 |
| 5. Finalidad secundaria | — | [05-finalidad-secundaria.md](evidencias/05-finalidad-secundaria.md) | 3 |
| 6. Derecho de acceso | [04-derechos-arco.sql](sql/04-derechos-arco.sql) | [06-derecho-acceso.pdf](evidencias/06-derecho-acceso.pdf) | 6 |
| 7. Derecho de rectificación | [04-derechos-arco.sql](sql/04-derechos-arco.sql) | [07-derecho-rectificacion.pdf](evidencias/07-derecho-rectificacion.pdf) | 6 |
| 8. Cancelación y ciclo de vida | — | [08-ciclo-vida.md](evidencias/08-ciclo-vida.md) | 6 |
| 9. Derecho de oposición | — | Este informe | 6 |
| 10. Retención | — | [10-retencion.md](evidencias/10-retencion.md) | 7 |
| 11. Gobierno de datos | — | [11-gobierno-datos.md](evidencias/11-gobierno-datos.md) | 8 |
| 12. Privacidad por diseño | — | [12-privacidad-diseno.md](evidencias/12-privacidad-diseno.md) | 4 |
| 13. Controles técnicos y administrativos | — | Este informe | 8 |
| 14. Escenario integral | — | [14-evaluacion-integral.md](evidencias/14-evaluacion-integral.md) | 9 |
| 15. Arquitectura de datos protegidos | — | [15-arquitectura.md](evidencias/15-arquitectura.md) | 9 |

## 1. Introducción

En los LAB-01 y LAB-02 se protegió la tabla `clientes` de la empresa ficticia Comercializadora Norte S.A. de C.V.: se clasificaron sus datos, se enmascararon y seudonimizaron, se limitaron los permisos y se cifró el RFC. Este laboratorio cambia la pregunta. Ya no es cómo proteger técnicamente un dato, sino por qué se tiene, quién lo necesita, para qué, durante cuánto tiempo y qué controles le corresponden (sección 30 de la guía).

El problema de privacidad es que una base técnicamente segura puede seguir tratando mal los datos personales: puede darle a un área más datos de los que necesita, guardarlos para siempre «por si acaso» o usarlos para algo que el cliente no aceptó. Ninguno de esos problemas se resuelve con cifrado ni con contraseñas fuertes.

El escenario es la tabla `clientes`, con nueve campos de cinco clientes, y tres procesos que la usan: Atención al cliente, Facturación y Analítica (sección 6 de la guía). Como marco de referencia se usaron la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP), en su texto vigente de 2025, y el Código Fiscal de la Federación (CFF) para los plazos de las facturas. Como dice la guía (sección 5), el DBA no necesita convertirse en abogado: tiene que entender qué requisitos se traducen en controles técnicos y qué decisiones debe escalar a otras áreas.

## 2. Inventario de datos

Evidencia: [evidencias/01-inventario-datos.md](evidencias/01-inventario-datos.md)

Los nueve campos de `clientes` son datos personales. Mientras estén en el mismo renglón que el nombre y el correo, hasta la edad o la fecha de alta son información de alguien identificado (LFPDPPP, art. 2, fracción V). Lo que cambia de un campo a otro es qué tan riesgoso es y quién lo necesita:

| Campo | Riesgo (LAB-01) | Quién lo necesita | Nivel de acceso |
| --- | --- | --- | --- |
| id | Medio | Atención al cliente y Facturación | Operativo |
| nombre | Alto | Atención al cliente y Facturación | Operativo |
| correo | Alto | Atención al cliente | Restringido |
| telefono | Alto | Atención al cliente | Restringido |
| rfc | Alto | Facturación, solo de quien pide factura | Restringido |
| edad | Medio | Analítica, en rangos | Agregado |
| ciudad | Medio | Analítica, en conteos | Agregado |
| codigo_postal | Medio | Facturación, el del domicilio fiscal; Analítica, solo la región | Restringido completo; agregado por región |
| fecha_alta | Bajo | Analítica, por mes o año | Agregado |

Los tres niveles son: **restringido**, para una sola área; **operativo**, para las dos que atienden al cliente; y **agregado**, para Analítica, solo en conteos o rangos que no señalan a nadie. El DBA puede ver todos los campos porque administra la base, pero no los usa para ninguna finalidad del negocio.

El inventario dejó dos conclusiones. Primero, ningún proceso necesita los nueve campos. Segundo, a la tabla le faltan dos cosas: ningún campo dice si la persona sigue siendo cliente ni cuándo dejó de serlo, y la edad se desactualiza (Ana López tiene 41 en la tabla y cumple 42 el 15 de marzo de 2027). Las dos se retoman en los apartados 4 y 7.

## 3. Finalidades

Evidencias: [evidencias/01-inventario-datos.md](evidencias/01-inventario-datos.md), [evidencias/03-finalidad.pdf](evidencias/03-finalidad.pdf) y [evidencias/05-finalidad-secundaria.md](evidencias/05-finalidad-secundaria.md) · Script: [sql/02-finalidad.sql](sql/02-finalidad.sql)

Los datos deben usarse solo para las tres finalidades del escenario:

| Finalidad | Proceso | Datos que usa |
| --- | --- | --- |
| Atender al cliente | Atención al cliente | id, nombre, correo y teléfono |
| Facturar | Facturación | id, nombre, RFC y código postal fiscal |
| Hacer estadísticas | Analítica | Ciudad, rango de edad, región del código postal y mes de alta, siempre agrupados |

**Actividad 3.** En lugar de entregarle la tabla a Analítica, se calcularon tres conteos:

| Agrupación | Resultado |
| --- | --- |
| Por ciudad | Culiacán 3, Los Mochis 1 y Mazatlán 1 |
| Por rango de edad | 30-44: 4 y 45-59: 1 |
| Por región (dos primeros dígitos del código postal) | 80: 3, 81: 1 y 82: 1 |

**¿Por qué esta información puede ser más apropiada para analítica que entregar directamente la tabla completa de clientes?** Porque la finalidad de Analítica son las estadísticas, y los conteos la cumplen sin decir quién es quién: no llevan nombres, correos, teléfonos ni RFC. Es la minimización aplicada a una consulta. Si el reporte se comparte o se filtra, no expone a nadie, y no se crean copias de datos personales en hojas de cálculo. Hay un límite: Los Mochis y Mazatlán tienen un solo cliente, y un conteo de 1 sigue apuntando a una persona. Por eso los conteos necesitan un tamaño mínimo de grupo (apartado 5). En estos datos, además, cada región coincide con una ciudad (80 Culiacán, 81 Los Mochis y 82 Mazatlán), así que agrupar por región dio lo mismo que por ciudad.

**Actividad 5.** La empresa propuso usar los datos para «enviar promociones personalizadas basadas en la edad, ciudad y comportamiento de compra». Es una finalidad nueva: tener los datos no da permiso de usarlos para otra cosa, y hace falta actualizar el aviso de privacidad y obtener otra vez el consentimiento (LFPDPPP, art. 11). Aun con ese consentimiento, Marketing no necesita la tabla `clientes`: le bastan conteos para decidir las promociones y una vista con el correo de quienes aceptaron para enviarlas. La base no guarda compras ni quién aceptó qué, así que antes de cualquier campaña necesita un registro de consentimiento por finalidad, que se diseñó en la Actividad 12.

## 4. Minimización

Script: [sql/01-minimizacion.sql](sql/01-minimizacion.sql) · Evidencias: [evidencias/02-minimizacion.pdf](evidencias/02-minimizacion.pdf) y [evidencias/12-privacidad-diseno.md](evidencias/12-privacidad-diseno.md)

**Actividad 2.** Atención al cliente pidió una tabla `clientes_soporte` con los nueve campos de `clientes`. Al analizar la solicitud:

- **¿Todos los campos son necesarios para atención al cliente?** No. Para atender basta saber con quién se habla y cómo contactarlo: id, nombre, correo y teléfono. El RFC, la edad, la ciudad, el código postal y la fecha de alta les sirven a Facturación o a Analítica.
- **¿Por qué soporte necesitaría conocer el RFC?** No lo necesita. El RFC solo sirve para facturar, y un problema con una factura lo resuelve Facturación. Además, el RFC trae la fecha de nacimiento, así que dárselo a soporte expone un identificador fiscal sin ninguna finalidad.
- **¿Necesita conocer la edad?** No. Atender una solicitud no depende de la edad del cliente.
- **¿Necesita conocer el código postal?** No. El código completo solo lo usa Facturación, si es el del domicilio fiscal, y Analítica solo usa su región.
- **¿Qué principio de privacidad está relacionado con esta decisión?** La minimización: tratar solo los datos adecuados, relevantes y necesarios para una finalidad. En la LFPDPPP corresponde al principio de proporcionalidad (arts. 5 y 12).

Por eso se creó `clientes_soporte` con solo cuatro columnas y se cargaron los cinco clientes.

Esta solución tiene un problema que apareció después: `clientes_soporte` es una copia física y no se entera de los cambios. En la Actividad 7 se corrigió el correo de Ana López en `clientes`, y la copia se quedó con el anterior. Una vista con las mismas cuatro columnas habría dado la misma minimización sin crear otra copia. También se encontró que la vista de soporte del LAB-01, `v_clientes_soporte`, todavía muestra los últimos cuatro caracteres del RFC; con las respuestas anteriores, el RFC debería salir de esa vista (evidencia 11).

**Actividad 12.** Un desarrollador propuso una tabla con nombre, correo, teléfono, RFC, edad, dirección, ciudad, código postal, fecha de nacimiento, ocupación, salario, estado civil y «...», con la justificación «Es mejor guardar todos los datos por si posteriormente necesitamos alguno». La evidencia 12 concluye que:

- **ignora la minimización**, y con ella los principios de finalidad y calidad: guarda datos sin finalidad, repite información (la edad sale de tres campos) y acepta datos que se contradicen;
- **se deben eliminar** la edad, la dirección, la ocupación, el salario, el estado civil y los «...», cambiar la fecha de nacimiento por el año, y mover el RFC y el código postal fiscal a una tabla de datos fiscales, solo para quien pide factura;
- **requieren justificación adicional** el salario, que es un dato financiero y necesita consentimiento expreso (art. 7); el RFC, la fecha exacta de nacimiento, la dirección, la ocupación y el estado civil; y cualquier dato sensible que se quisiera agregar, que necesita consentimiento expreso y por escrito (art. 8);
- **la privacidad por defecto** se aplica pidiendo solo nombre y correo, dejando apagadas las promociones hasta que el cliente acepte, registrando el ciclo de vida (estatus, fin de la relación y bloqueo) y sin dar permisos a nadie hasta asignar una vista por área.

Las dos tablas se probaron en `dba-ensayo`, dentro de una transacción con `ROLLBACK`. La del desarrollador aceptó al mismo cliente dos veces, un cliente sin nombre ni correo, dos renglones con el id 1 y una edad que contradice la fecha de nacimiento. El diseño propuesto rechazó los cinco cambios inválidos que se intentaron, y su vista de promociones solo mostró al cliente que aceptó y no había revocado.

## 5. Control de acceso

Script: [sql/03-control-acceso.sql](sql/03-control-acceso.sql) · Evidencia: [evidencias/04-control-acceso.pdf](evidencias/04-control-acceso.pdf)

Los permisos se relacionaron con las funciones a partir de la finalidad: primero se decidió qué necesita Analítica (ciudad y rango de edad) y después se le dio acceso solo a eso.

El rol `analista` ya existía desde el LAB-01, así que en lugar de crearlo, lo que habría fallado con «already exists», se comprobó en `pg_roles` que no puede iniciar sesión ni es superusuario. Después se creó la vista `v_analitica_clientes`, con la ciudad y el rango de edad, y se le dieron al rol `USAGE` sobre el esquema `public` y `SELECT` sobre la vista. La verificación de permisos devolvió dos renglones: `SELECT` sobre `v_analitica_clientes` y `SELECT` sobre `analitica.clientes`, que viene del LAB-01. Con `SET ROLE analista`, la vista devolvió los cinco renglones y la consulta a `clientes` falló con «permission denied for table clientes».

El PDF muestra el rol en `pg_roles`, la vista con sus permisos, los permisos del rol, los cinco renglones de la vista consultada como `analista` y, en la última página, el error al consultar `clientes` y el regreso al rol original con `RESET ROLE`.

- **¿Qué información puede consultar el rol?** La ciudad y el rango de edad de cada cliente, con `v_analitica_clientes`. Además, por el permiso del LAB-01, puede consultar `analitica.clientes`: el token, la edad exacta, la ciudad, el código postal y la fecha de alta de cada cliente.
- **¿Puede consultar directamente clientes?** No. No se le otorgó `SELECT`, y PostgreSQL no da permisos a PUBLIC sobre las tablas (manual, sección 5.7), así que sin un `GRANT` no hay acceso. La vista sí lee `clientes`, pero con los permisos de su dueño, y solo entrega las dos columnas que define.
- **¿Puede obtener nombre, correo y RFC?** No. Ni la vista ni `analitica.clientes` tienen esas columnas, y la tabla que las tiene le niega el acceso.
- **¿Qué principio de privacidad estás aplicando?** La minimización (proporcionalidad, art. 12), junto con la finalidad: Analítica recibe solo lo que necesita para hacer estadísticas.
- **¿Qué principio de seguridad estás aplicando?** El de mínimo privilegio: el rol tiene el menor permiso que le permite hacer su trabajo, `SELECT` sobre una vista, y ningún acceso a la tabla.

La prueba dejó dos pendientes:

1. **La vista entrega un renglón por cliente, no conteos.** Los Mochis 30-44 y Mazatlán 45-59 tienen una sola persona cada uno, así que el analista sabe que esos renglones son de clientes concretos. Lo correcto sería entregar conteos con un tamaño mínimo de grupo. En la evidencia 15 se probó, en modo lectura, `HAVING COUNT(*) >= 3`: de los tres grupos solo quedó Culiacán 30-44, con 3 clientes.
2. **El permiso del LAB-01 sobre `analitica.clientes` da más de lo necesario.** Con la lógica de esta actividad, la edad exacta y el código postal completo de cada token sobran para hacer estadísticas. No se modificó, para no alterar lo entregado en el LAB-01, y queda como recomendación (evidencia 11).

## 6. Derechos ARCO

Script: [sql/04-derechos-arco.sql](sql/04-derechos-arco.sql) · Evidencias: [evidencias/06-derecho-acceso.pdf](evidencias/06-derecho-acceso.pdf), [evidencias/07-derecho-rectificacion.pdf](evidencias/07-derecho-rectificacion.pdf) y [evidencias/08-ciclo-vida.md](evidencias/08-ciclo-vida.md)

Las cuatro actividades se hicieron con Ana López (id 1). La respuesta jurídica de una solicitud les corresponde al responsable de privacidad y al área jurídica; aquí se identificaron las implicaciones técnicas para la base.

### Acceso (Actividad 6)

La consulta de la guía busca a Ana por `ana@example.com` y devolvió 0 renglones, porque su correo registrado es `ana.lopez@example.test`. Con ese correo aparecieron sus nueve campos. Después se buscaron sus datos en las otras tablas: aparecen en `clientes_soporte`, en `analitica.clientes`, que se encuentra con el token que `pii.mapa_cliente` guarda junto a su id, y en `clientes_protegidos`, que solo se encuentra por nombre. Las etiquetas del PDF lo resumen: 6.1, usuario, base de datos y fecha; 6.2, la consulta de la guía no encuentra a Ana; 6.3, con el correo registrado sí aparece; y 6.4, sus datos también están en otras tablas.

**¿Qué información adicional debería proporcionar la organización además del resultado de esta consulta?**

- **Los datos de todas las tablas y copias,** no solo los de `clientes`: aquí, los de `clientes_soporte`, `pii.mapa_cliente`, `analitica.clientes` y `clientes_protegidos`. Declarar con dolo que no existen datos que sí existen es una infracción (LFPDPPP, art. 58, fracción III).
- **Las condiciones del tratamiento.** El derecho de acceso incluye conocer las condiciones y generalidades del tratamiento a través del aviso de privacidad (art. 22): para qué se usan los datos y cómo puede limitar su uso o ejercer sus derechos (art. 15).

Las implicaciones técnicas que dejó la actividad:

1. **Hace falta un identificador confiable.** Buscar por el dato que da el titular puede fallar, como pasó con el correo. La solicitud debe traer los elementos para localizar los datos (art. 28), y en la base conviene buscar por el id una vez identificada la persona.
2. **Primero se acredita la identidad.** Los datos se entregan solo después de acreditar la identidad del titular (art. 31), y eso lo hace el área que tramita la solicitud, no el DBA.
3. **Las copias sin llave son difíciles de encontrar.** `clientes_protegidos` no tiene llave foránea y tiene otro RFC para el mismo nombre, así que hay riesgo de no encontrar datos o de mezclar a dos personas.
4. **La respuesta también es una copia.** Los resultados de estas consultas quedaron en el registro de psql y en las capturas del PDF. La entrega debe ser segura y no conservarse más de lo necesario.
5. **Hay plazo.** La empresa tiene 20 días hábiles para comunicar su respuesta (art. 31), así que la búsqueda técnica no puede depender de improvisar.

### Rectificación (Actividad 7)

Se cambió el correo de Ana con `UPDATE clientes SET correo = 'nuevo-correo@example.com' WHERE id = 1;` (`UPDATE 1`) y se verificó el valor nuevo. La copia `clientes_soporte` se quedó con `ana.lopez@example.test`, mientras que la vista `v_clientes_soporte` ya mostraba `nu*****@example.com`. Al final, `SHOW log_statement` devolvió `none`. Las etiquetas del PDF: 7.1, usuario, fecha y correo antes del cambio; 7.2, rectificación del correo y verificación; 7.3, la copia de soporte conserva el correo anterior y la vista ya muestra el nuevo; y 7.4, el servidor no registra quién hizo el cambio.

- **¿Cómo podría comprobarse que el cambio fue autorizado?** Con el procedimiento de solicitudes: el titular indica qué hay que cambiar y aporta la documentación que lo respalde (arts. 28 y 30), la persona o el departamento de datos personales la tramita (art. 29) y el DBA solo hace el cambio con un folio autorizado, que queda registrado junto al cambio. Hoy la base no podría demostrar nada: el cambio lo hizo `postgres`, sin ninguna referencia a una solicitud.
- **¿Debería registrarse quién realizó el cambio?** Sí: quién, cuándo, qué campo y con qué folio. Hoy el servidor no lo registra (`log_statement = none`), y aunque lo hiciera diría `postgres`, porque todo el laboratorio usó ese usuario. Hacen falta cuentas individuales y un registro de cambios que no copie más datos de los necesarios.
- **¿Por qué la trazabilidad será importante?** Porque permite demostrar que el cambio se pidió y se autorizó, que es parte del principio de responsabilidad (art. 13); detectar cambios que nadie autorizó; reconstruir qué pasó en un incidente; y avisar de la corrección a quien haya recibido los datos (art. 24). La guía la retoma en la Unidad III.

La actividad también mostró que una copia física deja datos inexactos después de una rectificación, y mantener datos inexactos es una infracción (art. 58, fracción VI). Las vistas no tienen ese problema, porque se calculan desde `clientes`.

### Cancelación (Actividad 8)

Antes de cualquier `DELETE` se armó el mapa de los datos de Ana. Están en cuatro tablas además de `clientes`, en tres archivos del contenedor (los dos registros de psql y su historial), en el repositorio con su historial, en GitHub y en OneDrive. El `DELETE` en `clientes` ni siquiera pasaría: la llave foránea de `pii.mapa_cliente` lo impide, como se comprobó en `dba-ensayo` con `ROLLBACK`. Además, PostgreSQL conserva la versión vieja de un renglón hasta que pasa VACUUM. Cumplir una cancelación es un proceso: confirmar la autorización, separar lo que la ley obliga a conservar (como las facturas, CFF art. 30), bloquear, suprimir en todas las copias en orden, limpiar los archivos y avisar al titular (arts. 24 y 25).

### Oposición (Actividad 9)

Supuesto: un cliente pide que sus datos no se usen para una finalidad secundaria, por ejemplo las promociones de la Actividad 5.

**¿Es necesario eliminar inmediatamente todos sus datos de la base?** No. La solicitud se refiere a una finalidad, no a toda la relación: la persona sigue siendo cliente, y la empresa necesita sus datos para atenderla y facturarle. Borrarlo todo iría más allá de lo que pidió, impediría las finalidades principales y podría violar obligaciones legales, como conservar la documentación fiscal cinco años (CFF, art. 30). Lo que pide es que ese tratamiento termine, no la cancelación de sus datos.

La figura legal depende de la base del tratamiento. Si las promociones dependían de su consentimiento, se trata de una revocación, que puede hacer en cualquier momento, sin efectos retroactivos (art. 7). Si no, es una oposición (art. 26), que procede por causa legítima: por ejemplo, cuando el tratamiento, aun siendo lícito, le causa un daño (fracción I), o cuando se le evalúa con decisiones automatizadas, sin intervención humana, que afectan sus derechos (fracción II). No procede si el tratamiento es necesario para cumplir una obligación legal. Decidir cuál aplica le toca al área de privacidad.

**Qué información podría mantenerse y cuál dejaría de usarse para esa finalidad:**

| Información | Qué pasa con ella |
| --- | --- |
| Nombre, correo y teléfono | Se conservan para atenderlo y dejan de usarse para promociones. |
| RFC y código postal fiscal | Se conservan para facturar y durante el plazo fiscal (CFF, art. 30; LFPDPPP, art. 25, fracción II). |
| Edad y ciudad | Dejan de usarse para segmentar promociones. Pueden seguir contando en estadísticas solo si son conteos disociados, que ya no identifican a nadie (art. 9, fracción III), y si el área de privacidad lo confirma. |
| Listas de envío ya generadas y la del proveedor de correo | Se le saca de ellas. |
| El registro de su oposición: qué finalidad y cuándo | Se conserva, porque es lo que permite seguir respetándola. |

**Qué mecanismos técnicos podrían separar finalidades:**

- **Un registro por finalidad.** La tabla `consentimientos` de la evidencia 12 guarda quién aceptó qué y cuándo; la oposición o la revocación llenan `fecha_revocado`.
- **Una vista por finalidad.** `v_promociones` solo muestra a quien aceptó y no ha revocado. En `dba-ensayo`, el cliente que revocó no apareció en ella, y sus demás datos siguieron en `clientes`.
- **Un rol por finalidad.** Marketing solo consulta `v_promociones`, nunca `clientes`.
- **Seguir las copias.** Las listas de envío y el proveedor de correo también son copias (mapa de la Actividad 8).
- **Dejar registro.** El cambio se hace con el folio de la solicitud.

**¿Por qué la decisión final no debe ser tomada únicamente por el DBA?** Porque decidir si la oposición procede es un análisis jurídico: hay que ver si existe causa legítima, si hay una obligación legal (art. 26) o si se trata de una revocación (art. 7), y responder en plazo (art. 31). La ley asigna el trámite a una persona o un departamento de datos personales (art. 29). El DBA no conoce el aviso de privacidad, los contratos ni las demás relaciones del cliente, y los dos errores posibles tienen consecuencias: borrar todo puede incumplir obligaciones fiscales, y seguir usando los datos después de que se pidió el cese es una infracción (art. 58, fracción XVI). Al DBA le toca decir dónde están los datos, qué se puede separar, aplicarlo y documentarlo.

## 7. Retención

Evidencia: [evidencias/10-retencion.md](evidencias/10-retencion.md)

La política «conservar todos los datos de clientes indefinidamente porque podrían ser útiles en el futuro» no es compatible con la minimización: conservar también es tratar (LFPDPPP, art. 2, fracción XIX), «podrían ser útiles» no es una finalidad, y la ley pide suprimir, previo bloqueo, los datos que dejan de ser necesarios (art. 10).

El periodo de conservación debería determinarse por grupo de datos, respondiendo siete preguntas:

1. ¿Cuál es la finalidad de cada dato y cuándo se cumple?
2. ¿Hay una ley que obligue a conservar algo? El CFF obliga a conservar la documentación fiscal cinco años (art. 30), y la LFPDPPP fija 72 meses como máximo para los datos de incumplimientos contractuales (art. 10).
3. ¿Cuánto dura el bloqueo? Lo mismo que el plazo de prescripción de las acciones que pueden surgir de la relación con el cliente, y ese plazo lo fija el área jurídica (arts. 2, fracción III, y 24).
4. ¿Qué evento inicia el conteo y la base lo registra? Hoy no: ningún campo dice cuándo terminó la relación.
5. ¿Qué pasa al vencer el plazo: bloqueo, supresión o disociación?
6. ¿Dónde están las copias? El plazo se aplica en todas, incluidos los respaldos.
7. ¿Quién decide, quién ejecuta y quién revisa?

Con eso, cada grupo de datos tiene su propio plazo: los datos de las facturas, cinco años; el correo y el teléfono, mientras sea cliente más el bloqueo que fije el área jurídica; la edad, la ciudad y el código postal, mientras sea cliente y después solo como conteos disociados. Los dos huecos del inventario, el fin de la relación y la edad que caduca, se resolvieron en el diseño de la Actividad 12 con `estatus`, `fecha_fin_relacion`, `fecha_bloqueo` y el año de nacimiento.

## 8. Gobierno de datos

Evidencia: [evidencias/11-gobierno-datos.md](evidencias/11-gobierno-datos.md)

La matriz de responsabilidades, resumida (la evidencia 11 agrega la finalidad, la protección y la retención de cada dato):

| Dato | Responsable (propietario) | Usuarios autorizados | Acción al finalizar |
| --- | --- | --- | --- |
| nombre | Atención al cliente | Atención al cliente y Facturación | Bloqueo y supresión; en facturas, supresión a los cinco años |
| correo | Atención al cliente | Atención al cliente | Bloqueo y supresión |
| telefono | Atención al cliente | Atención al cliente | Bloqueo y supresión |
| rfc | Facturación | Facturación | Bloqueo y supresión; en facturas, supresión a los cinco años |
| edad | Analítica | Analítica, solo en rangos | Disociación: solo conteos |
| ciudad | Analítica | Analítica, en conteos | Disociación: solo conteos |
| codigo_postal | Facturación | Facturación completo; Analítica, solo la región | Supresión; la región queda en los conteos |

El DBA y Dirección no aparecen como usuarios de ningún dato. El DBA es el custodio: crea roles, vistas y permisos, y aplica bloqueos y supresiones, pero no usa los datos para el negocio ni decide finalidades o plazos. Dirección aprueba las finalidades y la política, y trabaja con reportes agregados. La matriz agrega al responsable de privacidad, que tramita las solicitudes, y al área jurídica, que fija los plazos.

Al compararla con la base aparecieron diferencias: `soporte` ve el RFC enmascarado, que no necesita, y no ve el correo ni el teléfono completos, que sí necesita; `analista` ve datos de cada persona; Facturación no tiene rol; y `clientes_soporte` es una copia sin dueño.

### Controles técnicos y administrativos (Actividad 13)

Un control técnico se implementa con tecnología, como permisos, cifrado o registros; un control administrativo es una política, un procedimiento o una regla de la organización (guía, sección 4).

| Medida | Técnico | Administrativo | Justificación |
| --- | --- | --- | --- |
| Crear roles de PostgreSQL | Sí | — | Se configura en la base con `CREATE ROLE` y `GRANT`. Qué roles existen y quién los recibe lo decide la política de control de acceso, que es otra medida. |
| Política de retención | — | Sí | Es un documento aprobado por la empresa, con plazos, fundamentos y responsables. Las depuraciones que la aplican son controles técnicos aparte. |
| Cifrado de datos | Sí | Sí | El cifrado lo hace la base o la aplicación, pero depende de reglas sobre quién guarda la clave, cómo se rota y qué se hace si se expone. En el LAB-02, la clave de prueba quedó en el registro y en el historial de psql: el mecanismo funcionó, y lo que faltaba era la parte administrativa. |
| Procedimiento para solicitudes ARCO | Sí | Sí | Quién recibe la solicitud, cómo se acredita la identidad, los plazos y la respuesta son administrativos. Localizar, corregir, bloquear y suprimir los datos son pasos técnicos que el DBA ejecuta dentro de ese procedimiento (Actividades 6 a 9). |
| Vista con información limitada | Sí | — | Es un objeto de la base que limita las columnas y los renglones que ve cada rol, como `v_analitica_clientes`. |
| Clasificación de información | — | Sí | Es una decisión de la organización sobre el nivel de cada dato (LAB-01 y Actividad 1). Es la base de los controles técnicos, pero no protege nada por sí sola. |
| Registro de auditoría | Sí | Sí | Lo genera el sistema (`log_statement`, triggers o una extensión como pgaudit), pero solo sirve si alguien lo revisa, se protege y tiene un plazo de conservación, y eso lo define un procedimiento. |
| Política de control de acceso | — | Sí | Define quién necesita qué según su finalidad, como la matriz de la Actividad 11. Los roles, los permisos y las vistas son su aplicación técnica. |

Las medidas técnicas cambian la base; las administrativas deciden y documentan. Las tres que tienen las dos partes muestran que un control técnico sin reglas, o una regla sin un control que la aplique, se quedan a medias.

## 9. Evaluación integral

Evidencias: [evidencias/14-evaluacion-integral.md](evidencias/14-evaluacion-integral.md) y [evidencias/15-arquitectura.md](evidencias/15-arquitectura.md)

El escenario de la Actividad 14 (50,000 clientes, Analítica con acceso directo a la tabla, datos de 12 años, copias reales para desarrollo y Marketing usando los correos) tiene al menos doce problemas. Los principales:

| Riesgo | Principio afectado | Control propuesto |
| --- | --- | --- |
| Todo el personal de Analítica puede ver los datos de contacto y el RFC de 50,000 personas | Mínimo privilegio; finalidad; proporcionalidad | Un rol sin acceso a `clientes`, con conteos o un resumen mensual con tamaño mínimo de grupo |
| Las copias de desarrollo llevan datos reales fuera del entorno controlado y no reciben las rectificaciones ni las cancelaciones | Mínimo privilegio; deber de confidencialidad (art. 20) | Datos ficticios o enmascarados, y ninguna copia de producción en desarrollo |
| Marketing usa los correos para una finalidad que los clientes no aceptaron | Finalidad (art. 11); consentimiento (art. 7) | Actualizar el aviso y enviar solo a quien aceptó, con un registro de consentimientos y una vista |
| Doce años de datos sin una política de retención | Proporcionalidad; calidad; responsabilidad | Plazos por grupo de datos, aprobados con el área jurídica, y depuración de quien ya no es cliente |
| Nadie documentó la finalidad de cada dato | Información; responsabilidad | Inventario, matriz de gobierno y catálogo de datos |

Ninguno es una falla técnica de seguridad. Lo más urgente es cerrar el acceso directo de Analítica y las copias de desarrollo, porque exponen a todos los clientes. Lo de fondo es documentar las finalidades, porque de ahí salen los permisos, los plazos y los consentimientos.

La Actividad 15 propone separar la base en tres partes: **Operación**, con los datos necesarios para operar y una vista por área; **Analítica**, solo con conteos con tamaño mínimo de grupo; y **Auditoría**, con registros que solo se agregan. Para cada uno de los siete aspectos que pide la guía hay un control concreto: roles y vistas para el acceso; agregación para la minimización; cifrado, enmascaramiento y TLS para la información más delicada; campos de ciclo de vida y depuraciones para la retención; cuentas individuales y registro de cambios para la trazabilidad; supresión ordenada para la eliminación; y un registro de solicitudes con sus plazos para atenderlas. Buena parte ya existe desde los LAB-01 y LAB-02; falta sobre todo el ciclo de vida, el consentimiento y la auditoría.

## 10. Conclusiones

Lo más importante que deja este laboratorio es que seguridad y privacidad no son lo mismo. La seguridad decide quién puede llegar a un dato; la privacidad decide si ese dato debe existir, para qué se usa y por cuánto tiempo. Los controles de los LAB-01 y LAB-02, como roles, enmascaramiento, seudonimización y cifrado, son herramientas; este laboratorio enseñó a decidir cuándo y para qué usarlas.

El DBA traduce los principios de privacidad en decisiones técnicas: la minimización en vistas y conteos, la finalidad en un rol por área, la calidad en restricciones y campos de ciclo de vida, el consentimiento en una tabla y una vista, y la responsabilidad en registros de auditoría. Lo que no le toca es decidir las finalidades, los plazos o si una solicitud procede: eso lo decide la empresa con su área de privacidad y su área jurídica, y el DBA debe escalarlo y documentarlo.

También quedó claro que los datos viven más allá de la tabla. Ana López terminó en cuatro tablas más, en registros, capturas, el repositorio, GitHub y OneDrive, y una rectificación no llegó a la copia de soporte. Por eso cada copia debe tener una razón, un dueño y un plazo. Por último, privacidad y desempeño van del mismo lado: guardar menos datos reduce lo que se puede filtrar y también hace más pequeñas las tablas y los respaldos, y más rápidas las búsquedas para atender una solicitud.

## 11. Preguntas de reflexión

1. **¿Una base de datos técnicamente segura necesariamente cumple con todos los requisitos de privacidad?** No. La seguridad protege el dato de accesos no autorizados, pero no decide si el dato debe existir, para qué se usa ni cuánto tiempo se guarda. El escenario de la Actividad 14 no tiene ninguna falla técnica y aun así tiene doce riesgos. En `dba-practica`, después del LAB-02, había roles sin inicio de sesión y un RFC cifrado, y aun así `analista` veía la edad exacta y el código postal de cada cliente, y la copia de soporte se quedó con un correo que ya no era cierto.
2. **¿Por qué el principio de mínimo privilegio también contribuye a la privacidad?** Porque cada persona ve solo lo que su función requiere, y así menos gente ve datos personales, se hacen menos copias y una cuenta comprometida expone menos. Es la forma técnica de la minimización: en la Actividad 4, `analista` recibió una vista con dos columnas, y la tabla con los nueve campos le negó el acceso.
3. **¿Por qué el DBA no debería decidir por sí solo la finalidad del tratamiento de los datos?** Porque la finalidad la define la empresa en su aviso de privacidad, y usarla para algo distinto requiere un nuevo consentimiento (LFPDPPP, art. 11). El DBA no tiene la autoridad ni el contexto para eso: tener acceso técnico a un dato no le da una finalidad para usarlo. Su papel es señalar las implicaciones técnicas y aplicar lo que se decida.
4. **¿Por qué los desarrolladores no deberían recibir automáticamente copias completas de bases de datos productivas?** Porque su finalidad, programar y probar, no necesita a personas reales: necesita la estructura y datos realistas. Una copia completa les da más de lo que requiere su función, que es lo contrario del mínimo privilegio. Se puede copiar solo la estructura o excluir los datos de ciertas tablas (por ejemplo, con `pg_dump --exclude-table-data`) y cargar datos ficticios o enmascarados.
5. **¿Por qué una copia utilizada para desarrollo también puede representar un riesgo de privacidad?** Porque tiene los mismos datos de las mismas personas, con menos controles: equipos personales, servidores de prueba y cuentas compartidas. Además, no recibe las rectificaciones ni las cancelaciones, como la copia de soporte de la Actividad 7, y suele quedar fuera de la política de retención. Si se filtra, afecta a las mismas personas que una fuga de producción.
6. **¿Por qué la retención debe formar parte del ciclo de vida de los datos?** Porque conservar también es tratar (LFPDPPP, art. 2, fracción XIX), y los datos que dejan de ser necesarios se deben suprimir (art. 10). Si la retención no se diseña desde el principio, con el evento que inicia el plazo, el bloqueo y la depuración, «conservar todo» se vuelve la regla por omisión, y además hay que aplicarla en todas las copias.
7. **¿Qué relación existe entre privacidad por diseño y diseño de bases de datos?** El diseño de la base decide qué se recolecta (las columnas), con qué detalle (el año o la fecha completa), dónde se guarda (tablas separadas por finalidad), quién lo ve (vistas y roles) y cómo se registra su ciclo de vida (estatus, fechas y consentimientos). En la Actividad 12, la tabla del desarrollador aceptó duplicados y contradicciones, y el diseño alternativo los rechazó desde la estructura.
8. **¿Qué controles técnicos implementarías para reducir el riesgo de exposición de datos personales?** Roles por área con `SELECT` solo sobre vistas; conteos con tamaño mínimo de grupo para Analítica; una tabla de datos fiscales con el RFC cifrado; enmascaramiento donde no hace falta el dato completo; TLS en las conexiones; campos de ciclo de vida con depuraciones programadas; un registro de consentimientos por finalidad; cuentas individuales con registro de auditoría; copias de desarrollo con datos ficticios; y respaldos cifrados con caducidad.
9. **¿Qué información debería conocer un DBA para responder técnicamente a una solicitud ARCO?** Qué derecho se pide y sobre quién, con un folio autorizado y la identidad ya acreditada; un identificador confiable de la persona; el mapa de dónde están sus datos (tablas, copias, tokens, registros, respaldos y sistemas externos); las llaves foráneas y el orden para modificar o borrar; qué debe conservarse por ley y durante cuánto bloqueo; los plazos (20 días hábiles para responder y 15 más para hacer efectiva la respuesta); y cómo dejar registro de lo que hizo.
10. **¿Qué responsabilidades deberían corresponder al DBA, al responsable de privacidad, al área jurídica y al propietario de los datos?**
    - **DBA:** como custodio, implementa y mantiene los controles técnicos; localiza los datos y ejecuta rectificaciones, bloqueos y supresiones con autorización; avisa de los riesgos técnicos y documenta lo que hace.
    - **Responsable de privacidad:** tramita las solicitudes ARCO (art. 29), coordina la acreditación de la identidad y las respuestas, decide cuándo una finalidad requiere consentimiento y mantiene el aviso de privacidad.
    - **Área jurídica:** interpreta las obligaciones legales, fija los plazos de conservación y de bloqueo, y evalúa si una cancelación o una oposición proceden.
    - **Propietario de los datos:** decide para qué se usan sus datos dentro de las finalidades aprobadas, qué necesita su proceso y quién de su área tiene acceso.

## 12. Problemas encontrados

1. **El rol `analista` ya existía.** El `CREATE ROLE analista NOLOGIN;` de la Actividad 4 habría fallado con «already exists», porque el rol se creó en el LAB-01. Se comprobaron su existencia y sus atributos en `pg_roles`.
2. **La consulta de la guía no encontró a Ana.** Busca `ana@example.com`, y el correo registrado es `ana.lopez@example.test`. Se dejó como evidencia del problema de localización (6.2) y se buscó con el correo registrado.
3. **Errores al pegar en psql.** En la Actividad 4, al pegar por segunda vez la consulta a `clientes`, se coló la marca que la terminal agrega al pegar (`[200~`) y psql marcó un error de sintaxis sin ejecutar nada; se repitió la prueba, y el PDF muestra la prueba limpia. En otra ocasión se pegó dentro de psql un `docker exec` que solo hacía falta con psql cerrado; tampoco cambió nada.
4. **El registro de psql no guarda los errores.** `psql -L` guarda las consultas y sus resultados, pero no los mensajes de error. El «permission denied» de la Actividad 4 se confirmó en el log del servidor con `docker logs`, además de verse en la página 4 de su PDF.
5. **Diferencias con la estructura de la guía.** La guía nombra la carpeta `lab-03-privacidad-cumplimiento` y lista tres scripts (sección 24). Se conservó el nombre del esqueleto del repositorio, `laboratorio-03-privacidad-cumplimiento`, y se agregó un cuarto script para las Actividades 6 y 7. La entrega sigue en GitHub porque el GitLab de la FIC dejó de funcionar, como se explicó en el LAB-02.
6. **Pruebas fuera de la base del laboratorio.** El `DELETE` de la Actividad 8 y los diseños de la Actividad 12 se probaron en `dba-ensayo`, dentro de transacciones que se deshicieron con `ROLLBACK`, para que `dba-practica` conservara el estado que muestran los PDF.

## Referencias

- Guía del LAB-03, «Privacidad, cumplimiento y gobierno de los datos»: https://academy.ficlabs.com.mx/materias/dba/unidad-02/laboratorios/laboratorio-3-privacidad-cumplimiento-y-gobierno-de-los-datos/
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Código Fiscal de la Federación, artículo 30. Texto vigente, última reforma publicada en el DOF el 9 de abril de 2026. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/CFF.pdf
- SAT, esquema del CFDI 4.0 (`cfdv40.xsd`): http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd
- Manual de PostgreSQL 16, sección 5.7, «Privileges»: https://www.postgresql.org/docs/16/ddl-priv.html
- Manual de PostgreSQL 16, «CREATE VIEW» (permisos de las vistas): https://www.postgresql.org/docs/16/sql-createview.html

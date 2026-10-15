# Informe — LAB-01 Protección y privacidad de datos

- Alumno: Jesús Arturo Carrillo Avilez
- Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad II — Seguridad, privacidad y control de acceso, tema 2.3
- Entorno: PostgreSQL 16.15 en un contenedor de Docker (dba-practica), base comercializadora

## 1. Clasificación de los datos

Script: [sql/01-clasificacion.sql](sql/01-clasificacion.sql) · Evidencias: [evidencias/01-clasificacion.pdf](evidencias/01-clasificacion.pdf)

### 1.1 Matriz de clasificación

| Campo | ¿Identifica directamente? | ¿Puede contribuir a identificar? | ¿Requiere protección? | Justificación |
| --- | --- | --- | --- | --- |
| id | No | Sí | Sí, nivel medio | Es una clave interna: fuera de la empresa no dice quién es, pero dentro apunta a un solo cliente y sirve para juntar todos sus datos. Por eso en la Actividad 3 se sustituye por un token. |
| nombre | Sí | Sí | Sí, nivel alto | El nombre completo señala a una persona concreta; es el ejemplo de identificador directo que da la guía. |
| correo | Sí | Sí | Sí, nivel alto | Cada cliente tiene uno distinto, casi siempre incluye el nombre y permite contactarlo, lo que se presta a fraudes y suplantación. |
| telefono | Sí | Sí | Sí, nivel alto | Es distinto para cada cliente y permite contactarlo directamente. |
| rfc | Sí | Sí | Sí, nivel alto | Es un identificador fiscal único y además revela datos: se arma con letras de los apellidos y el nombre más la fecha de nacimiento (el de Ana López trae 850315, es decir, 15 de marzo de 1985). |
| edad | No | Sí | Sí, nivel medio | Sola no dice quién es, porque mucha gente tiene la misma edad. Aquí las cinco son distintas. Solo porque hay pocos clientes; combinada con ciudad y código postal sí señala a una persona. |
| ciudad | No | Sí | Sí, nivel medio | Sola no identifica, pero en esta tabla hay un solo cliente en Mazatlán y uno solo en Los Mochis, así que en esos casos ya apunta a una persona. |
| codigo_postal | No | Sí | Sí, nivel medio | Es más preciso que la ciudad: los cinco son distintos, y junto con la edad y la ciudad forman una combinación única para cada cliente. |
| fecha_alta | No | Sí, en menor grado | Sí, nivel bajo | Hoy no distingue a nadie porque todos tienen la misma fecha (evidencia 1.4), pero en una empresa real la fecha exacta de alta se puede cruzar con otros registros, también es el dato que usa la regla de retención. |

### 1.2 Preguntas

1. **¿Qué campos identifican directamente a una persona?** El nombre, el correo, el teléfono y el RFC, porque cada uno por si solo señala a un cliente en específico.
2. **¿Qué campos no identifican por sí solos pero podrían contribuir a hacerlo?** La edad, la ciudad, el código postal y el id, y en menor medida la fecha de alta, Solos no dicen quién es la persona, pero junto con otros datos sí pueden ayudar a identificarla.
3. **¿Qué combinación de campos podría incrementar el riesgo de reidentificación?** La edad, la ciudad y el código postal juntos. Esa combinación es distinta para cada uno de los cinco clientes, así que se podría reconocer a una persona aunque no aparezca su nombre.
4. **¿Todos los datos que deben protegerse son necesariamente datos personales sensibles desde el punto de vista jurídico?** No, los datos sensibles son los más íntimos o los que podrían causar discriminación, como la salud, la religión o la preferencia sexual, y en la tabla clientes no hay ninguno. Aun así, los datos de la tabla son personales y deben protegerse, porque si se filtran pueden usarse para fraudes o suplantación de identidad.

### 1.3 Qué datos requieren protección y por qué

Todos los campos de la tabla requieren protección pero no al mismo nivel. El nombre, el correo, el teléfono y el RFC tienen nivel alto porque identifican a la persona por si solos. El id, la edad, la ciudad y el código postal tienen nivel medio porque solos no la identifican, pero combinados sí pueden hacerlo, y la fecha de alta tiene nivel bajo. Si estos datos se filtran pueden usarse para fraudes o suplantación de identidad, y quitar solo el nombre no es suficiente para proteger a la persona.

### 1.4 Resumen de la actividad

1. **¿Cuál era el problema?** La tabla clientes guarda datos personales y no se sabía cuáles había que proteger ni con qué nivel.
2. **¿Qué riesgo o necesidad se identificó?** Que se expongan los datos que identifican directamente a un cliente, y que aun sin ellos se pueda reconocer a alguien por su edad, ciudad y código postal.
3. **¿Qué decisión se tomó?** Clasificar cada campo con una matriz antes de aplicar cualquier medida de protección.
4. **¿Qué configuración o implementación se realizó?** Se creó la tabla clientes, se insertaron cinco clientes de ejemplo y se hicieron dos consultas para analizar los datos. Todo está en sql/01-clasificacion.sql.
5. **¿Cómo se verificó?** Contando los valores distintos de cada campo y agrupando por edad, ciudad y código postal. Cada combinación salió una sola vez.
6. **¿Qué evidencia demuestra el resultado?** Las capturas del punto 1.1 al 1.5 del archivo evidencias/01-clasificacion.pdf.
7. **¿Qué conclusión se obtiene?** Que quitar el nombre no basta para proteger a una persona porque varios datos que parecen inofensivos también la identifican si se juntan. Por eso en las siguientes actividades se aplican enmascaramiento, seudonimización, anonimización y una regla de retención.

## 2. Enmascaramiento

Script: [sql/02-enmascaramiento.sql](sql/02-enmascaramiento.sql) · Evidencias: [evidencias/02-enmascaramiento.pdf](evidencias/02-enmascaramiento.pdf)

### 2.1 Preguntas

1. **¿Qué información continúa existiendo en la tabla original?** Toda, la vista no cambia ni borra nada, la tabla clientes sigue guardando el nombre, correo, teléfono y RFC completos. Lo único que cambia es lo que muestra al consultar la vista.
2. **¿Qué información puede visualizar el usuario soporte?** Solo lo que muestra la vista: el id y el nombre completos, las dos primeras letras del correo con su dominio, los últimos cuatro dígitos del teléfono y los últimos cuatro caracteres del RFC. La edad, la ciudad, el código postal y la fecha de alta no los ve porque la vista no los incluye.
3. **¿Por qué no es suficiente ocultar los datos únicamente en la aplicación?** Porque en la base los datos seguirían completos y cualquie persona que la consulte por otro medio, como psql, u otra aplicación, los vería sin ocultar. Si se ocultan en la base con una vista y permisos, la protección aplica sin importar desde dónde se consulte.
4. **¿Qué ocurriría si soporte tuviera acceso directo a clientes?** Podría consultar la tabla y ver todos los datos completos, y la vista ya no serviría de nada. Por eso se le quitaron los permisos sobre clientes, y al intentar consultarla aparece el error permission denied.

### 2.2 Qué se ocultó, para quién, por qué y cómo

Se ocultó parte del correo, del teléfono y del RFC de los clientes para el área de soporte. Soporte necesita identificar al cliente para atenderlo, pero no necesita ver esos datos completos, y entre menos personas los vean, menor es el riesgo de que se filtren o se usen mal. El mecanismo fue una vista, v_clientes_soporte, que muestra esos datos con asteriscos usando funciones de texto, y un rol soporte sin inicio de sesión que solo tiene permiso de leer la vista y ningún permiso sobre la tabla clientes. La vista consulta la tabla con los permisos de su dueño, por eso soporte puede usarla aunque no tenga acceso a la tabla.

### 2.3 Resumen de la actividad

1. **¿Cuál era el problema?** El área de soporte necesita consultar a los clientes, pero no debe ver completos su correo, teléfono y RFC.
2. **¿Qué riesgo o necesidad se identificó?** Que soporte tuviera acceso a datos que no necesita para su trabajo y que esos datos se pudieran filtrar o usar mal.
3. **¿Qué decisión se tomó?** Darle a soporte una vista con esos datos parcialmente ocultos y quitarle el acceso directo a la tabla.
4. **¿Qué configuración o implementación se realizó?** Se creó el rol soporte sin inicio de sesión y la vista v_clientes_soporte, se le dio permiso de usar el esquema public y de leer la vista, y se le quitaron todos los permisos sobre clientes. Todo está en sql/02-enmascaramiento.sql.
5. **¿Cómo se verificó?** Consultando los permisos del rol y actuando como soporte con SET ROLE: la vista mostró los datos enmascarados y la consulta a clientes fue rechazada.
6. **¿Qué evidencia demuestra el resultado?** Las capturas 2.1 a 2.6 del archivo evidencias/02-enmascaramiento.pdf.
7. **¿Qué conclusión se obtiene?** Que el enmascaramiento sirve si se hace en la base de datos y va junto con los permisos: la vista oculta los datos y los permisos evitan que soporte se la salte consultando la tabla directamente.

## 3. Seudonimización

Script: [sql/03-seudonimizacion.sql](sql/03-seudonimizacion.sql) · Evidencias: [evidencias/03-seudonimizacion.pdf](evidencias/03-seudonimizacion.pdf)

### 3.1 Tokens, mapa de correspondencia y permisos

Los tokens se generaron con la función gen_random_uuid(), que crea un identificador aleatorio de 36 caracteres para cada cliente. El token no sale de ningún dato del cliente, así que viéndolo no se puede saber a quién pertenece. La guía pide habilitar la extensión pgcrypto para usarla, aunque en PostgreSQL 16 esa función ya viene incluida.

La relación entre cada token y el id del cliente quedó en la tabla pii.mapa_cliente, dentro del esquema pii, separada de la tabla analitica.clientes que usa el área de analítica. Ese mapa es lo único que permite saber de quién es cada token, por eso solo debería consultarlo el personal autorizado, como el administrador de la base, y nunca el área de analítica.

Los permisos se separaron porque si la misma persona pudiera ver los datos seudonimizados y el mapa, podría volver a identificar a todos los clientes y la seudonimización no serviría de nada.

### 3.2 Resumen de la actividad

1. **¿Cuál era el problema?** El área de analítica necesita estudiar la información de los clientes, pero no necesita saber quién es cada uno.
2. **¿Qué riesgo o necesidad se identificó?** Que analítica trabajara con el nombre, el correo, el teléfono y el RFC de los clientes sin necesitarlos, y que esos datos se pudieran filtrar.
3. **¿Qué decisión se tomó?** Sustituir el identificador de cada cliente por un token aleatorio y guardar la relación entre el token y el cliente en un esquema aparte.
4. **¿Qué configuración o implementación se realizó?** Se crearon los esquemas pii y analitica, la tabla pii.mapa_cliente con un token para cada cliente y la tabla analitica.clientes con el token, la edad, la ciudad, el código postal y la fecha de alta. Todo está en sql/03-seudonimizacion.sql.
5. **¿Cómo se verificó?** Consultando el mapa, que tiene un token distinto para cada uno de los cinco clientes, y la tabla analitica.clientes, que no tiene nombre, correo, teléfono ni RFC.
6. **¿Qué evidencia demuestra el resultado?** Las capturas 3.1 a 3.3 del archivo evidencias/03-seudonimizacion.pdf.
7. **¿Qué conclusión se obtiene?** Que con la seudonimización analítica puede trabajar con los datos sin ver quién es cada cliente, pero la identidad se puede recuperar con el mapa, por eso el mapa se tiene que proteger por separado.

## 4. Separación de funciones

Script: [sql/03-seudonimizacion.sql](sql/03-seudonimizacion.sql) · Evidencias: [evidencias/03-seudonimizacion.pdf](evidencias/03-seudonimizacion.pdf)

### 4.1 Preguntas

1. **¿Qué ocurriría si analista pudiera consultar también pii.mapa_cliente?** Podría saber a qué cliente pertenece cada fila de analitica.clientes, porque el mapa relaciona cada token con el id del cliente, y ese id es el que lleva a su nombre, correo, teléfono y RFC. La seudonimización ya no protegería nada.
2. **¿Qué principio de seguridad se está aplicando al separar ambos accesos?** La separación de funciones, junto con el mínimo privilegio: cada rol tiene solo el acceso que necesita para su trabajo. Analítica tiene los datos para estudiarlos, pero no el mapa, y el mapa queda solo para quien está autorizado a volver a identificar a un cliente.
3. **¿Por qué la seudonimización no equivale a anonimización?** Porque la identidad no se elimina, solo se guarda aparte, y con el mapa se puede volver a saber de quién es cada dato. En la anonimización ya no hay forma de saberlo. Además, en analitica.clientes siguen la edad, la ciudad y el código postal, que juntos pueden identificar a un cliente, como se vio en la Actividad 1.
4. **¿Qué información permite volver a relacionar el token con una persona?** La tabla pii.mapa_cliente, que relaciona cada token con el id del cliente. Con ese id se encuentran sus datos completos en la tabla clientes, por eso el mapa se guardó en un esquema al que analista no tiene acceso.

### 4.2 Resumen de la actividad

1. **¿Cuál era el problema?** Si la misma persona puede ver los datos seudonimizados y el mapa, puede volver a identificar a los clientes.
2. **¿Qué riesgo o necesidad se identificó?** Que el área de analítica tuviera acceso al mapa o a la tabla clientes y pudiera recuperar la identidad de los clientes.
3. **¿Qué decisión se tomó?** Darle a analítica un rol que solo pueda leer el conjunto seudonimizado, sin acceso al mapa ni a los datos originales.
4. **¿Qué configuración o implementación se realizó?** Se creó el rol analista sin inicio de sesión, con permiso de usar el esquema analitica y de leer analitica.clientes, y sin ningún permiso sobre pii ni sobre clientes. Está en sql/03-seudonimizacion.sql.
5. **¿Cómo se verificó?** Consultando los permisos del rol y actuando como analista con SET ROLE: la consulta a analitica.clientes funcionó y las otras dos fueron rechazadas, la de pii.mapa_cliente porque analista no tiene permiso sobre el esquema pii y la de public.clientes porque no tiene permiso sobre la tabla. Después, como postgres, se comprobó que solo uniendo el mapa con clientes se llega al nombre de cada cliente.
6. **¿Qué evidencia demuestra el resultado?** Las capturas 4.1 a 4.4 del archivo evidencias/03-seudonimizacion.pdf.
7. **¿Qué conclusión se obtiene?** Que la seudonimización solo protege si el mapa y el conjunto de datos están separados y los consultan roles distintos. Con estos permisos analítica puede hacer su trabajo sin poder saber quién es cada cliente.

## 5. Anonimización

Script: [sql/04-anonimizacion.sql](sql/04-anonimizacion.sql) · Evidencias: [evidencias/04-anonimizacion.pdf](evidencias/04-anonimizacion.pdf)

### 5.1 Identificadores eliminados, atributos generalizados y grupos suprimidos

Las consultas no muestran ningún identificador directo: no aparecen el nombre, el correo, el teléfono ni el RFC, y tampoco el id. Solo muestran cuántos clientes hay en cada grupo.

Se generalizaron dos atributos: la edad, que se cambió por rangos (18-30, 31-45 y 46+), y el código postal, del que solo se dejaron los dos primeros dígitos como región. Al combinarlos quedaron tres grupos: uno de 3 clientes (31-45 en la región 80) y dos de un solo cliente (31-45 en la región 81 y 46+ en la región 82).

Con el umbral de k = 5 se suprimieron los tres grupos, porque ninguno llegaba a cinco clientes, y la consulta 12.4 no devolvió ninguna fila.

El riesgo de reidentificación no desaparece. Antes de suprimir, los grupos de un solo cliente señalaban a una persona. Además, con tan pocos registros, quien conozca a los clientes por otro medio podría deducir quién está en cada grupo, y si se agregan otros atributos, como la ciudad o la fecha de alta, los grupos vuelven a hacerse más pequeños.

### 5.2 Resumen de la actividad

1. **¿Cuál era el problema?** La dirección necesita información estadística de los clientes, pero no necesita conocerlos uno por uno.
2. **¿Qué riesgo o necesidad se identificó?** Que aun sin nombre, correo, teléfono ni RFC se pudiera reconocer a un cliente por su edad y su código postal, sobre todo en los grupos con muy pocos registros.
3. **¿Qué decisión se tomó?** Mostrar solo totales por grupo, generalizar la edad y el código postal, y suprimir los grupos con menos de cinco clientes.
4. **¿Qué configuración o implementación se realizó?** Cuatro consultas: CASE para los rangos de edad, LEFT para la región, GROUP BY para agrupar y HAVING para suprimir los grupos pequeños. Están en sql/04-anonimizacion.sql.
5. **¿Cómo se verificó?** Comparando los resultados de cada consulta: al combinar edad y región quedaron grupos de 3, 1 y 1 clientes, y con el umbral de cinco la consulta no devolvió ningún grupo.
6. **¿Qué evidencia demuestra el resultado?** Las capturas 5.1 a 5.4 del archivo evidencias/04-anonimizacion.pdf.
7. **¿Qué conclusión se obtiene?** Que generalizar ayuda, pero con pocos registros no basta: si los grupos son muy pequeños hay que suprimirlos, aunque eso deje sin información útil, como pasó aquí.

## 6. Análisis del riesgo de reidentificación

Script: [sql/04-anonimizacion.sql](sql/04-anonimizacion.sql) · Evidencias: [evidencias/04-anonimizacion.pdf](evidencias/04-anonimizacion.pdf)

### 6.1 Preguntas

1. **¿Qué identificadores directos fueron eliminados?** El nombre, el correo, el teléfono y el RFC. Tampoco se muestra el id, porque las consultas solo devuelven totales por grupo.
2. **¿Qué cuasi-identificadores permanecen?** La edad y el código postal, aunque generalizados como rango de edad y región.
3. **¿Qué combinaciones de atributos podrían reducir el anonimato?** La edad con el código postal, y más si se agregan la ciudad o la fecha de alta, porque entre más atributos se combinan, más pequeños quedan los grupos. En la Actividad 1 se vio que la edad, la ciudad y el código postal juntos distinguen a cada uno de los cinco clientes.
4. **¿Qué sucede cuando un grupo contiene pocos registros?** Que la persona se puede reconocer. En la consulta 12.3 quedaron dos grupos de un solo cliente: quien sepa que alguien de más de 45 años con código postal 82 es cliente sabe que ese registro es el suyo, y cualquier dato que se publique de ese grupo es información de esa persona. Por eso esos grupos se suprimen.
5. **¿Qué atributos deberían generalizarse?** La edad, en rangos más amplios, y el código postal, dejando menos dígitos. Si se usaran la ciudad o la fecha de alta también habría que generalizarlas, por ejemplo la ciudad por región y la fecha por año.
6. **¿Qué información debería suprimirse?** Los identificadores directos y los grupos que no lleguen al umbral de cinco registros. Con estos datos fueron todos los grupos de la consulta 12.4.
7. **¿Es correcto afirmar que el conjunto de datos es «100 % anónimo»? ¿Por qué?** No. Cumplir con k = 5 reduce el riesgo, pero no lo elimina: alguien que conozca a los clientes por otro medio o que cruce estos datos con otra información podría reidentificar a alguien. La guía también aclara que hay que revisar otros atributos y sus combinaciones, y entre menos registros hay, más fácil es reconocer a una persona.

### 6.2 Reto

- **Cambio realizado:** Se usaron rangos de edad más amplios (18-29, 30-49 y 50+), se dejó solo el primer dígito del código postal (8xxxx) y se agregó la categoría «sin dato» para edades vacías o menores de 18, que en la consulta original se contarían como 46+.
- **Motivo:** Con los rangos y regiones de la guía ningún grupo llegaba a cinco clientes, y dos grupos tenían un solo cliente.
- **Resultado obtenido:** Un solo grupo, 30-49 en la zona 8xxxx, con los cinco clientes, que sí cumple el umbral de k = 5. A cambio, el resultado dice menos: solo que hay cinco clientes de 30 a 49 años en la zona 8.
- **Riesgo que se pretende reducir:** La reidentificación por la combinación de edad y código postal: ahora cada cliente se confunde con los otros cuatro.

### 6.3 Resumen de la actividad

1. **¿Cuál era el problema?** Aun sin los identificadores directos, había grupos tan pequeños que permitían reconocer a un cliente.
2. **¿Qué riesgo o necesidad se identificó?** La reidentificación de un cliente por la combinación de su rango de edad y su región.
3. **¿Qué decisión se tomó?** Generalizar más la edad y el código postal hasta que los grupos cumplieran el umbral de cinco clientes.
4. **¿Qué configuración o implementación se realizó?** Se modificó la consulta 12.4 con rangos de edad más amplios, la zona postal de un dígito y una categoría para edades vacías. Está al final de sql/04-anonimizacion.sql.
5. **¿Cómo se verificó?** La consulta del reto devolvió un solo grupo con los cinco clientes, que cumple el umbral.
6. **¿Qué evidencia demuestra el resultado?** La captura 6.1 del archivo evidencias/04-anonimizacion.pdf, junto con la 5.3 y la 5.4, que muestran el problema.
7. **¿Qué conclusión se obtiene?** Que hay que equilibrar privacidad y utilidad: entre más se generaliza menos riesgo hay, pero también se pierde detalle, y ningún umbral garantiza por sí solo que los datos sean 100 % anónimos.

## 7. Retención de datos

Script: [sql/05-retencion.sql](sql/05-retencion.sql) · Evidencias: [evidencias/05-retencion.pdf](evidencias/05-retencion.pdf)

### 7.1 Registros afectados y procedimiento antes de eliminar

1. **¿Qué registros serían afectados?** Los clientes con una fecha_alta anterior a la fecha de hoy menos cinco años. El 15/10/2026 ese límite es el 15/10/2021, y la consulta no devolvió ningún registro porque los cinco clientes se dieron de alta el 14/10/2026. Cada registro se conserva hasta el 14/10/2031; a partir del día siguiente aparecería en la consulta.
2. **¿Cuál sería la justificación del periodo?** En el ejercicio, los cinco años los fija la guía. En una empresa real el plazo debe salir de una obligación legal o de la finalidad para la que se recabaron los datos. Por ejemplo, el artículo 30 del Código Fiscal de la Federación obliga a conservar la contabilidad y su documentación durante cinco años, contados desde que se presentaron las declaraciones relacionadas; si los datos de un cliente forman parte de esa documentación, como en sus facturas, no se pueden eliminar antes. Por otro lado, el artículo 10 de la Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP), publicada en el Diario Oficial de la Federación (DOF) el 20 de marzo de 2025, establece que los datos que dejan de ser necesarios para las finalidades del aviso de privacidad deben suprimirse, previo bloqueo en su caso, cuando concluye su plazo de conservación. Es decir, los datos se conservan mientras haya una razón para tenerlos, y después se eliminan.
3. **¿Qué aprobación debería existir antes de eliminar información?** Una autorización por escrito del área dueña de los datos, por ejemplo ventas, y de la persona o el área encargada de la protección de datos, después de que el área legal o contable confirme que ya no hay obligación de conservarlos. Quien ejecuta el borrado no debería ser quien lo autoriza.
4. **¿Qué respaldo debería existir?** Un respaldo completo de la base, tomado justo antes de eliminar, comprobado (que sí se pueda restaurar) y guardado con acceso restringido. Ese respaldo también contiene datos personales, así que necesita su propio plazo: si se guarda para siempre, los datos eliminados siguen existiendo en él.
5. **¿Qué evidencia debería conservarse?** Un registro de la eliminación: la fecha, la consulta que identificó los registros, cuántos se eliminaron y cuáles (solo por su id, sin los datos personales), quién lo autorizó, quién lo ejecutó y qué respaldo se tomó antes.
6. **¿Qué procedimiento permitiría recuperar información eliminada accidentalmente?** Hacer el borrado dentro de una transacción (BEGIN … COMMIT): antes de confirmarlo, se compara el número de registros eliminados con los que identificó la consulta y, si no coinciden, se deshace con ROLLBACK. Si el error se descubre después de confirmarlo, se restaura el respaldo en una base aparte, no encima de la original, y de ahí se recuperan solo los registros borrados por error. La guía indica que la eliminación se trabajará en las prácticas de respaldo y recuperación.

### 7.2 Criterio, qué conservar, qué eliminar y controles

- **Criterio utilizado:** Un periodo de cinco años contado desde la fecha_alta: un registro lo supera cuando su fecha_alta es anterior a CURRENT_DATE - INTERVAL '5 years'. Es una simplificación del ejercicio. En la práctica el plazo debería contarse desde la última operación con el cliente o desde que termina la relación con él, porque un cliente que sigue comprando no debería eliminarse solo porque se registró hace cinco años. La tabla no tiene ese dato, por eso se usó fecha_alta.
- **Qué información debería conservarse:** La de los clientes activos y la que todavía tenga una obligación legal, como la documentación fiscal durante sus cinco años. Cuando los datos ya no se necesitan, pueden pasar primero por un bloqueo: según el artículo 2, fracción III, de la LFPDPPP, se conservan sin poder tratarse, solo para determinar posibles responsabilidades, hasta que estas prescriban, y después se eliminan. También se pueden conservar los resultados agregados, como el de la Actividad 6, porque no identifican a nadie.
- **Qué información podría eliminarse:** Los datos de los clientes que superen el periodo y no tengan ninguna obligación pendiente: nombre, correo, teléfono, RFC y el resto de su registro. También sus copias: su token en pii.mapa_cliente y su fila en analitica.clientes, que es una copia hecha con CREATE TABLE AS y no se actualiza sola. Además, el orden importa: la llave foránea del mapa hacia clientes impide borrar a un cliente mientras su token siga en pii.mapa_cliente.
- **Controles antes de eliminar:** La aprobación por escrito, un respaldo comprobado, revisar la lista que devuelve la consulta antes de borrar, hacer el borrado dentro de una transacción comparando el número de registros, que solo un rol designado pueda borrar (ni soporte ni analista tienen permiso de DELETE) y dejar el registro de la eliminación.

### 7.3 Resumen de la actividad

1. **¿Cuál era el problema?** La empresa guarda los datos de sus clientes sin un límite de tiempo.
2. **¿Qué riesgo o necesidad se identificó?** Conservar datos personales más tiempo del necesario: entre más datos y más tiempo se guardan, más se expone en una filtración o un mal uso. Al mismo tiempo, borrar sin control podría eliminar información que la empresa todavía está obligada a conservar.
3. **¿Qué decisión se tomó?** Identificar con una consulta los registros que superan el periodo de cinco años, sin eliminarlos, y definir el procedimiento que debería seguirse antes de borrar.
4. **¿Qué configuración o implementación se realizó?** La consulta de la guía, que compara fecha_alta con CURRENT_DATE - INTERVAL '5 years', y dos consultas más que muestran la fecha límite de hoy y hasta cuándo se conserva cada registro. No se ejecutó ningún DELETE. Están en sql/05-retencion.sql.
5. **¿Cómo se verificó?** La consulta de la guía no devolvió registros, lo cual es correcto porque los cinco clientes se dieron de alta el 14/10/2026. Las otras dos consultas muestran que el límite de hoy es el 15/10/2021 y que cada registro se conserva hasta el 14/10/2031.
6. **¿Qué evidencia demuestra el resultado?** Las capturas 7.1 y 7.2 del archivo evidencias/05-retencion.pdf.
7. **¿Qué conclusión se obtiene?** Que identificar los datos que ya no deberían conservarse se resuelve con una consulta sencilla, pero eliminarlos requiere un procedimiento: un criterio justificado, aprobación, respaldo, evidencia y una forma de recuperar lo que se borre por error.

## 8. Verificación final

Script: [sql/05-retencion.sql](sql/05-retencion.sql), sección 15 al final del archivo · Evidencias: [evidencias/05-retencion.pdf](evidencias/05-retencion.pdf), Verificación 1 a 4

Al terminar el laboratorio se comprobaron los cuatro escenarios de la sección 15 de la guía. Todo se ejecutó como postgres, usando SET ROLE para actuar como soporte o como analista y RESET ROLE para regresar.

| Escenario | Qué pide la guía | Resultado | Evidencia |
|---|---|---|---|
| Área de soporte | Consultar v_clientes_soporte, pero no la tabla clientes | La vista devolvió los cinco clientes con el correo, el teléfono y el RFC enmascarados. La consulta a clientes fue rechazada: «permission denied for table clientes». | Verificación 1 |
| Área de analítica | Consultar analitica.clientes, pero no pii.mapa_cliente ni public.clientes | analitica.clientes devolvió los cinco registros con su token. El mapa fue rechazado («permission denied for schema pii») y la tabla original también («permission denied for table clientes»). | Verificación 2 |
| Información para dirección | Información agregada, sin identificadores directos | Un solo grupo: 30-49, zona 8xxxx, 5 clientes. No aparecen nombre, correo, teléfono, RFC ni id. | Verificación 3 |
| Retención | Una consulta que identifique los registros que exceden el periodo | La consulta existe y el 15/10/2026 devolvió 0 registros, porque ninguno tiene más de cinco años. | Verificación 4 |

Los cuatro escenarios se cumplen. Los tres accesos que debían rechazarse fueron rechazados por falta de permisos, y en las capturas se ven el intento y el mensaje de error, como pide la sección 18 de la guía.

## 9. Conclusiones

1. **¿Qué técnica utilizarías para un área de soporte?** El enmascaramiento con una vista. Soporte necesita reconocer al cliente que lo contacta, por ejemplo por su nombre y los últimos dígitos de su teléfono, pero no necesita ver completos el correo, el teléfono ni el RFC. La vista le muestra solo eso, y el rol tiene permiso sobre la vista, no sobre la tabla.
2. **¿Qué técnica utilizarías para un área de analítica?** La seudonimización. Analítica necesita trabajar con registros individuales, por ejemplo para relacionar varios datos de un mismo cliente mediante su token, pero no necesita saber quién es. Eso funciona mientras el mapa esté en un esquema al que analítica no tenga acceso.
3. **¿Qué técnica utilizarías para publicar estadísticas?** La anonimización: totales por grupo, con los cuasi-identificadores generalizados y suprimiendo los grupos que no lleguen al umbral, como en la Actividad 6. Lo que se publica sale del control de la empresa y ya no se puede proteger con permisos, así que no debe permitir reconocer a nadie.
4. **¿Por qué ninguna de estas técnicas sustituye al control de acceso?** Porque las tres protegen una forma de mostrar o de copiar los datos, pero los datos originales siguen completos en la tabla clientes. El enmascaramiento sirve porque soporte no tiene permiso sobre clientes: si lo tuviera, consultaría la tabla y lo vería todo. La seudonimización sirve porque analista no tiene acceso a pii.mapa_cliente. Las técnicas deciden qué ve cada rol, y el control de acceso impide que se las salte; los errores de permisos de la verificación final lo demuestran.

## 10. Preguntas de reflexión

1. **¿Cuál es la diferencia entre enmascaramiento y seudonimización?** El enmascaramiento oculta parte de un dato al mostrarlo, como el correo an*****@example.test; el dato original no cambia en la tabla, solo cambia lo que ve quien consulta la vista. La seudonimización reemplaza al identificador por un token y guarda aparte, en el mapa, a quién corresponde cada token: sirve para trabajar con los datos sin saber de quién son, y solo con el mapa se puede volver a saberlo.
2. **¿Por qué la seudonimización no significa anonimización?** Porque se puede revertir: quien tenga el mapa sabe de quién es cada token. Además, en analitica.clientes siguen la edad, la ciudad y el código postal, que combinados pueden identificar a una persona. Los datos seudonimizados siguen siendo datos personales.
3. **¿Por qué eliminar nombre y RFC no garantiza que un conjunto de datos sea anónimo?** Porque otros datos pueden identificar a una persona si se combinan entre sí o se cruzan con información de otra fuente. En la Actividad 1 se vio que la edad, la ciudad y el código postal juntos distinguen a cada uno de los cinco clientes, aunque no aparezcan su nombre ni su RFC.
4. **¿Qué función tienen los cuasi-identificadores?** Son los datos que por sí solos no identifican a nadie, pero combinados entre sí o con información de otra fuente sí pueden hacerlo, como la edad, la ciudad o el código postal. Por eso son los que hay que revisar al anonimizar: se generalizan o se suprimen hasta que cada grupo tenga suficientes personas.
5. **¿Por qué es importante separar el mapa de seudonimización?** Porque el mapa es lo único que permite saber a quién pertenece cada token. Si estuviera junto a los datos seudonimizados, o si el mismo rol pudiera leer ambos, la seudonimización no protegería nada. Por eso está en el esquema pii, al que analista no tiene acceso.
6. **¿Qué principio de seguridad se aplica al impedir que el analista acceda al mapa?** El de mínimo privilegio, junto con la separación de funciones: el analista tiene solo el acceso que necesita para su trabajo, y la posibilidad de volver a identificar a un cliente queda en otro rol.
7. **¿Por qué una vista puede ser preferible a entregar acceso directo a la tabla?** Porque la vista muestra solo las columnas que el área necesita y en la forma en que las necesita, enmascaradas en el caso de soporte. El rol recibe permiso sobre la vista y no sobre la tabla; en PostgreSQL la vista consulta la tabla con los permisos de su dueño, así que soporte puede usarla sin tener acceso a clientes. Además, si después se agrega una columna sensible a la tabla, no aparece en la vista a menos que se modifique.
8. **¿Qué diferencia existe entre proteger un dato para visualización y protegerlo contra acceso no autorizado?** Protegerlo para visualización cambia cómo se le muestra el dato a alguien que sí puede consultarlo, como hace la vista de soporte, pero el dato original sigue completo en la tabla. Protegerlo contra acceso no autorizado significa que quien no debe verlo no pueda leerlo de ninguna forma, y eso lo dan los permisos, como muestran los errores «permission denied». El enmascaramiento sin control de acceso no protege, porque cualquiera con acceso a la tabla vería el dato completo.
9. **¿Por qué la retención forma parte de la protección de datos?** Porque un dato que ya no se conserva no se puede filtrar ni usar mal. Guardar los datos solo mientras se necesitan reduce lo que se expone, y la ley lo exige: el artículo 10 de la LFPDPPP indica que los datos que ya no son necesarios para sus finalidades deben suprimirse, previo bloqueo en su caso, cuando termina su plazo de conservación.
10. **¿Qué riesgo existe si una organización conserva información indefinidamente?** Que en una filtración se exponen también los datos de clientes que ya no tienen relación con la empresa, que se acumulan datos desactualizados y que crece el riesgo de usarlos para fines distintos de aquellos para los que se recabaron. Además, la empresa incumpliría la obligación de suprimir los datos que ya no necesita y tendría más copias y respaldos que proteger.

## Referencias

- Código Fiscal de la Federación, artículo 30. Texto vigente, última reforma publicada en el DOF el 9 de abril de 2026. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/CFF.pdf
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 y 10. Nueva ley publicada en el DOF el 20 de marzo de 2025, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf

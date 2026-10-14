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
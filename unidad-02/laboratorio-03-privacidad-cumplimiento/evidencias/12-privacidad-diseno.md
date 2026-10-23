# Evidencia 12 — Privacidad por diseño

LAB-03, Actividad 12 (sección 18 de la guía). Se analizó la tabla que propone el desarrollador y se probaron esa tabla y el diseño alternativo en `dba-ensayo`, el contenedor de práctica, dentro de una transacción que se deshizo con `ROLLBACK`. En `dba-practica` no se creó nada.

## Objetivo

Revisar la tabla `clientes` que un desarrollador propone para una aplicación nueva, con la justificación «Es mejor guardar todos los datos por si posteriormente necesitamos alguno», y proponer un diseño que aplique la privacidad desde el principio.

## Procedimiento

1. A cada campo se le hicieron las mismas preguntas que en la [evidencia 01](01-inventario-datos.md): qué proceso lo usa, si hace falta con ese detalle y quién debe verlo. Los procesos son los del escenario: Atención al cliente, Facturación y Analítica.
2. Los campos se compararon con la definición de datos sensibles (LFPDPPP, art. 2, fracción VI), con las reglas de consentimiento de los artículos 7 y 8 y con los datos del receptor que pide la factura electrónica, según el esquema del CFDI 4.0 del SAT.
3. En `dba-ensayo` se creó un esquema aparte, `ensayo12`, y ahí se probaron dos cosas:
   - la tabla del desarrollador, sin los «...», con renglones de prueba;
   - el diseño propuesto, con sus restricciones y una vista para promociones.

   Todo se hizo con datos ficticios (`Cliente Prueba`, `uno@example.test`) y dentro de un `BEGIN … ROLLBACK`. Al final, una consulta a `information_schema.schemata` confirmó que el esquema ya no existía.

## Resultado

### Lo que acepta la tabla del desarrollador

Se insertaron cuatro renglones que una base de clientes no debería aceptar:

```sql
INSERT INTO clientes_dev (nombre, correo, edad, fecha_nacimiento)
VALUES ('Cliente Prueba', 'prueba@example.test', 41, DATE '1990-01-01'),
       ('Cliente Prueba', 'prueba@example.test', 41, DATE '1990-01-01');
INSERT INTO clientes_dev (nombre, correo) VALUES (NULL, NULL);
INSERT INTO clientes_dev (id, nombre) VALUES (1, 'Otro cliente con el id 1');
```

La tabla los aceptó todos:

```text
 id |          nombre          |       correo        | edad | fecha_nacimiento
----+--------------------------+---------------------+------+------------------
  1 | Cliente Prueba           | prueba@example.test |   41 | 1990-01-01
  1 | Otro cliente con el id 1 |                     |      |
  2 | Cliente Prueba           | prueba@example.test |   41 | 1990-01-01
  3 |                          |                     |      |
(4 rows)
```

- El mismo cliente quedó dos veces.
- Quedó un cliente sin nombre y sin correo.
- Hay dos renglones con el id 1: `BIGSERIAL` crea una secuencia, pero sin `PRIMARY KEY` no impide los repetidos.
- La edad dice 41 y la fecha de nacimiento dice que en 2026 tiene 36. La tabla guarda las dos sin notar la contradicción.

### 1. ¿Qué problemas identificas?

| Problema | En la tabla propuesta |
| --- | --- |
| Ningún campo tiene finalidad | La justificación es «por si acaso»: primero se guarda y después se busca para qué. |
| Hay datos que ningún proceso usa | Ni Atención al cliente, ni Facturación, ni Analítica usan la dirección, la ocupación, el salario o el estado civil. |
| La misma información está varias veces | La edad sale de tres campos: `edad`, `fecha_nacimiento` y el RFC, que trae la fecha de nacimiento. La ubicación también está tres veces: dirección, ciudad y código postal. Cada copia es una más que rectificar, proteger y borrar. |
| Hay datos que caducan o se contradicen | La edad se desactualiza cada año (evidencia 01), y la prueba mostró que puede contradecir a la fecha de nacimiento. |
| Todo está en una sola tabla | Quien pueda leerla ve el RFC y el salario de todos junto a sus datos de contacto. Para dar a cada área solo lo suyo habría que armar vistas sobre una tabla que lo junta todo. |
| No hay restricciones | Sin llave primaria, sin `NOT NULL` y todo en `TEXT`, la tabla acepta clientes repetidos y vacíos. Para atender un derecho ARCO habría que encontrar todos los duplicados de una persona. |
| No hay ciclo de vida | Ningún campo dice si la persona sigue siendo cliente, cuándo dejó de serlo, si sus datos están bloqueados ni qué finalidades aceptó. Sin eso no se puede aplicar la retención (evidencia 10). |
| La lista está abierta | Los «...» permiten agregar cualquier campo sin justificarlo, incluso datos sensibles, y no se puede crear una base con datos sensibles sin una finalidad legítima y concreta (art. 8). |
| El RFC se pide a todos | Solo lo necesitan los clientes que piden factura. |

### 2. ¿Qué principio de privacidad se está ignorando?

La **minimización**: tratar solo los datos adecuados, relevantes y necesarios para una finalidad determinada (guía, sección 4). En la LFPDPPP corresponde al principio de proporcionalidad (art. 5): el tratamiento debe ser el necesario, adecuado y relevante para las finalidades del aviso de privacidad (art. 12). «Por si acaso» invierte la regla: la ley parte de la finalidad para decidir los datos, y el diseño parte de los datos y deja la finalidad para después.

Con ella se ignoran otros dos principios del artículo 5:

- **Finalidad.** Un dato sin finalidad no se puede incluir en el aviso de privacidad, y si después aparece un uso, será una finalidad nueva que necesita otra vez el consentimiento (art. 11).
- **Calidad.** Los datos deben ser exactos y estar actualizados (art. 10), y la tabla acepta edades que caducan y fechas que se contradicen.

La guía también lo plantea como privacidad por diseño (sección 4): las consideraciones de privacidad se incorporan desde el diseño de la base, no después.

### 3. ¿Qué preguntas realizarías antes de aprobar el diseño?

| Pregunta | Por qué |
| --- | --- |
| ¿Qué proceso usa cada campo y para qué? | Sin una finalidad no hay razón para el campo (art. 12). |
| ¿Esa finalidad está en el aviso de privacidad? | El aviso debe decir qué datos se tratan y para qué (art. 15, fracciones II y III). |
| ¿Basta un dato menos detallado? | El año en lugar de la fecha, el rango en lugar de la edad, la ciudad en lugar de la dirección. |
| ¿Es obligatorio u opcional para el cliente? | Lo opcional no se pide desde el primer formulario. |
| ¿Hay datos financieros, patrimoniales o sensibles? | Los financieros necesitan consentimiento expreso (art. 7), y los sensibles, expreso y por escrito (art. 8). |
| ¿Quién lo va a consultar? | Con eso se definen los roles y las vistas desde el principio (evidencia 11). |
| ¿Cuánto tiempo se conserva y qué evento inicia el conteo? | Si ningún campo registra ese evento, el plazo no se puede aplicar (evidencia 10). |
| ¿Cómo se atenderán los derechos ARCO? | Hay que poder encontrar, corregir, bloquear y suprimir a una persona (Actividades 6 a 9). |
| ¿Qué incluyen los «...»? | No se aprueba una lista abierta. |
| ¿Dónde habrá copias? | Desarrollo, respaldos, reportes y exportaciones también guardan los datos (evidencia 08). |

### 4. ¿Qué datos eliminarías?

| Campo | Decisión | Motivo |
| --- | --- | --- |
| edad | Eliminar | Caduca y puede contradecir a la fecha de nacimiento. Para los rangos basta el año de nacimiento. |
| fecha_nacimiento | Cambiar por el año de nacimiento, opcional | Las estadísticas solo piden el rango. La fecha exacta es más precisa de lo necesario y, junto con la ciudad o el código postal, ayuda a señalar a una persona (LAB-01). |
| direccion | Eliminar | Ningún proceso la usa, y la factura solo pide el código postal fiscal. Si después hubiera envíos a domicilio, se justificaría para esa finalidad. |
| ocupacion | Eliminar | No tiene finalidad. |
| salario | Eliminar | No tiene finalidad, es un dato financiero (art. 7) y su exposición es de las más dañinas. |
| estado_civil | Eliminar | No tiene finalidad. |
| rfc | Mover a una tabla de datos fiscales | Solo de los clientes que piden factura. |
| codigo_postal | Mover a la tabla de datos fiscales | La factura pide el del domicilio fiscal. Para las estadísticas basta la ciudad. |
| «...» | Eliminar | Cada campo nuevo debe llegar con su finalidad. |

Se quedan `nombre` y `correo`, obligatorios para atender al cliente, y `telefono`, `ciudad` y el año de nacimiento, opcionales.

### 5. ¿Qué datos requerirían una justificación adicional?

- **salario.** Es un dato financiero o patrimonial, que requiere consentimiento expreso (art. 7). Si algún día se pidiera, por ejemplo para evaluar un crédito, sería una finalidad nueva con su propio consentimiento.
- **rfc.** Es un identificador fiscal único y además trae la fecha de nacimiento. Se justifica solo para facturar, y solo de quien lo pide.
- **fecha_nacimiento exacta.** Solo si alguna finalidad necesita el día exacto. Si solo hubiera que comprobar que el cliente es mayor de edad, bastaría con registrar que se comprobó.
- **direccion.** Solo si hubiera envíos a domicilio.
- **ocupacion y estado_civil.** No aparecen entre los ejemplos de datos sensibles del artículo 2, fracción VI, aunque esa lista no es cerrada. Aun así hablan de la vida privada de la persona, así que necesitarían una finalidad concreta y declarada.
- **Cualquier dato sensible** que se quisiera agregar en los «...», como salud, creencias u origen étnico: consentimiento expreso y por escrito, y una finalidad legítima y concreta para crear siquiera la base (art. 8).

### 6. ¿Cómo aplicarías privacidad por defecto?

Privacidad por defecto es que la configuración inicial del sistema limite la exposición y el tratamiento de los datos al mínimo necesario (guía, sección 4). El diseño propuesto separa los datos en tres tablas y una vista:

```sql
CREATE TABLE clientes (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre             VARCHAR(120) NOT NULL,
    correo             VARCHAR(150) NOT NULL UNIQUE,
    telefono           VARCHAR(20),
    anio_nacimiento    SMALLINT CHECK (anio_nacimiento >= 1900),
    ciudad             VARCHAR(80),
    estatus            VARCHAR(10) NOT NULL DEFAULT 'activo'
                       CHECK (estatus IN ('activo', 'baja', 'bloqueado')),
    fecha_alta         DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin_relacion DATE,
    fecha_bloqueo      DATE,
    CONSTRAINT baja_con_fecha CHECK (estatus = 'activo' OR fecha_fin_relacion IS NOT NULL),
    CONSTRAINT bloqueo_con_fecha CHECK (estatus <> 'bloqueado' OR fecha_bloqueo IS NOT NULL)
);

CREATE TABLE datos_fiscales (
    cliente_id     BIGINT PRIMARY KEY REFERENCES clientes (id),
    rfc            VARCHAR(13) NOT NULL,
    nombre_fiscal  VARCHAR(300) NOT NULL,
    codigo_postal  CHAR(5) NOT NULL,
    regimen_fiscal CHAR(3) NOT NULL
);

CREATE TABLE consentimientos (
    cliente_id     BIGINT NOT NULL REFERENCES clientes (id),
    finalidad      VARCHAR(30) NOT NULL,
    fecha_otorgado TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_revocado TIMESTAMPTZ,
    PRIMARY KEY (cliente_id, finalidad)
);

CREATE VIEW v_promociones AS
SELECT c.id, c.nombre, c.correo
FROM clientes c
JOIN consentimientos k ON k.cliente_id = c.id
WHERE k.finalidad = 'promociones'
  AND k.fecha_revocado IS NULL
  AND c.estatus = 'activo';
```

Lo que queda limitado desde el inicio:

- **Solo dos datos obligatorios.** `nombre` y `correo` son `NOT NULL`; el teléfono, el año de nacimiento y la ciudad son opcionales.
- **Los datos fiscales, solo con factura.** `datos_fiscales` guarda lo que el CFDI 4.0 pide del receptor y no cambia de una factura a otra: RFC, nombre tal como está inscrito en el RFC (hasta 300 caracteres en el esquema del SAT), código postal del domicilio fiscal (5 caracteres) y clave del régimen fiscal (de 3 dígitos en el catálogo del SAT). El uso del CFDI no se guarda, porque se indica en cada factura. El RFC se puede cifrar como en el LAB-02.
- **Las promociones, apagadas.** Si un cliente no tiene renglón en `consentimientos`, no aparece en `v_promociones`; para retirar el consentimiento se llena `fecha_revocado`. Es el registro de consentimiento por finalidad que pedía la evidencia 05.
- **El ciclo de vida, registrado.** `estatus`, `fecha_fin_relacion` y `fecha_bloqueo` son los campos que les faltaban a la retención (evidencias 01 y 10) y al bloqueo (evidencia 08). Las dos restricciones con nombre impiden dar de baja a un cliente sin fecha de fin o bloquearlo sin fecha de bloqueo.
- **La edad, calculada al consultar.** El año de nacimiento no caduca: el rango se calcula con el año en curso, con un margen de un año porque no se sabe si ya cumplió.
- **Sin duplicados.** La llave primaria la genera la base, y el correo no se puede repetir.
- **Sin permisos para nadie.** PostgreSQL no da privilegios a PUBLIC sobre las tablas nuevas (manual de PostgreSQL 16, sección 5.7). Cada área recibe después solo su vista (evidencia 11).

**Prueba del diseño.** Se cargaron tres clientes ficticios: el primero aceptó promociones, el segundo las aceptó y luego retiró su consentimiento, y el tercero nunca las aceptó. `v_promociones` devolvió solo al primero. Luego se intentaron cinco cambios que el diseño debe rechazar, y la base los rechazó todos:

```text
ERROR:  duplicate key value violates unique constraint "clientes_correo_key"
ERROR:  cannot insert a non-DEFAULT value into column "id"
ERROR:  new row for relation "clientes" violates check constraint "baja_con_fecha"
ERROR:  new row for relation "clientes" violates check constraint "bloqueo_con_fecha"
ERROR:  insert or update on table "datos_fiscales" violates foreign key constraint "datos_fiscales_cliente_id_fkey"
```

En orden: un correo repetido, un id escrito a mano, una baja sin fecha de fin, un bloqueo sin fecha de bloqueo y datos fiscales de un cliente que no existe. Después, al dar de baja al primer cliente con su fecha de fin, `v_promociones` quedó vacía: la baja lo sacó de las promociones sin tocar su consentimiento. El rango de edad calculado con el año de nacimiento dio 30-44 para 1985 y 1990, y «Sin dato» para quien no lo dio. Por último, `information_schema.role_table_grants` no mostró permisos sobre las tablas nuevas para ningún rol distinto de `postgres`.

## Análisis

1. **«Por si acaso» tiene costo.** Cada campo de más es algo más que proteger, rectificar, borrar y explicar en el aviso de privacidad. Algunos, como el salario, hacen mucho más grave una fuga.
2. **Diseñar con privacidad es más barato al principio.** Agregar después el estatus o el consentimiento obliga a migrar datos, y hay historia que ya no se puede reconstruir: nadie sabrá quién aceptó promociones ni cuándo si nunca se registró.
3. **La calidad de los datos también protege la privacidad.** La llave primaria, el `UNIQUE` y los `CHECK` no solo cuidan la integridad: hacen que cada persona tenga un solo renglón y que cada estado tenga su fecha. Así se puede responder un derecho ARCO y aplicar un plazo.
4. **Separar por finalidad simplifica los permisos.** Con los datos fiscales en su tabla, darle acceso solo a Facturación es un `GRANT` sobre esa tabla o su vista, en lugar de enmascarar columnas de una tabla que lo junta todo.
5. **El DBA revisa y propone; no aprueba.** Le toca hacer estas preguntas, señalar los riesgos y proponer alternativas, pero decidir qué finalidades tiene la aplicación les corresponde al propietario de los datos y al responsable de privacidad.

## Conclusión

La tabla propuesta guarda datos sin finalidad, repite información, acepta datos contradictorios y no tiene forma de saber quién sigue siendo cliente ni qué aceptó. Ignora sobre todo la minimización, que en la LFPDPPP es la proporcionalidad. El diseño alternativo pide solo nombre y correo, guarda los datos fiscales solo de quien factura, deja las promociones apagadas hasta que el cliente acepte y registra el ciclo de vida que necesitan la retención y los derechos ARCO. La prueba en `dba-ensayo` confirmó que la tabla original acepta duplicados, clientes vacíos y contradicciones, y que el diseño propuesto los rechaza.

## Referencias

- Guía del LAB-03, secciones 4 y 18; evidencias [01](01-inventario-datos.md), [05](05-finalidad-secundaria.md), [08](08-ciclo-vida.md), [10](10-retencion.md) y [11](11-gobierno-datos.md).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 (fracción VI), 5, 7, 8, 10, 11, 12 y 15. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- SAT, esquema del CFDI 4.0 (`cfdv40.xsd`), nodo Receptor: http://www.sat.gob.mx/sitio_internet/cfd/4/cfdv40.xsd, y catálogo `c_RegimenFiscal` (`catCFDI.xsd`): http://www.sat.gob.mx/sitio_internet/cfd/catalogos/catCFDI.xsd
- Manual de PostgreSQL 16, sección 5.7, «Privileges»: https://www.postgresql.org/docs/16/ddl-priv.html

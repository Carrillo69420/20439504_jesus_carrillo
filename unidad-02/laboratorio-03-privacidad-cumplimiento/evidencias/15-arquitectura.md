# Evidencia 15 — Propuesta de arquitectura de datos protegidos

LAB-03, Actividad 15 (sección 21 de la guía). Es una propuesta conceptual y no se implementó en la base, como permite la guía. Solo se ejecutó, en modo lectura, una consulta para probar el tamaño mínimo de grupo.

## Objetivo

Proponer cómo separar los datos de clientes según su finalidad (operación, analítica y auditoría) y qué controles aplicar en cada parte para el acceso, la minimización, la información más delicada, la retención, la trazabilidad, la eliminación y la atención de solicitudes.

## Procedimiento

1. Se partió del diagrama de la guía y se le pusieron los nombres de esta base: esquemas, tablas, vistas y roles.
2. Cada control salió de algo que se encontró en el laboratorio: el mapa de copias (evidencia 08), la política de retención (evidencia 10), la matriz de gobierno (evidencia 11), el diseño de la evidencia 12 y los riesgos de la evidencia 14.
3. Para el control de minimización en Analítica se comparó, en `dba-practica` y en modo lectura, la vista de la Actividad 4 agrupada con y sin un tamaño mínimo de grupo:

```sql
SELECT ciudad, rango_edad, COUNT(*) AS clientes
FROM v_analitica_clientes
GROUP BY ciudad, rango_edad
HAVING COUNT(*) >= 3
ORDER BY clientes DESC, ciudad;
```

## Resultado

### Diagrama

```text
                        BASE DE DATOS comercializadora
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
          ▼                           ▼                           ▼
      Operación                   Analítica                   Auditoría
  esquema operacion           esquema analitica           esquema auditoria
          │                           │                           │
          ▼                           ▼                           ▼
  Datos necesarios            Datos agregados             Registros
  para operar                 resumen_mensual:            registro_cambios
  clientes                    conteos por mes,            solicitudes_arco
  datos_fiscales              ciudad y rango de           depuraciones
  consentimientos             edad, con grupo mínimo
          │                           │                           │
          ▼                           ▼                           ▼
  Una vista por área          Solo conteos: sin           Solo se agregan
  v_soporte                   nombres, correos,           renglones; nadie
  v_facturacion               RFC ni tokens               los cambia
  v_promociones
```

Fuera de la base, pero dentro del ciclo de vida de los datos:

```text
Copias
  ├── respaldos: cifrados, con su propio plazo y rotación
  ├── desarrollo y pruebas: datos ficticios, nunca una copia de producción
  ├── exportaciones y reportes: solo conteos, con fecha de caducidad
  └── proveedor de correo: solo la lista de v_promociones
```

### Esquemas y roles

| Esquema | Qué guarda | Quién lo usa |
| --- | --- | --- |
| `operacion` | `clientes` (contacto y ciclo de vida), `datos_fiscales` y `consentimientos`, con el diseño de la evidencia 12 | La aplicación escribe. Cada área lee solo su vista: `soporte` la de contacto, `facturacion` la fiscal y `marketing` la de promociones. |
| `analitica` | `resumen_mensual`: conteos por mes, ciudad y rango de edad | `analista`, solo con SELECT. |
| `auditoria` | Los cambios a datos personales, las solicitudes ARCO y las depuraciones | La aplicación y los procesos solo insertan; el responsable de privacidad consulta. |
| `pii` (del LAB-01) | El mapa entre el id y el token | Solo el proceso que prepara datos seudonimizados, si alguna finalidad los necesita. Ningún analista. |

Los roles de área no inician sesión: cada persona tiene su propia cuenta y hereda los permisos de su área. El DBA también usa una cuenta propia, y el superusuario se reserva para las tareas que lo requieren.

### Controles

| Aspecto | Control | Cómo se hace en PostgreSQL | Decide / ejecuta |
| --- | --- | --- | --- |
| Acceso | Un rol por área, con SELECT solo sobre su vista; ninguna área recibe las tablas | `CREATE ROLE soporte NOLOGIN`, `GRANT soporte TO` cada usuario y `GRANT SELECT ON v_soporte TO soporte`. Las tablas nuevas no dan permisos a PUBLIC (manual, sección 5.7). | Los propietarios de los datos / el DBA |
| Minimización | Cada vista con solo las columnas de su finalidad; Analítica, solo conteos con un tamaño mínimo de grupo; campos opcionales y año de nacimiento en lugar de edad | Vistas por área y `GROUP BY … HAVING COUNT(*) >= n` en el resumen | Propietarios y responsable de privacidad / el DBA |
| Información más delicada | El RFC en `datos_fiscales`, cifrado y solo para Facturación; el correo y el teléfono enmascarados donde no hacen falta completos; conexiones con TLS y respaldos cifrados | pgcrypto con la clave fuera de la base (LAB-02), vista enmascarada (LAB-01), `ssl = on` y reglas `hostssl` (LAB-02) | Responsable de privacidad / el DBA |
| Retención | Plazos por grupo de datos (evidencia 10) aplicados con `estatus`, `fecha_fin_relacion` y `fecha_bloqueo`; la historia queda solo en el resumen, sin datos personales | Un proceso periódico que bloquea y suprime lo vencido; tablas de auditoría particionadas por mes, para borrar una partición entera al vencer su plazo (manual, sección 5.11) | Área jurídica / el DBA |
| Trazabilidad | Cada cambio a datos personales registra quién, cuándo, qué tabla y el folio que lo autoriza, sin copiar los valores; también se registran las consultas a datos personales | `log_statement = 'mod'` registra INSERT, UPDATE y DELETE (manual, sección 20.8), triggers que insertan en `auditoria.registro_cambios` o una extensión de auditoría como pgaudit (Unidad III) | Responsable de privacidad y Dirección / el DBA; los revisa alguien distinto del DBA |
| Eliminación | Suprimir en el orden del mapa de la evidencia 08, sin dejar copias; respaldos con caducidad; cada depuración se registra | Llaves foráneas en todas las tablas que repiten datos del cliente, `DELETE` y después `VACUUM`; registro en `auditoria.depuraciones` | Responsable de privacidad y área jurídica / el DBA |
| Atención de solicitudes | Un registro con folio, tipo, fecha de recepción y plazos: 20 días para responder y 15 para hacer efectiva la respuesta (art. 31); una consulta documentada que encuentra a una persona en todas las tablas; el DBA solo actúa con un folio autorizado | `auditoria.solicitudes_arco`; búsqueda por id en `operacion`, `analitica` y `pii`; la oposición o la revocación se registran en `consentimientos` | Responsable de privacidad (art. 29) / el DBA |

### Prueba del tamaño mínimo de grupo

Sin `HAVING`, la vista agrupada da tres grupos:

```text
   ciudad   | rango_edad | clientes
------------+------------+----------
 Culiacán   | 30-44      |        3
 Los Mochis | 30-44      |        1
 Mazatlán   | 45-59      |        1
(3 rows)
```

Con `HAVING COUNT(*) >= 3` queda uno:

```text
  ciudad  | rango_edad | clientes
----------+------------+----------
 Culiacán | 30-44      |        3
(1 row)
```

Los dos clientes que estaban solos en su grupo dejan de aparecer. El mínimo real lo debe fijar el responsable de privacidad; con cinco clientes, 3 solo sirve para ilustrar. Si el reporte necesita cuadrar el total, los grupos pequeños se pueden juntar en un renglón «Otros».

### Lo que existe hoy y lo que falta

| Pieza | Hoy en `comercializadora` | Lo que falta |
| --- | --- | --- |
| Vistas por área | `v_clientes_soporte` (LAB-01) y `v_analitica_clientes` (Actividad 4) | Las vistas de Facturación y de promociones; quitarle el RFC a la de soporte y darle el correo y el teléfono completos |
| Roles | `soporte` y `analista`, sin inicio de sesión | `facturacion` y `marketing`, y cuentas individuales |
| Resumen para Analítica | No existe: `analista` ve un renglón por cliente y `analitica.clientes` por token | Un resumen mensual con tamaño mínimo de grupo |
| Ciclo de vida y consentimiento | No existen | Los campos y la tabla de la evidencia 12 |
| Información más delicada | El RFC solo está cifrado en `clientes_protegidos`, y `dba-practica` tiene TLS apagado (LAB-02) | El RFC cifrado en los datos fiscales y TLS encendido |
| Auditoría | `log_statement = none`; el log del servidor solo guarda las sentencias con error | El registro de cambios y de solicitudes |
| Respaldos y desarrollo | No hay respaldos ni copias de desarrollo | Su plazo y sus reglas, antes de crearlos |

## Análisis

1. **Se separa por finalidad, no por tipo de dato.** El mismo cliente aparece en las tres partes: identificado en Operación, como parte de un conteo en Analítica y como un renglón de la bitácora en Auditoría. Cada parte guarda solo lo que su finalidad necesita.
2. **Cada parte tiene su propio control principal.** En Operación son los roles y las vistas; en Analítica, la agregación; en Auditoría, que los registros solo se agreguen y que los revise alguien distinto del DBA. El superusuario puede modificar cualquier tabla, así que conviene enviar también los registros fuera de la base.
3. **La auditoría también guarda datos personales.** Dice quién pidió qué y cuándo, y `log_statement` copia el texto de cada sentencia, con los valores que lleva, como un correo nuevo. Por eso la bitácora registra el folio y no los valores, y tiene su propio plazo de conservación.
4. **Seudonimizado no es anónimo.** Si Analítica conserva datos por token, como `analitica.clientes` del LAB-01, siguen siendo datos personales, porque el mapa permite volver a la persona. Un resumen con grupo mínimo se acerca más a la disociación, que ya no permite asociar los datos a nadie (LFPDPPP, art. 2, fracción IX), pero aun así hay que vigilar los grupos pequeños (guía, sección 29).
5. **Más piezas, pero consultas más ligeras.** Hay más vistas, roles y procesos que mantener. A cambio, Analítica lee un resumen pequeño en lugar de recorrer la tabla de clientes completa, y deja de competir con la operación por la misma tabla. Como en la retención (evidencia 10), proteger mejor y hacer la base más ligera van del mismo lado.
6. **El DBA es el custodio.** Implementa y opera la arquitectura, pero quién recibe cada vista, cuánto se conserva y qué se audita lo deciden los propietarios, el responsable de privacidad, el área jurídica y Dirección.

## Conclusión

La propuesta separa la base en Operación, Analítica y Auditoría para que cada área reciba solo lo que su finalidad necesita: Operación entrega una vista por área, Analítica solo conteos con un tamaño mínimo de grupo y Auditoría registra quién hizo qué sin copiar los datos. Los siete controles que pide la guía se traducen en piezas concretas de PostgreSQL: roles y vistas, agregación, cifrado y TLS, campos de ciclo de vida con depuraciones, registros de auditoría, supresión ordenada y un registro de solicitudes con sus plazos. Buena parte ya existe en la base desde los LAB-01 y LAB-02; lo que falta es sobre todo el ciclo de vida, el consentimiento y la auditoría.

## Referencias

- Guía del LAB-03, secciones 21 y 29; evidencias [08](08-ciclo-vida.md), [10](10-retencion.md), [11](11-gobierno-datos.md), [12](12-privacidad-diseno.md) y [14](14-evaluacion-integral.md).
- LAB-01: vista enmascarada, token y mapa ([informe](../../laboratorio-01-proteccion-datos/informe.md)). LAB-02: cifrado y TLS ([README](../../laboratorio-02-cifrado-credenciales/README.md)).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 (fracción IX), 29 y 31. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Manual de PostgreSQL 16, sección 5.7, «Privileges»: https://www.postgresql.org/docs/16/ddl-priv.html
- Manual de PostgreSQL 16, sección 5.11, «Table Partitioning»: https://www.postgresql.org/docs/16/ddl-partitioning.html
- Manual de PostgreSQL 16, sección 20.8, «Error Reporting and Logging» (`log_statement`): https://www.postgresql.org/docs/16/runtime-config-logging.html

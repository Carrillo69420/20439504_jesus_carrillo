# Evidencia 11 — Matriz de gobierno de datos

LAB-03, Actividad 11 (sección 17 de la guía). No tiene script ni capturas: la matriz parte del inventario de la evidencia 01 y se comparó con los permisos que hoy tiene la base.

## Objetivo

Asignar a cada campo principal de `clientes` una finalidad, un área responsable, los usuarios que pueden verlo, su protección, su retención y lo que se hace al terminar ese plazo, para demostrar que el acceso a un dato depende de una necesidad de trabajo y no de que el dato exista en la tabla.

## Procedimiento

1. La finalidad, el nivel de acceso y la retención de cada campo salieron de la [evidencia 01](01-inventario-datos.md) y de la tabla de retención de la [evidencia 10](10-retencion.md).
2. Se usaron los roles que sugiere la guía (Atención al cliente, Facturación, Analítica, DBA y Dirección) y se agregaron dos que ya aparecieron en las Actividades 8 a 10: el responsable de privacidad, que tramita las solicitudes ARCO, y el área jurídica, que fija los plazos.
3. Para separar a quien decide de quien ejecuta se usaron dos conceptos de la guía (sección 4). El **propietario de datos** decide sobre el uso de ciertos datos y sus controles; el **custodio de datos** implementa y mantiene los controles técnicos. En la matriz, la columna «Responsable» es el propietario. No es el «responsable» de la LFPDPPP: para la ley, el responsable es la empresa completa, la persona moral que trata los datos (art. 2, fracciones XIV y XVI).
4. Para comparar la matriz con la base se consultaron, solo en modo lectura, los permisos de los roles `soporte` y `analista`, creados en el LAB-01:

```sql
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('analista', 'soporte')
ORDER BY grantee, table_schema, table_name;
```

También se revisó qué columnas entrega la vista de soporte del LAB-01:

```sql
SELECT pg_get_viewdef('v_clientes_soporte'::regclass, true);
```

## Resultado

### Matriz

| Dato | Finalidad | Responsable | Usuarios autorizados | Protección | Retención | Acción al finalizar |
| --- | --- | --- | --- | --- | --- | --- |
| nombre | Saber con quién se trata y ponerlo en sus facturas | Atención al cliente | Atención al cliente y Facturación | Solo en las vistas de esas dos áreas; ninguna vista de Analítica lo incluye | Mientras sea cliente; en las facturas emitidas, cinco años (CFF, art. 30) | Bloqueo y luego supresión; en las facturas, supresión al vencer los cinco años |
| correo | Contactar al cliente y responder sus solicitudes | Atención al cliente | Atención al cliente | Completo solo en la vista de Atención al cliente; enmascarado donde no hace falta completo; para promociones, solo el de quien aceptó (evidencia 05) | Mientras sea cliente, más el bloqueo que fije el área jurídica | Bloqueo y luego supresión |
| telefono | Contactar al cliente | Atención al cliente | Atención al cliente | Igual que el correo; además es opcional | Igual que el correo | Bloqueo y luego supresión |
| rfc | Emitir facturas | Facturación | Facturación | Tabla aparte solo para Facturación, cifrado como en el LAB-02; nunca en vistas de otras áreas ni en copias de desarrollo | Mientras sea cliente; en las facturas emitidas, cinco años (CFF, art. 30) | Bloqueo y luego supresión; en las facturas, supresión al vencer los cinco años |
| edad | Estadísticas por rango de edad | Analítica | Analítica, solo en rangos | Rangos y conteos con un tamaño mínimo de grupo; ninguna otra área la ve | Mientras sea cliente | Disociación: solo quedan los conteos por rango |
| ciudad | Estadísticas por ciudad | Analítica | Analítica, en conteos | Conteos con un tamaño mínimo de grupo | Mientras sea cliente | Disociación: solo quedan los conteos por ciudad |
| codigo_postal | Región para estadísticas y, si es el del domicilio fiscal, la factura | Facturación | Facturación, completo; Analítica, solo la región | Completo solo en la tabla de Facturación; para Analítica, los dos primeros dígitos | En las facturas emitidas, cinco años; para estadísticas, mientras sea cliente | Supresión; la región queda solo en los conteos |

En la base, cada área sería un rol de grupo sin inicio de sesión, del que heredan los usuarios de esa área: Atención al cliente es el rol `soporte` y Analítica el rol `analista`, que ya existen desde el LAB-01. Facturación necesitaría un rol `facturacion`, que hoy no existe.

### Qué le toca a cada rol

| Rol | Datos que usa | Qué decide | Qué ejecuta |
| --- | --- | --- | --- |
| Atención al cliente | id, nombre, correo y teléfono de los clientes activos | Es propietario de los datos de contacto: qué hace falta para atender y quién de su área lo ve | Atiende al cliente y recibe sus solicitudes |
| Facturación | id, nombre, RFC y código postal fiscal de quien pide factura | Es propietario de los datos fiscales | Emite las facturas y conserva la documentación fiscal |
| Analítica | Solo conteos por ciudad, rango de edad y región | Es propietario de las estadísticas, no de los datos de cada persona | Genera los reportes agregados |
| DBA | Ninguno para el negocio; ve todo por su función técnica | Nada sobre finalidades ni plazos; propone controles y avisa de los riesgos | Es el custodio: crea roles, vistas y permisos, y aplica bloqueos, supresiones y depuraciones |
| Dirección | Solo reportes agregados | Aprueba las finalidades y la política de privacidad | Nombra a los propietarios y al responsable de privacidad |
| Responsable de privacidad | Los de una persona, solo mientras atiende su solicitud | Si una solicitud ARCO procede y si una finalidad nueva requiere consentimiento | Tramita las solicitudes (LFPDPPP, art. 29) y le da las instrucciones al DBA |
| Área jurídica | Ninguno de forma rutinaria | Los plazos de conservación y de bloqueo, y las obligaciones legales | Revisa la política de retención y el aviso de privacidad |

### Cómo está hoy la base

La consulta de permisos devolvió tres renglones: `analista` tiene SELECT sobre `analitica.clientes` y sobre `v_analitica_clientes`, y `soporte` tiene SELECT sobre `v_clientes_soporte`. Comparados con la matriz:

| Rol o tabla | Hoy | Según la matriz |
| --- | --- | --- |
| `soporte` | Ve `v_clientes_soporte`: id, nombre, y el correo, el teléfono y el RFC enmascarados (del RFC, los últimos cuatro caracteres) | Le sobra el RFC, aun enmascarado: Atención al cliente no lo usa. Le falta el correo completo y el teléfono completo, porque con los enmascarados no puede contactar a nadie. |
| `analista` | Ve `v_analitica_clientes`, con un renglón por cliente, y `analitica.clientes`, con la edad, la ciudad, el código postal y la fecha de alta exactos de cada token | Debería recibir solo conteos con un tamaño mínimo de grupo. Con lo que ve hoy, el único cliente de Mazatlán y el único de Los Mochis quedan señalados. |
| Facturación | No tiene rol | Necesita un rol `facturacion` con una vista de los datos fiscales; hoy solo el superusuario podría facturar. |
| `clientes_soporte` | Ningún rol tiene permiso; conserva el correo anterior de Ana López (Actividad 7) | Es una copia sin dueño ni usuarios: la debería sustituir una vista para Atención al cliente. |
| DBA | En el laboratorio, todo se hizo con el superusuario `postgres` | El DBA debería usar una cuenta propia y el superusuario solo para lo que lo requiera, para que cada cambio diga quién lo hizo (Actividad 7). |

## Análisis

1. **Ningún rol necesita todos los datos, y ningún dato lo necesitan todos los roles.** Cada campo tiene como máximo dos áreas usuarias. Dirección y el DBA, los roles con más poder, no usan ningún campo para su trabajo diario: Dirección decide con reportes agregados y el DBA administra la base sin usar los datos para el negocio.
2. **Decidir y ejecutar están separados.** Los propietarios deciden qué hace falta, el área jurídica fija los plazos, el responsable de privacidad resuelve las solicitudes y el DBA, como custodio, lo convierte en roles, vistas, permisos y depuraciones. Si el DBA decidiera solo, las decisiones legales quedarían en manos de quien no tiene la autoridad para tomarlas (guía, sección 29).
3. **La matriz se vuelve permisos.** Cada columna se traduce en algo de la base: los usuarios autorizados, en roles y en GRANT sobre vistas; la protección, en vistas, enmascaramiento, cifrado y conteos; la retención y la acción al finalizar, en campos del ciclo de vida y en depuraciones (Actividad 12). Una matriz que no se refleja en la base es solo un documento.
4. **La base actual no coincide con la matriz.** Hay permisos de más (el RFC enmascarado para `soporte`, la edad y el código postal exactos para `analista`), permisos de menos (Facturación no tiene rol y `soporte` no ve el correo completo) y una copia sin dueño (`clientes_soporte`). Son las correcciones que propone la Actividad 15.
5. **Un mismo dato puede tener dos usos con distinto detalle.** El código postal completo es de Facturación; su región, de Analítica. El nombre lo usan Atención al cliente para atender y Facturación para facturar. Cada área debe recibirlo en su propia vista y con el detalle que necesita.

## Conclusión

La matriz demuestra que el acceso se decide por la necesidad de cada área: Atención al cliente ve los datos de contacto, Facturación los fiscales y Analítica solo conteos. Dirección y el DBA no aparecen como usuarios de ningún campo: una aprueba y el otro custodia. Al comparar la matriz con los permisos de hoy aparecen diferencias concretas que el DBA puede corregir; las decisiones sobre finalidades y plazos, en cambio, les corresponden a los propietarios, al responsable de privacidad y al área jurídica.

## Referencias

- Guía del LAB-03, secciones 4, 17 y 29; evidencias [01](01-inventario-datos.md), [05](05-finalidad-secundaria.md) y [10](10-retencion.md).
- LAB-01: roles `soporte` y `analista`, vista `v_clientes_soporte` y tabla `analitica.clientes` ([informe](../../laboratorio-01-proteccion-datos/informe.md)). LAB-02: cifrado del RFC ([README](../../laboratorio-02-cifrado-credenciales/README.md)).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 2 (fracciones XIV y XVI) y 29. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Código Fiscal de la Federación, artículo 30. Texto vigente, última reforma publicada en el DOF el 9 de abril de 2026. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/CFF.pdf

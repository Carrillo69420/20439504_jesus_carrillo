# Evidencia 14 — Evaluación integral

LAB-03, Actividad 14 (sección 20 de la guía). No tiene script ni capturas: se analizó el escenario de la guía con lo encontrado en las Actividades 1 a 13.

## Objetivo

Identificar al menos diez problemas o riesgos de privacidad en el escenario de una empresa con 50,000 clientes y, para cada uno, indicar el principio afectado, el riesgo y un control que lo reduzca.

## Procedimiento

1. Se separó el escenario en sus hechos:
   - 50,000 clientes;
   - todo el personal de Analítica consulta directamente `clientes`, que tiene nombre, correo, teléfono, RFC, edad, ciudad y código postal;
   - Analítica solo genera estadísticas mensuales;
   - los datos se conservan desde hace 12 años, sin una política documentada de retención;
   - los desarrolladores reciben copias completas, con información real;
   - Marketing usa los correos para campañas promocionales;
   - no hay documentación de la finalidad de cada dato.
2. A cada hecho se le hicieron tres preguntas: qué principio deja de cumplirse, qué podría pasar y qué control lo corrige.
3. Para la columna «Principio afectado» se usaron los principios de la LFPDPPP (art. 5) y los deberes de seguridad y confidencialidad (arts. 18 y 20). Cuando el problema es de acceso, también el principio de seguridad de mínimo privilegio. La minimización de la guía corresponde a la proporcionalidad de la ley (art. 12).
4. Cada control se comparó con lo que ya se probó en este laboratorio y en los LAB-01 y LAB-02.

## Resultado

### Matriz

| # | Problema | Principio afectado | Riesgo | Control propuesto |
| --- | --- | --- | --- | --- |
| 1 | Todo el personal de Analítica consulta directamente `clientes` | Mínimo privilegio; finalidad | Cualquier analista puede ver o extraer los datos de contacto y el RFC de 50,000 personas, aunque su trabajo no lo requiera | Rol `analista` sin permiso sobre `clientes` y con SELECT solo sobre una vista o una tabla de resumen (Actividad 4) |
| 2 | Analítica recibe nombre, correo, teléfono y RFC aunque solo genera estadísticas | Proporcionalidad (minimización) | Datos que identifican a cada persona terminan en consultas, hojas de cálculo y reportes que no los necesitaban | Entregar solo conteos por ciudad, rango de edad y región (Actividad 3) |
| 3 | Las estadísticas se calculan con los renglones de cada persona | Proporcionalidad | Los grupos pequeños señalan a alguien: con la ciudad, la edad exacta y el código postal, una persona puede quedar sola en su grupo (LAB-01) | Una tabla de resumen que se calcula una vez al mes, con un tamaño mínimo de grupo; Analítica no ve renglones individuales |
| 4 | Los datos se conservan desde hace 12 años | Proporcionalidad; calidad | Los exclientes de hace 12 años siguen expuestos: una fuga afecta a más personas, y a cada una se le debe informar (art. 19) | Plazos por grupo de datos, bloqueo y supresión de quien ya no es cliente, y solo conteos disociados para la historia (evidencia 10) |
| 5 | La tabla guarda la edad como número, y hay registros de hasta 12 años | Calidad (art. 10) | Si nadie la actualiza, una edad guardada hace 12 años está 12 años atrasada: estadísticas equivocadas y datos inexactos, que son una infracción (art. 58, fracción VI) | Año de nacimiento en lugar de edad, con el rango calculado al consultar (evidencia 12) |
| 6 | No hay una política documentada de retención | Responsabilidad (art. 13) | Nadie sabe qué se puede borrar ni cuándo, así que se conserva todo, y la empresa no puede demostrar que cumple | Política aprobada con el área jurídica, con fundamento, plazo, evento de inicio y responsables, y campos que registren el fin de la relación (evidencias 10 y 12) |
| 7 | Los desarrolladores reciben copias completas de la base | Mínimo privilegio; deber de confidencialidad (art. 20) | Los datos de 50,000 personas salen del entorno controlado y terminan en equipos personales, servidores de prueba y respaldos sin la misma protección | Copias con datos ficticios o enmascarados; si solo hace falta la estructura, `pg_dump` con `--exclude-table-data` para las tablas con datos personales |
| 8 | Las copias de desarrollo tienen información real | Finalidad; calidad | Las copias no reciben las rectificaciones ni las cancelaciones, como la copia de soporte de la Actividad 7: siguen ahí datos corregidos o que ya se debieron borrar | Inventario de copias con dueño y fecha de caducidad, sin datos reales en desarrollo, y destrucción de las copias al terminar las pruebas |
| 9 | Marketing usa los correos para campañas promocionales | Finalidad (art. 11); consentimiento (art. 7) | Cambiar la finalidad sin consentimiento es una infracción (art. 58, fracción IX), y genera quejas y solicitudes de oposición | Actualizar el aviso de privacidad y enviar solo a quien aceptó, con un registro de consentimiento por finalidad y una vista (evidencias 05 y 12) |
| 10 | No hay documentación de la finalidad de cada dato | Información (art. 14); responsabilidad (art. 13) | No se puede redactar el aviso (art. 15), decidir quién necesita qué ni responder una solicitud de acceso, que incluye las condiciones del tratamiento (art. 22) | Inventario y matriz de gobierno (evidencias 01 y 11), con la finalidad de cada columna también en la base (`COMMENT ON COLUMN`) |
| 11 | El RFC está al alcance de Analítica y de Desarrollo | Proporcionalidad; deber de seguridad (art. 18) | Es un identificador fiscal único que además trae la fecha de nacimiento: sirve para suplantar a una persona | RFC en una tabla de datos fiscales solo para Facturación, cifrado (LAB-02) y fuera de las copias y exportaciones |
| 12 | El escenario no menciona ningún registro de quién consulta o cambia los datos | Responsabilidad (art. 13); deber de seguridad (art. 18) | Una extracción masiva o un cambio no autorizado no se detectan, y no se puede demostrar quién hizo qué | Una cuenta por persona, sin cuentas compartidas, y un registro de auditoría de los cambios y de las consultas a datos personales (Unidad III) |

### Qué atender primero

| Prioridad | Problemas | Por qué |
| --- | --- | --- |
| Inmediata | 1, 2, 7, 8 y 11 | Son los accesos más amplios: muchas personas, o copias fuera de producción, con los datos de los 50,000 clientes. Se corrigen con controles que ya se probaron: una vista y un rol (Actividad 4) y copias sin datos reales. |
| Con el área jurídica y Dirección | 4, 6 y 9 | Necesitan decisiones que no le tocan al DBA: plazos de conservación y la base para enviar promociones. La campaña de Marketing es una infracción que está pasando hoy. |
| De fondo | 3, 5, 10 y 12 | Corrigen el diseño y la documentación para que los problemas no vuelvan: resúmenes con grupo mínimo, año de nacimiento, catálogo de finalidades y auditoría. |

### Lo que ya se probó en el laboratorio

- **Una vista y un rol en lugar de la tabla.** En la Actividad 4, `analista` consultó `v_analitica_clientes` y PostgreSQL le negó `clientes` («permission denied for table clientes»).
- **Conteos en lugar de renglones.** La Actividad 3 dio Culiacán 3, Los Mochis 1 y Mazatlán 1. Los dos grupos de una sola persona son la razón del tamaño mínimo de grupo del problema 3.
- **Las copias no se enteran de los cambios.** En la Actividad 7, `clientes` cambió el correo de Ana López y `clientes_soporte` se quedó con el anterior. Es lo mismo que pasaría con las copias de desarrollo del problema 8.
- **El ciclo de vida y el consentimiento.** El diseño de la evidencia 12 se probó en `dba-ensayo`: la vista de promociones solo mostró al cliente que aceptó, y dejó de mostrarlo en cuanto se le dio de baja.
- **El RFC cifrado y el token.** El LAB-02 cifró el RFC y el LAB-01 cambió el id por un token para Analítica.

## Análisis

1. **Ningún problema es una falla técnica de seguridad.** El escenario no habla de contraseñas débiles ni de conexiones sin cifrar, y aun así tiene doce riesgos. Una base puede estar bien configurada y no cumplir con la privacidad.
2. **Los problemas se encadenan.** Sin documentar la finalidad de cada dato (problema 10) no se puede decidir quién lo necesita (1 y 2), cuánto tiempo conservarlo (4 y 6) ni si Marketing puede usarlo (9). Por eso la documentación es de fondo, aunque no sea lo primero que se corrige.
3. **Las copias multiplican cada riesgo.** Una copia completa para desarrollo repite fuera de producción los 12 años de datos, el RFC y los correos, con menos controles y sin las correcciones posteriores.
4. **La escala cambia el impacto.** Con 50,000 clientes, un acceso indebido o una fuga afecta a decenas de miles de personas, y a cada una se le tendría que informar si la vulneración afecta de forma significativa sus derechos (art. 19).
5. **El DBA propone los controles; otros deciden.** Las vistas, los roles, las copias sin datos reales y la auditoría son técnicos. Los plazos, el consentimiento para promociones y las finalidades los deciden Dirección, el responsable de privacidad y el área jurídica. El DBA presenta esta matriz y escala lo que no le toca (guía, sección 29).

## Conclusión

El escenario tiene al menos doce problemas, y ninguno se resuelve con más cifrado o mejores contraseñas: el acceso es más amplio de lo que cada área necesita, los datos se conservan sin plazo, se copian a desarrollo con información real y se usan para una finalidad que los clientes no aceptaron. Lo más urgente es cerrar el acceso directo de Analítica y las copias reales de desarrollo, porque exponen los datos de los 50,000 clientes a muchas personas. Lo de fondo es documentar la finalidad de cada dato, porque de ahí salen los permisos, los plazos y los consentimientos.

## Referencias

- Guía del LAB-03, secciones 20 y 29; evidencias [01](01-inventario-datos.md), [05](05-finalidad-secundaria.md), [08](08-ciclo-vida.md), [10](10-retencion.md), [11](11-gobierno-datos.md) y [12](12-privacidad-diseno.md); PDF de las Actividades [3](03-finalidad.pdf), [4](04-control-acceso.pdf) y [7](07-derecho-rectificacion.pdf).
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículos 5, 7, 10, 11, 12, 13, 14, 15, 18, 19, 20, 22 y 58. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Manual de PostgreSQL 16, «pg_dump», opción `--exclude-table-data`: https://www.postgresql.org/docs/16/app-pgdump.html

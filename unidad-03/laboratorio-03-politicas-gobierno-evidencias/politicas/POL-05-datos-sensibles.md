# POL-05 — Uso de datos sensibles

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Estado: propuesta del DBA; la aprueba Dirección
- Fecha: 24 de noviembre de 2026

**Objetivo:** reducir el riesgo de que alguien lea datos personales que su función no necesita, o para una finalidad que no está en el aviso de privacidad, sin que quede registro. Hoy puede pasar: `soporte_ana` puede leer toda la tabla `clientes`, y cuando leyó el RFC de María García la bitácora solo guardó una conexión de 6 milisegundos ([LAB-01, evidencia 14](../../laboratorio-01-bitacoras-auditoria/evidencias/14-limites.md)).

**Alcance:**

- Datos: en esta política, datos sensibles son los datos personales de los clientes, las columnas que el [diccionario](../evidencias/03-diccionario.md) marca como «Dato personal», y los conjuntos que los copian. En el [catálogo](../evidencias/04-catalogo.md) son los que contienen datos personales: CAT-01, CAT-02 y CAT-04 a CAT-07.
- Ninguna de esas columnas es un dato personal sensible en el sentido jurídico, porque no hay datos de salud, religión ni preferencia sexual, como se concluyó para la tabla de clientes de la Unidad II ([informe de su LAB-01](../../../unidad-02/laboratorio-01-proteccion-datos/informe.md), pregunta 4). Se protegen porque, si se filtran, sirven para fraudes y suplantación de identidad.
- Sistemas: `dba-u3-pg`, `dba-u3-mongo` y las copias exportadas.
- Ambiente: producción, el único con datos reales (regla 2).

**Regla:**

1. Cada área lee solo los campos que le asigna la matriz de gobierno de la Unidad II, por medio de una vista o un rol propio, y leer otro campo requiere un folio con su finalidad, aprobado por la Gerencia Comercial y por el responsable de privacidad.
2. Los datos personales reales solo están en producción y en las copias exportadas para Auditoría interna, que se conservan con POL-03; desarrollo y pruebas trabajan con datos ficticios o enmascarados.
3. Las lecturas de estos datos que hacen las cuentas de personas, incluido el DBA, quedan registradas con la cuenta, el momento y la consulta, y Auditoría interna las revisa cada mes contra las finalidades aprobadas.

**Responsable:**

- Decide: la Gerencia Comercial, qué campos usa cada área, y el responsable de privacidad, si la finalidad está en el aviso de privacidad. Una finalidad distinta requiere obtener otra vez el consentimiento del titular (LFPDPPP, art. 11).
- Ejecuta: el DBA, que crea las vistas, los roles y los permisos con POL-01.
- Revisa: Auditoría interna.

**Excepciones:**

- Una solicitud del propio titular para conocer sus datos (derecho de acceso) la resuelve el responsable de privacidad, después de acreditar la identidad del titular (LFPDPPP, art. 31).
- En una investigación, como la de un RFC cambiado sin autorización, Auditoría interna puede recibir los valores completos de la auditoría y de la bitácora de los clientes involucrados, no solo los metadatos de la muestra E4, con un folio que lo registre. Lo que necesite se preserva con POL-03.
- La prueba de restauración de POL-02, en un ambiente aislado que se elimina al terminar.
- Un requerimiento de una autoridad lo autoriza el área jurídica.

**Evidencia:**

- Qué campos usa cada área: la [matriz de gobierno de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md).
- Qué puede leer cada cuenta: E2 (Actividad 8). Hoy no se cumple la regla 1: `soporte_ana` tiene `SELECT` sobre toda la tabla ([README del LAB-01](../../laboratorio-01-bitacoras-auditoria/README.md)).
- El registro de lecturas: hoy no existe. Con `log_statement = 'mod'`, la bitácora no guarda los `SELECT`, y el disparador no se activa con lecturas (LAB-01, evidencia 14). En MongoDB solo está el perfilador, que es una herramienta de diagnóstico, no de auditoría (evidencia 05).
- Los folios de accesos de excepción y las revisiones mensuales: hoy no existen.

**Revisión:** cada año, y cuando cambien el aviso de privacidad o la matriz de la Unidad II.

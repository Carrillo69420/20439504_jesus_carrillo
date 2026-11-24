# POL-02 — Respaldo

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Estado: propuesta del DBA; la aprueba Dirección
- Fecha: 24 de noviembre de 2026

**Objetivo:** reducir el riesgo de que una pérdida de datos, por un borrado, una falla del disco o un volumen eliminado, sea definitiva. Hoy lo sería: ninguno de los dos servidores tiene respaldos, y en `dba-u3-pg` los clientes, la auditoría y la bitácora están en el mismo volumen, `dba-u3-pg-data`, así que se perderían juntos ([evidencia 05](../evidencias/05-conservacion.md), paso 1). Tener respaldos tampoco basta: en el caso de GitLab.com de 2017, que se revisó en la [Unidad I](https://academy.ficlabs.com.mx/materias/dba/unidad-01/03-ambientes-de-trabajo/), varios de sus mecanismos de respaldo no funcionaban de forma confiable cuando hicieron falta.

**Alcance:**

- Datos: en `dba-u3-pg`, la base `comercial` completa, con los clientes, la auditoría y el registro de cambios (CAT-01 a CAT-03); en `dba-u3-mongo`, las bases `comercial` y `auditoria`, con los clientes y las instantáneas de privilegios (CAT-04 y CAT-08).
- También la configuración de cada servidor: los parámetros del motor, como los de la bitácora del LAB-01, y las reglas de acceso. Para la Unidad I, la configuración es parte del ambiente, igual que los datos (POL-06).
- No incluye las bitácoras ni `system.profile`: se conservan con POL-03, porque conservar una bitácora no es lo mismo que respaldar una base (evidencia 05, pregunta 3).
- Sistemas: `dba-u3-pg` y `dba-u3-mongo`. Ambiente: producción.

**Regla:**

1. Lo del alcance se respalda una vez al día, y cada respaldo se guarda 30 días fuera del servidor que respalda, con su huella SHA-256; al cumplir los 30 días, se suprime.
2. Cada mes, el DBA restaura el respaldo más reciente en un ambiente aislado, con los mismos accesos que producción, y comprueba que estén todas las tablas y colecciones con los renglones que se contaron al respaldar; al terminar, ese ambiente se elimina.
3. Auditoría interna revisa el acta de cada prueba, y un respaldo que no se pudo restaurar se reporta como incidente el mismo día.

El procedimiento técnico se definirá en la Unidad V: esta política solo fija qué se respalda, cada cuánto y quién verifica que el respaldo sirve.

**Responsable:**

- Deciden la frecuencia y el plazo: la Gerencia Comercial, según cuántos datos de clientes se pueden perder y hasta qué fecha hay que poder volver, y Auditoría interna, lo mismo para la evidencia. Aquí se proponen un día y 30 días.
- Ejecuta: el DBA.
- Verifica que el respaldo sirve: Auditoría interna, con el acta de la prueba de restauración.

**Excepciones:** ninguna para el respaldo diario: si falla, se repite el mismo día y la falla queda registrada. La prueba mensual solo se puede posponer un mes, con autorización de Auditoría interna.

**Evidencia:** hoy no existe. En los LAB-01 a LAB-03 no se hizo ningún respaldo de `dba-u3-pg` ni de `dba-u3-mongo`, y no hay un registro de respaldos. Cuando exista, la evidencia será ese registro, con la fecha, la huella y el resultado de cada respaldo, y las actas de las pruebas de restauración.

**Revisión:** cada año, y cuando la Unidad V defina el procedimiento técnico.

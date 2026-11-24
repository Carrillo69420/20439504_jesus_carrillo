# POL-03 — Retención

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Estado: propuesta del DBA; la aprueba Dirección
- Fecha: 24 de noviembre de 2026

**Objetivo:** reducir dos riesgos opuestos: conservar datos y registros más de lo que justifica su finalidad, y perderlos antes de que alguien los necesite. Hoy pasan los dos: los archivos de la bitácora de PostgreSQL se acumulan sin plazo desde octubre, y uno todavía guarda cinco secretos ([evidencia 05](../evidencias/05-conservacion.md), paso 1), mientras que lo que `getLog` muestra de MongoDB se vacía en cada reinicio ([LAB-02, evidencia 08](../../laboratorio-02-trazabilidad-mongodb/evidencias/08-conservacion.md)).

**Alcance:**

- Datos: los ocho conjuntos del catálogo, de CAT-01 a CAT-08 ([evidencia 04](../evidencias/04-catalogo.md)), y todas sus copias: exportaciones, copias del expediente y respaldos (POL-02).
- Sistemas: `dba-u3-pg`, `dba-u3-mongo` y los lugares donde se guardan sus copias. Ambiente: producción.

**Regla:**

1. Cada conjunto se conserva el plazo que le fija su documento: los datos de clientes, la política de retención de la Unidad II (lo fiscal, cinco años; lo demás, mientras sea cliente); la auditoría, las bitácoras, el perfilado y las instantáneas, el criterio de conservación de la evidencia 05, y el registro de cambios, el que fije el Comité de cambios, que no puede ser menor que los dos años de la bitácora de privilegios con que se concilia.
2. Al vencer un plazo, el DBA aplica la acción que indica ese documento, bloqueo o supresión, en la base y en sus copias, y deja una constancia con la fecha, el conjunto, cuántos registros, quién lo autorizó y quién lo hizo, sin copiar lo borrado.
3. Nada se suprime mientras esté preservado: Auditoría interna o el área jurídica pueden ordenar por escrito que se conserve lo que necesita una investigación o una reclamación (POL-05), y esa orden prevalece sobre cualquier plazo hasta que se levante, también por escrito.

**Responsable:**

- Fijan los plazos: el área jurídica, los que dependen de una ley; Auditoría interna, los de la evidencia, y el Comité de cambios, el de su registro. Dirección aprueba la política.
- Autoriza cada depuración: el propietario del conjunto. En la auditoría, el responsable de privacidad con el área jurídica, que confirman que el plazo venció y que ninguna investigación o reclamación pendiente la necesita ([LAB-01, evidencia 14](../../laboratorio-01-bitacoras-auditoria/evidencias/14-limites.md)).
- Ejecuta: el DBA.
- Revisa: Auditoría interna, que comprueba que se borró solo lo autorizado.

**Excepciones:**

- La preservación de la regla 3, que puede alargar cualquier plazo.
- Si el titular pide cancelar sus datos y el responsable de privacidad decide que procede, el plazo se adelanta: sus datos pasan a bloqueo y después se suprimen (LFPDPPP, art. 24), en todas sus copias, la auditoría incluida.
- Los respaldos no se editan: lo que se suprime sale de ellos cuando rotan, a los 30 días (POL-02).

**Evidencia:**

- Los plazos: la [política de retención de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/10-retencion.md) y el [criterio de conservación](../evidencias/05-conservacion.md).
- Que la bitácora no pasa de 90 días en el servidor: el listado del directorio `log`, como el del paso 1 de la evidencia 05. Hoy el archivo más viejo es del 29 de octubre de 2026, de hace 26 días.
- Las constancias de depuración: hoy no existe ninguna, porque en los LAB-01 a LAB-03 no se depuró nada. El `DELETE` de Pedro Ruiz en el LAB-01 fue una baja, no una depuración, y sus datos siguen en la auditoría y en la bitácora ([LAB-01, evidencia 12](../../laboratorio-01-bitacoras-auditoria/evidencias/12-altas-bajas.md)).
- Las órdenes de preservación: hoy no existe ninguna.

**Revisión:** cada año, y en cuanto el área jurídica confirme el plazo de prescripción que la evidencia 05 dejó pendiente, o cambie la ley.

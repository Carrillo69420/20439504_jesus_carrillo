# POL-01 — Acceso

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Estado: propuesta del DBA; la aprueba Dirección
- Fecha: 24 de noviembre de 2026

**Objetivo:** reducir el riesgo de que una cuenta tenga más acceso del que necesita su función, o de que lo conserve cuando ya no le hace falta. Ya pasó en los laboratorios: `soporte_ana` tiene `SELECT` sobre toda la tabla `clientes` y leyó un RFC que Atención al cliente no usa, y en MongoDB `app_ventas` recibió `dbAdmin`, un rol que también alcanza la evidencia ([evidencia 02](../evidencias/02-responsables.md)).

**Alcance:**

- Datos: los ocho conjuntos del catálogo, de CAT-01 a CAT-08 ([evidencia 04](../evidencias/04-catalogo.md)).
- Sistemas: `dba-u3-pg` y `dba-u3-mongo`, con sus cuentas de personas y de aplicaciones.
- Ambiente: producción, que en este laboratorio son esos dos servidores (POL-06). Desarrollo y pruebas no tienen datos reales (POL-05).
- Cubre crear y borrar cuentas, y dar y quitar permisos y roles.

**Regla:**

1. Toda cuenta nueva y todo permiso o rol que se agregue llevan un folio en `gobierno.solicitudes_cambio`, pedido por el área que lo va a usar y aprobado por el propietario del conjunto de datos.
2. Cada mes, Auditoría interna concilia con sus folios los cambios de cuentas y permisos: en PostgreSQL, las líneas `GRANT` y `REVOKE` de la bitácora exportada y las que crean, cambian o borran cuentas; en MongoDB, la instantánea de privilegios del mes, comparada con la anterior.
3. Cada año, el propietario de cada conjunto revisa los permisos vigentes y confirma cada uno o pide quitarlo, y el DBA quita, con folio, lo que no se confirme.

**Responsable:**

- Decide: el propietario de cada conjunto, según la matriz de la [evidencia 02](../evidencias/02-responsables.md): la Gerencia Comercial, en los clientes (CAT-01 y CAT-04); Auditoría interna, en la evidencia (CAT-02 y CAT-05 a CAT-08), y el Comité de cambios, en su registro (CAT-03). Si un permiso sobre los clientes también alcanza la evidencia, como `dbAdmin`, que permite leer `system.profile` y cambiar el nivel del perfilador, lo aprueban los dos propietarios.
- Ejecuta: el DBA, solo con el folio aprobado.
- Concilia: Auditoría interna, no el DBA que hizo los cambios.

**Excepciones:** un acceso urgente para atender una falla en producción lo puede aprobar el propietario por cualquier medio; el DBA registra el folio ese mismo día y quita el acceso al cerrar la falla. La cuenta de administrador que se crea al instalar cada servidor no lleva folio, pero entra en la revisión anual.

**Evidencia:**

- Las solicitudes aprobadas: `gobierno.solicitudes_cambio`, que se crea en la Actividad 7. Hoy no hay folios de accesos: los permisos de los LAB-01 y LAB-02 se dieron sin solicitud.
- Los cambios en PostgreSQL: las líneas de privilegios y de cuentas de la bitácora ([LAB-01, evidencia 06](../../laboratorio-01-bitacoras-auditoria/evidencias/06-privilegios-estructura.md)).
- Los cambios en MongoDB: las instantáneas de `auditoria.instantaneas_privilegios` y su comparación ([LAB-02, evidencia 07](../../laboratorio-02-trazabilidad-mongodb/evidencias/07-privilegios-control-compensatorio.md)).
- Los permisos vigentes en PostgreSQL: E2 (Actividad 8).
- Las actas de la conciliación mensual y de la revisión anual: hoy no existen.

**Revisión:** cada año, y cada vez que cambie la matriz de responsables.

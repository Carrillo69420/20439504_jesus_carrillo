# POL-06 — Cambios en producción

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Estado: propuesta del DBA; la aprueba Dirección
- Fecha: 24 de noviembre de 2026

**Objetivo:** reducir el riesgo de que se haga un cambio en producción sin autorización, o distinto del que se aprobó, y de que después no se pueda comprobar. Sin una regla escrita no se puede decir que un cambio fue indebido (sección 1 de la guía): en el LAB-01, `postgres` apagó el disparador de auditoría, cambió el RFC del cliente 3 y lo volvió a encender en 3 milisegundos; la bitácora lo registró, pero no había con qué compararlo ([LAB-01, evidencia 13](../../laboratorio-01-bitacoras-auditoria/evidencias/13-manipulacion.md)).

**Alcance:**

- Ambiente: producción. La [Unidad I](https://academy.ficlabs.com.mx/materias/dba/unidad-01/03-ambientes-de-trabajo/) define un ambiente como un «conjunto independiente de infraestructura, configuración y datos» en el que se ejecuta un sistema con un propósito dentro de su ciclo de vida, y el programa fija tres: desarrollo, pruebas y producción, que es el que atiende a los usuarios reales. En este laboratorio, producción son `dba-u3-pg` y `dba-u3-mongo`, con la base `comercial`.
- Qué es un cambio: por esa definición, cualquier cambio a una de las tres partes del ambiente. Es decir, a la infraestructura (el servidor, el contenedor o su volumen), a la configuración (los parámetros del motor, las reglas de acceso, las cuentas y sus permisos) o a los datos (la estructura y las correcciones hechas a mano).
- No es un cambio lo que la aplicación hace en su operación normal, como dar de alta o actualizar un cliente: eso es el uso del sistema.
- Datos: los ocho conjuntos del catálogo, de CAT-01 a CAT-08 ([evidencia 04](../evidencias/04-catalogo.md)).

**Regla:**

1. Antes: cada cambio tiene un folio aprobado en `gobierno.solicitudes_cambio`, con `ambiente = 'produccion'` y su ventana, y si es de estructura o de configuración, primero se prueba en el ambiente de pruebas.
2. Durante: el DBA lo ejecuta dentro de la ventana, sin bajar `log_statement` de `mod` ni apagar el disparador de auditoría, y si cambia la estructura, anota el folio en el comentario del objeto, como `CAM-2026-014` en `clientes.canal_alta`.
3. Después: cada mes, Auditoría interna concilia con los folios las sentencias `CREATE`, `ALTER`, `DROP`, `GRANT` y `REVOKE` de la bitácora exportada, y un cambio sin folio o fuera de su ventana es un hallazgo que se reporta al Comité de cambios.

**Responsable:**

- Aprueba: el propietario del dato, las correcciones de datos, las cuentas y los permisos (POL-01); el Comité de cambios, los demás cambios de infraestructura, configuración y estructura, y Auditoría interna, además, los que cambian lo que registran la bitácora, la auditoría o el perfilador ([evidencia 02](../evidencias/02-responsables.md)).
- Ejecuta: el DBA. Según la Unidad I, en producción solo actúa quien tiene la responsabilidad formal de administrarla.
- Concilia: Auditoría interna, no el DBA que hizo los cambios.

**Excepciones:**

- Un cambio de emergencia, con producción detenida o un incidente de seguridad en curso, lo puede aprobar el Comité de cambios por cualquier medio; el DBA registra el folio ese mismo día y Auditoría interna lo revisa en la siguiente conciliación.
- Apagar el disparador de auditoría solo procede como un mantenimiento con folio, aprobado también por Auditoría interna, como se propuso en el LAB-01 para los cambios masivos ([evidencia 14](../../laboratorio-01-bitacoras-auditoria/evidencias/14-limites.md)).
- La conciliación de la regla 3 no tiene excepciones.

**Evidencia:**

- Los folios: `gobierno.solicitudes_cambio` y su script, `sql/04-registro-cambios.sql`, de la Actividad 7, con el primer folio, `CAM-2026-014`.
- Lo que se ejecutó: las sentencias de estructura y privilegios de la bitácora ([LAB-01, evidencia 06](../../laboratorio-01-bitacoras-auditoria/evidencias/06-privilegios-estructura.md)), que se exporta con su huella en E5 (Actividad 8).
- La conciliación: `evidencias/06-conciliacion.md` (Actividad 7).
- Hoy no existen:
  - un ambiente de pruebas: cada motor tiene un solo servidor, el de producción;
  - folios de los cambios de los LAB-01 y LAB-02, que se hicieron antes de esta política;
  - un registro de quién cambia la estructura en MongoDB: Community no tiene auditoría ([LAB-02, evidencia 01](../../laboratorio-02-trazabilidad-mongodb/evidencias/01-edicion-y-limitacion.md)), y las instantáneas solo cubren los privilegios;
  - una forma de comprobar que nadie bajó `log_statement` en su sesión: un superusuario puede hacerlo con `SET` sin dejar rastro ([LAB-01, evidencia 10](../../laboratorio-01-bitacoras-auditoria/evidencias/10-diseno-auditoria.md)), y lo que cambie después no queda en la bitácora.

**Revisión:** cada año, y después de cada conciliación que encuentre un tipo de cambio que esta política no previó.

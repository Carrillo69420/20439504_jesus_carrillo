# Evidencia 02 — Propietarios, custodios y usuarios

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 2 (sección 8 de la guía)
- Alcance: los conjuntos de datos de `dba-u3-pg` (PostgreSQL 16.15) y de `dba-u3-mongo` (MongoDB 7.0.45), los dos con la base `comercial`
- Fecha: 24 de noviembre de 2026

## Objetivo

Asignar a cada conjunto de datos un propietario, que decide sobre él; un custodio, que lo opera y lo protege, y sus usuarios autorizados, y dejar escrito quién aprueba los accesos y quién aprueba las correcciones.

## Punto de partida

Esta actividad no tiene script ni comandos. Parte de la matriz de gobierno de la Unidad II ([LAB-03, evidencia 11](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md)), que le asignó a cada campo de `clientes` su finalidad, sus usuarios, su protección y su retención. Como pide la guía, esa matriz no se repite: se amplía en tres puntos.

1. **Un propietario por conjunto de datos.** En la Unidad II el responsable se asignó por campo: Atención al cliente para los datos de contacto, Facturación para los fiscales y Analítica para las estadísticas. La sección 4.2 de la guía le asigna la tabla completa a la Gerencia Comercial, y así se toma aquí: la Gerencia Comercial es la propietaria de `clientes` y responde por toda la tabla. Las áreas de la Unidad II pasan a ser usuarios autorizados. Cada una conserva los campos y la protección que ahí se le asignaron, y si necesita algo más, se lo pide a la Gerencia Comercial.
2. **Dos columnas nuevas.** Además del propietario, el custodio y los usuarios, la matriz dice quién aprueba los accesos y quién aprueba las correcciones.
3. **Los conjuntos de datos de esta unidad.** A la tabla de clientes se agregan la tabla de auditoría y la bitácora del LAB-01, y la colección de clientes y el perfilador de MongoDB del LAB-02. También se agregaron, aunque la guía no los pide aquí, la bitácora de `mongod` y las instantáneas de privilegios del LAB-02, y la tabla de solicitudes de cambio de la Actividad 7, porque aparecen en el catálogo (Actividad 4) o en el criterio de conservación (Actividad 5).

Siguen igual los demás papeles de la Unidad II: Dirección aprueba las finalidades y nombra a los propietarios, el responsable de privacidad resuelve las solicitudes ARCO y el área jurídica fija los plazos de conservación.

Hay una figura nueva, **Auditoría interna**: el área que revisa la operación y para la que se arma el expediente de este laboratorio (sección 4.6 de la guía). Es la propietaria de todo lo que sirve como evidencia: la tabla de auditoría, las bitácoras, el perfilador y las instantáneas de privilegios. La razón está en la pregunta 1.

## Matriz de responsables

| Conjunto de datos | Propietario | Custodio | Usuarios autorizados | Quién aprueba accesos | Quién aprueba correcciones |
| --- | --- | --- | --- | --- | --- |
| `comercial.public.clientes` (PostgreSQL) | Gerencia Comercial | DBA | La aplicación de ventas (`app_ventas`), que consulta y actualiza clientes; Atención al cliente (`soporte_ana`), Facturación y Analítica, con los campos que les asignó la Unidad II | Gerencia Comercial | Gerencia Comercial, con el valor que da el cliente. Si la corrección la pide el propio cliente (derecho de rectificación), el responsable de privacidad decide si procede |
| `comercial.auditoria.cambios_clientes` (PostgreSQL) | Auditoría interna | DBA | Auditoría interna, solo para leer. Nadie escribe en ella: sus renglones los inserta el disparador `trg_auditoria_clientes` | Auditoría interna | Nadie: un registro de auditoría no se corrige ni se borra. Si tiene un error, se documenta como hallazgo |
| Bitácora de PostgreSQL: los archivos del directorio `log` y la vista `dba.bitacora` | Auditoría interna | DBA | El DBA, para diagnosticar el servidor; Auditoría interna, en copias exportadas sin secretos y con hash | Auditoría interna | Nadie: la bitácora no se edita. Cambiar lo que registra (`log_statement`, `log_connections`) lo aprueba Auditoría interna |
| `comercial.clientes` (MongoDB) | Gerencia Comercial | DBA | La tienda (`app_ventas@comercial`, con `readWrite` sobre `comercial`) | Gerencia Comercial | Gerencia Comercial, igual que en PostgreSQL |
| `comercial.system.profile` (MongoDB) | Auditoría interna | DBA | El DBA, para diagnosticar el rendimiento; Auditoría interna, en copias exportadas con hash | Auditoría interna | Nadie: lo escribe el servidor y no se edita. Cambiar el nivel o el filtro del perfilador lo aprueba Auditoría interna |
| Bitácora de `mongod` (agregada) | Auditoría interna | DBA | El DBA; Auditoría interna, en copias exportadas con hash | Auditoría interna | Nadie: no se edita |
| `auditoria.instantaneas_privilegios` (MongoDB, agregada) | Auditoría interna | DBA | El DBA, que toma las instantáneas; Auditoría interna, que las compara | Auditoría interna | Nadie: cada instantánea se conserva como se tomó |
| `comercial.gobierno.solicitudes_cambio` (PostgreSQL, agregada; se crea en la Actividad 7) | Comité de cambios | DBA | Las áreas que piden cambios; el comité, que los aprueba; el DBA, que revisa el folio antes de ejecutar, y Auditoría interna, que concilia | Comité de cambios | Comité de cambios. Un folio aprobado no se modifica: si el cambio es otro, se registra un folio nuevo |

El propietario de las solicitudes de cambio no se eligió aquí: lo fija el comentario que la guía le pone a la tabla en la Actividad 7.

### Notas

- **El DBA es custodio de todo y propietario de nada.** Opera los servidores, otorga los permisos que aprueba cada propietario, ejecuta las correcciones aprobadas con una solicitud de cambio (Actividad 7) y reporta los problemas que detecta, como los de la [evidencia 01](01-calidad.md). Es el error 2 de la sección 20 de la guía: «El DBA custodia. El propietario decide».
- **Los clientes tienen el mismo propietario en los dos motores.** Son las mismas personas, y si una corrección se aprueba en un motor, la misma área tiene que decidir sobre el otro.
- **La evidencia no se corrige.** Una evidencia que se puede editar deja de probar lo que pasó. Sobre ella solo se decide quién la lee, cuánto tiempo se conserva (Actividad 5) y qué registra el servidor. Las tres decisiones son de Auditoría interna; los plazos legales los confirma el área jurídica.
- **Las cuentas de hoy no siguen del todo la matriz.** `soporte_ana` tiene SELECT sobre `clientes` ([README del LAB-01](../../laboratorio-01-bitacoras-auditoria/README.md)), y en el LAB-01 consultó el RFC de María García ([informe del LAB-01](../../laboratorio-01-bitacoras-auditoria/informe.md)), un dato que Atención al cliente no usa según la Unidad II. Facturación y Analítica no tienen cuenta en `dba-u3-pg`, y Auditoría interna no tiene cuenta en ningún servidor. Los permisos vigentes se comprueban en la evidencia E2 (Actividad 8).

## Preguntas

**1. ¿Por qué el propietario de `auditoria.cambios_clientes` no debería ser el mismo que opera `clientes`?**

Porque la tabla de auditoría es la evidencia de lo que hacen quienes operan `clientes`. Si fuera de la Gerencia Comercial, el área cuyos usuarios y cuya aplicación hacen los cambios decidiría quién los revisa, cuánto tiempo se guardan y si un registro se puede quitar: controlaría la prueba de su propia operación. Es la separación de funciones: quien ejecuta no controla la evidencia de lo que ejecutó. Por eso la propietaria es Auditoría interna, que no opera la tabla.

En el LAB-01, los permisos ya separaban a la aplicación de su evidencia. `app_ventas` intentó borrar la auditoría y apagar el disparador, y los dos intentos fallaron: no tiene acceso al esquema `auditoria`, y el disparador solo lo puede apagar el dueño de la tabla o un superusuario ([LAB-01, evidencia 13](../../laboratorio-01-bitacoras-auditoria/evidencias/13-manipulacion.md), líneas 36 a 41). El superusuario `postgres`, en cambio, apagó el disparador, cambió el RFC del cliente 3 y lo volvió a encender en 3 milisegundos (líneas 45 a 47), y la tabla de auditoría no registró ese cambio.

Es decir, el custodio también puede alterar la evidencia, así que asignar bien al propietario no basta. Hace falta que la evidencia salga del servidor con un hash y que la revise alguien distinto del DBA. El cambio de las líneas 45 a 47 solo quedó en la bitácora, y por eso en la Actividad 8 la bitácora se exporta con su hash (E5).

**2. ¿Quién debería poder leer las bitácoras y la vista `dba.bitacora`?**

El DBA, para diagnosticar el servidor, y Auditoría interna, para revisar; nunca las cuentas cuya actividad registran, como `app_ventas` o `soporte_ana`. Es lo que se concluyó en el LAB-01 ([evidencia 02](../../laboratorio-01-bitacoras-auditoria/evidencias/02-colector.md)): si la cuenta auditada puede leer la bitácora, sabe qué queda registrado y qué no.

Además, por lo que contienen, las bitácoras son tan sensibles como lo más sensible que haya pasado por la base. La bitácora del LAB-01 guardó cinco secretos: una contraseña en texto claro, la del `CREATE ROLE` de la [evidencia 06](../../laboratorio-01-bitacoras-auditoria/evidencias/06-privilegios-estructura.md), y cuatro resúmenes SCRAM de los `ALTER USER`. Son las líneas 41, 72, 93, 113 y 114 de la copia exportada, y hubo que taparlas antes de sacarla del servidor ([evidencia 15](../../laboratorio-01-bitacoras-auditoria/evidencias/15-cronologia.md)). Con `log_statement = 'mod'` también guarda los valores de cada cambio, como el RFC de la línea 46 de la evidencia 13.

La vista tiene un riesgo más. Lee el archivo con `pg_read_file`, que puede leer cualquier archivo al que tenga acceso el servidor, y por eso, por omisión, solo la puede ejecutar un superusuario. Darle a Auditoría interna permiso sobre la vista obligaría a darle también esa función. Lo correcto es que reciba copias exportadas, sin secretos y con su hash, como `bitacora-lab01.log` del LAB-01 y E5 en la Actividad 8.

Con el perfilador de MongoDB pasa lo mismo: guarda los filtros y los valores nuevos, como el RFC ([LAB-02, evidencia 03](../../laboratorio-02-trazabilidad-mongodb/evidencias/03-perfilador.md)). Según la documentación de MongoDB 7.0 ([Built-In Roles](https://www.mongodb.com/docs/v7.0/reference/built-in-roles/)), el rol `read`, y con él `readWrite`, solo da lectura de las colecciones que no son del sistema y de `system.js`, así que `app_ventas` no debería poder leer `system.profile`. `dbAdmin`, en cambio, sí permite leerlo y cambiar el nivel del perfilador. En la Actividad 7 del LAB-02, `app_ventas` recibió ese rol ([evidencia 07](../../laboratorio-02-trazabilidad-mongodb/evidencias/07-privilegios-control-compensatorio.md)), y según la documentación, mientras lo tuvo, la aplicación podía leer su propio registro y apagarlo. Ninguna de las dos cosas se probó en el laboratorio. Un permiso así no solo da acceso a los clientes, también a la evidencia, y por eso tendría que aprobarlo Auditoría interna, además de la Gerencia Comercial.

**3. ¿Qué ocurre con la responsabilidad sobre un dato cuando nadie la tiene asignada?**

No desaparece: la toma quien tiene el acceso técnico, casi siempre el DBA, que termina decidiendo como si fuera el propietario. O no la toma nadie, y los problemas se quedan como están. En los dos casos, cuando el dato cambia no hay contra qué comparar para saber si el cambio estaba permitido.

Ese fue el problema inicial de la unidad. Facturación reportó que el RFC de María García había cambiado, y a Dirección no se le pudo decir quién lo cambió, porque la bitácora no guardó la sentencia ni la conexión ([LAB-01, evidencia 03](../../laboratorio-01-bitacoras-auditoria/evidencias/03-incidente-sin-bitacora.md)). Hoy, con la bitácora, la auditoría y el perfilador, ya se sabe qué cuenta hizo un cambio, cuándo y desde dónde. Pero queda la otra mitad de la pregunta: si el cambio estaba permitido, y esa no la contesta ningún mecanismo. Para decir que una cuenta no debía cambiar un RFC hace falta saber de quién es el dato, quién autoriza sus correcciones y si hubo una autorización. Sin eso, un cambio registrado no se puede calificar de indebido (sección 1 de la guía).

En la Unidad II ya había un ejemplo: la tabla `clientes_soporte` quedó como una copia sin dueño ni usuarios, y seguía guardando el correo anterior de Ana López ([evidencia 11 de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md)). Nadie respondía por ella, así que nadie decidía si se actualizaba o se eliminaba.

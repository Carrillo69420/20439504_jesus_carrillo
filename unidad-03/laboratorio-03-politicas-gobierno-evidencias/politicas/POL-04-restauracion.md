# POL-04 — Restauración

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-03 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Estado: propuesta del DBA; la aprueba Dirección
- Fecha: 24 de noviembre de 2026

**Objetivo:** reducir el riesgo de que una restauración haga más daño del que corrige. Restaurar reemplaza los datos actuales por los del respaldo, y con eso se pueden perder los cambios posteriores, la evidencia de lo que pasó y las supresiones ya hechas. En `dba-u3-pg` la auditoría es una tabla de la misma base que los clientes: restaurar la base `comercial` completa también la regresaría a la fecha del respaldo, y desaparecerían los renglones del incidente que se quiere corregir.

**Alcance:**

- Datos: lo que respalda POL-02, completo o una parte, como una tabla o una colección.
- Sistemas: `dba-u3-pg` y `dba-u3-mongo`. Ambiente: producción.
- No incluye la prueba mensual de POL-02, que se hace en un ambiente aislado.

**Regla:**

1. Toda restauración en producción lleva un folio en `gobierno.solicitudes_cambio`, aprobado por el propietario de los datos que se restauran, y solo se aprueba si el daño no se puede corregir con una corrección de datos (POL-06).
2. Antes de restaurar, el DBA exporta con su huella la auditoría y la bitácora de lo que se va a reemplazar, y Auditoría interna confirma que las recibió.
3. Después, el DBA vuelve a aplicar las supresiones que las constancias de POL-03 registran desde la fecha del respaldo, y el propietario revisa los datos restaurados y firma el acta.

El procedimiento técnico se definirá en la Unidad V: esta política solo fija quién autoriza, quién ejecuta y en qué condiciones.

**Responsable:**

- Autoriza: el propietario de los datos, según la [evidencia 02](../evidencias/02-responsables.md): la Gerencia Comercial, en los clientes, y Auditoría interna, en la evidencia. Si la restauración alcanza las dos, como la de la base `comercial` completa, autorizan las dos.
- Ejecuta: el DBA.
- Comprueba: el propietario, con el acta.

**Excepciones:** si producción está detenida y el propietario no responde, autoriza Dirección, y el folio se registra el mismo día. La exportación de la regla 2 solo se omite si ya no queda nada que exportar, por ejemplo porque se perdió el volumen, y eso se anota en el acta.

**Evidencia:** hoy no existe: en los LAB-01 a LAB-03 no se hizo ninguna restauración. Cuando exista, la evidencia será el folio, las exportaciones previas con su huella, las líneas de la bitácora de la sesión que restauró y el acta firmada por el propietario.

**Revisión:** cada año, después de cada restauración y cuando la Unidad V defina el procedimiento técnico.

# Evidencia 15 — Bitácora exportada y cronología

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividades 16 y 17 (secciones 22 y 23 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 31 de octubre de 2026

## Objetivo

Sacar la bitácora del servidor, sin secretos y con un hash que permita detectar cambios, y usarla junto con la auditoría para reconstruir lo ocurrido y responder a Dirección.

## Pasos y resultados

### 1. Qué se exportó (Actividad 16)

La consulta de la guía exporta solo el archivo vigente. Este servidor se apagó el 29 de octubre y volvió a arrancar el 31, así que la bitácora del laboratorio está en dos archivos:

| Archivo | Líneas al exportar | Qué contiene |
| --- | --- | --- |
| `postgresql-2026-10-29_103255.log` | 181 | Del arranque de la Actividad 2 a la Actividad 11 |
| `postgresql-2026-10-31_094251.log` | 60 | Actividades 12 a 15 y la conexión de esta exportación |

Exportar solo el vigente dejaría fuera los accesos fallidos, el `GRANT`, el `ALTER TABLE` y los cambios de configuración que pide la sección 26. Por eso los dos archivos van juntos y en orden en `bitacora-lab01.log`, el único archivo que pide la guía.

Las líneas 1 a 181 del exportado son el archivo del 29 de octubre, con el mismo número que tenían. Las evidencias 11 a 14 citan el número dentro del archivo del 31 de octubre, así que en el exportado hay que sumarle 181: el `UPDATE` de la Actividad 12 es la línea 15 en la [evidencia 11](11-incidente-auditado.md) y la 196 aquí.

### 2. La exportación

```powershell
docker exec dba-u3-pg psql -U postgres -d comercial -At -o /tmp/bitacora-lab01.log -c "SELECT regexp_replace(pg_read_file('log/postgresql-2026-10-29_103255.log') || pg_read_file(pg_current_logfile()), 'PASSWORD ''[^'']*''', 'PASSWORD ''<REDACTED>''', 'gi')"
```

| Parte | Qué hace |
| --- | --- |
| `-At` | Salida sin alineación ni encabezados |
| `-o /tmp/bitacora-lab01.log` | Guarda el resultado en un archivo dentro del contenedor |
| `pg_read_file(...)` | Lee un archivo de bitácora; `pg_current_logfile()` da el nombre del vigente |
| `regexp_replace(texto, patrón, reemplazo, 'gi')` | Sustituye lo que coincida con el patrón antes de que salga del servidor: `g` todas las veces, `i` sin distinguir mayúsculas |

`||` une los dos textos. El patrón `PASSWORD '[^']*'` es la palabra `PASSWORD`, una comilla, cualquier cantidad de caracteres que no sean comilla y otra comilla. Dentro de un texto SQL, cada comilla se escribe doble.

Hay dos diferencias con el comando de la guía:

- **Un patrón en lugar de un valor.** La guía sustituye una contraseña escribiéndola en el comando. Aquí había cinco líneas con secretos: la contraseña del `CREATE ROLE` (línea 41) y cuatro resúmenes SCRAM de los `ALTER USER` (líneas 72, 93, 113 y 114). El patrón las cubre todas, y la contraseña no queda escrita en el comando.
- **`-o` en lugar de `>`.** En PowerShell 5.1, `>` guarda la salida en UTF-16, con casi el doble de tamaño y otro hash. Con `-o`, el archivo se crea dentro del contenedor y `docker cp` lo copia tal cual.

### 3. El hash y la copia al equipo

Hash dentro del servidor:

```powershell
docker exec dba-u3-pg sh -c "cd /tmp && sha256sum bitacora-lab01.log > bitacora-lab01.sha256 && cat bitacora-lab01.sha256"
```

```text
3a9fe43ad4b5f063488d3232103fa82c4b4482491fa9a745c5ee3204475fa470  bitacora-lab01.log
```

Copia al equipo y hash en Windows. En los comandos se usó la ruta completa de la carpeta del laboratorio; aquí se abrevia con `...`:

```powershell
docker cp dba-u3-pg:/tmp/bitacora-lab01.log "...\evidencias\bitacora-lab01.log"
docker cp dba-u3-pg:/tmp/bitacora-lab01.sha256 "...\evidencias\bitacora-lab01.sha256"
(Get-FileHash "...\evidencias\bitacora-lab01.log" -Algorithm SHA256).Hash
```

```text
Successfully copied 34.7kB (transferred 36.4kB) to ...\evidencias\bitacora-lab01.log
Successfully copied 85B (transferred 2.05kB) to ...\evidencias\bitacora-lab01.sha256
3A9FE43AD4B5F063488D3232103FA82C4B4482491FA9A745C5EE3204475FA470
```

Las dos huellas son la misma: una sale en minúsculas y la otra en mayúsculas. El archivo llegó igual a como salió del servidor. `bitacora-lab01.sha256` queda en el formato de `sha256sum`, así que en Linux o en Git Bash se comprueba desde `evidencias/` con `sha256sum -c bitacora-lab01.sha256`. Al terminar se borraron las dos copias temporales de `/tmp`.

### 4. Revisión antes de subirla

```powershell
(Select-String -Path "...\evidencias\bitacora-lab01.log" -Pattern "PASSWORD '").LineNumber -join ' '
(Select-String -Path "...\evidencias\bitacora-lab01.log" -Pattern "PASSWORD '<REDACTED>'").LineNumber -join ' '
(Select-String -Path "...\evidencias\bitacora-lab01.log" -Pattern 'SCRAM-SHA-256\$').Count
```

```text
41 72 93 113 114
41 72 93 113 114
0
```

- Las cinco líneas con `PASSWORD '` son las mismas cinco que quedaron tapadas.
- No queda ningún resumen. `\$` busca el signo de pesos que sigue al nombre del algoritmo en un resumen. Sin él, la búsqueda también contaría `method=scram-sha-256` y las reglas de `pg_hba.conf`, que no son secretos, porque `Select-String` no distingue mayúsculas.
- Comparado línea por línea con los dos archivos originales, el exportado solo difiere en esas cinco líneas.
- Las líneas 240 y 241 son la conexión de la propia exportación, y la 242 está vacía porque `psql` agrega un salto de línea al resultado. La desconexión de esa sesión no aparece porque ocurrió después de leer el archivo.

### 5. Que Git no cambie el archivo

En este equipo, Git tiene activo `core.autocrlf`, que cambia los fines de línea de los archivos de texto al sacarlos del repositorio. Eso cambiaría el hash sin que nadie tocara el contenido. Por eso la carpeta del laboratorio tiene un [`.gitattributes`](../.gitattributes):

```text
evidencias/bitacora-lab01.log -text
evidencias/bitacora-lab01.sha256 -text
```

```powershell
git ls-files --eol evidencias/bitacora-lab01.log
```

```text
i/lf    w/lf    attr/-text            	evidencias/bitacora-lab01.log
```

`i/lf` es lo guardado en Git y `w/lf` la copia de trabajo: los dos tienen fines de línea de Linux. `attr/-text` indica que Git no debe convertirlos.

### 6. La cronología (Actividad 17)

Las líneas son las de `bitacora-lab01.log`, y los eventos son los `id_evento` de `auditoria.cambios_clientes`. Las horas son las del servidor, en hora del Pacífico de México (UTC−7). «Socket local» corresponde a `client=[local]`.

| # | Fecha y hora | Usuario | Cliente | Tipo de evento | Qué ocurrió | ¿Exitoso? | Fuente |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 29/10 10:32:55.607 | — | — | Servidor | Arranca con el colector activo. Todavía no registra conexiones ni sentencias | Sí | Línea 6 |
| 2 | 29/10 10:53:23.997 | — | — | Configuración | Se aplican `log_connections`, `log_disconnections`, el prefijo nuevo y `log_statement = 'ddl'`. No se registró quién lo pidió | Sí | Líneas 12 a 15 |
| 3 | 29/10 11:00:33.439 | `app_ventas` | 127.0.0.1 | Acceso | Contraseña incorrecta | No | Línea 20 |
| 4 | 29/10 11:00:38.191 | `usuario_inexistente` | 127.0.0.1 | Acceso | El usuario no existe | No | Líneas 23 y 24 |
| 5 | 29/10 11:00:57.745 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Acceso | Entra y sale en 17 milisegundos | Sí | Líneas 29 y 30 |
| 6 | 29/10 11:20:18.913 | `postgres` | Socket local, `psql` | Privilegio | `REVOKE UPDATE ON clientes FROM soporte_ana` | Sí | Línea 33 |
| 7 | 29/10 11:20:18.918 | `postgres` | Socket local, `psql` | Privilegio | `GRANT UPDATE ON clientes TO app_ventas` | Sí | Línea 34 |
| 8 | 29/10 11:20:18.920 | `postgres` | Socket local, `psql` | Estructura | `ALTER TABLE clientes ADD COLUMN segmento` | Sí | Línea 35 |
| 9 | 29/10 11:20:25.157 | `postgres` | Socket local, `psql` | Error | `DROP ROLE rol_temporal`: el rol no existe | No | Líneas 36 y 37 |
| 10 | 29/10 11:33:22.213 a 11:43:22.856 | `app_ventas` | 127.0.0.1 | Acceso | Cuatro contraseñas rechazadas | No | Líneas 47, 56, 65 y 68 |
| 11 | 29/10 11:33:38.531 y 11:39:36.188 | `postgres` | Socket local, `psql` | Configuración | `log_statement` pasa a `mod` y regresa a `ddl` | Sí | Líneas 51, 54, 60 y 63 |
| 12 | 29/10 11:49:31.350 | `postgres` | Socket local, `psql` | Privilegio | Cambia la contraseña de `app_ventas` (valor tapado) | Sí | Línea 72 |
| 13 | 29/10 11:49:46.239 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Acceso | Sesión de 14 milisegundos. No se registró qué hizo: `log_statement` estaba en `ddl` | Sí | Líneas 76 y 77 |
| 14 | 29/10 11:51:02.283 | `postgres` | Socket local, `psql` | Configuración | `log_statement` pasa a `mod` | Sí | Líneas 80 y 83 |
| 15 | 29/10 11:51:13.931 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Datos | Cambia el teléfono del cliente 3 a `6679990000` | Sí | Línea 87 |
| 16 | 29/10 11:59:07.890 | `soporte_ana` | 127.0.0.1, `psql` | Error | `DELETE FROM clientes WHERE id = 5`: sin permiso | No | Líneas 98 y 99 |
| 17 | 29/10 12:10:56.000 | `soporte_ana` | 127.0.0.1 | Acceso | Contraseña incorrecta | No | Línea 111 |
| 18 | 29/10 12:49:41.837 a 12:57:57.649 | `postgres` | Socket local, `psql` | Estructura | Crea el esquema `auditoria`, su tabla, la función y el disparador. Desde aquí se audita el dato | Sí | Líneas 130 a 172 |
| 19 | 29/10 13:01:35.374 | — | — | Servidor | Se apaga | Sí | Línea 181 |
| 20 | 31/10 09:42:51.718 | — | — | Servidor | Arranca. Confirma que se había apagado a las 13:01:35 del 29, así que entre los dos archivos no falta tiempo de servicio | Sí | Líneas 186 y 187 |
| 21 | 31/10 09:50:08.326 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Datos | Cambia el RFC del cliente 3 de `GAMA780912XYZ` a `GAMA780912ZZZ` | Sí | Línea 196, evento 1 |
| 22 | 31/10 09:53:37.271 | `app_ventas` | 127.0.0.1, `psql` | Error | Intenta leer la auditoría: sin permiso sobre el esquema | No | Líneas 203 y 204 |
| 23 | 31/10 09:58:15.892 | `postgres` | Socket local, `psql` | Datos | Da de alta a Pedro Ruiz (id 6) | Sí | Líneas 208 y 209, evento 2 |
| 24 | 31/10 09:58:23.769 | `postgres` | Socket local, `psql` | Datos | Da de baja a Pedro Ruiz | Sí | Línea 210, evento 3 |
| 25 | 31/10 10:04:56.378 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Error | Intenta borrar la auditoría: sin permiso | No | Líneas 217 y 218 |
| 26 | 31/10 10:04:56.378 | `app_ventas` | 127.0.0.1, `app-ventas-web` | Error | Intenta apagar el disparador: no es dueño de la tabla | No | Líneas 220 y 221 |
| 27 | 31/10 10:05:15.746 | `postgres` | Socket local, `psql` | Estructura | Apaga el disparador | Sí | Línea 226 |
| 28 | 31/10 10:05:15.748 | `postgres` | Socket local, `psql` | Datos | Cambia el RFC del cliente 3 a `GAMA780912GHI`, sin registro de auditoría | Sí | Línea 227 |
| 29 | 31/10 10:05:15.749 | `postgres` | Socket local, `psql` | Estructura | Vuelve a encender el disparador | Sí | Línea 228 |
| 30 | 31/10 10:07:37.088 | `soporte_ana` | 127.0.0.1, `psql` | Acceso | Sesión de 6 milisegundos. No se registró qué leyó | Sí | Líneas 231 a 233 |
| 31 | 31/10 10:07:44.393 | `postgres` | Socket local, `psql` | Datos | Cambia `segmento` en los cinco clientes con un solo `UPDATE` | Sí | Línea 236, eventos 4 a 8 |

### 7. Lo que no quedó registrado

Estos hechos no llevan número ni hora en la tabla: no se registraron, así que no se estiman.

| Hueco | Por qué no hay registro | Lo único que queda |
| --- | --- | --- |
| Cambio del RFC a `GAMA780912XXX` (Actividad 3) | `log_statement` estaba en `none` y no se registraban conexiones. La auditoría no existía. Las líneas 1 a 10 solo traen el arranque y dos checkpoints | El valor en la tabla, visto en la consulta de la [evidencia 03](03-incidente-sin-bitacora.md) |
| Cambio del RFC a `GAMA780912XYZ` (Actividad 7) | `log_statement` estaba en `ddl`, que no registra `UPDATE`. La auditoría no existía | La sesión de las líneas 76 y 77, que no dice qué hizo, y el valor en `valores_antes` del evento 1 |
| Valor anterior del teléfono | La bitácora guarda la sentencia con el valor nuevo, y la auditoría no existía | Solo el valor nuevo (línea 87) |
| Lecturas de `clientes` (Actividades 7 y 15) | `mod` no registra `SELECT`, y el disparador no se activa con lecturas | Las conexiones, como las líneas 231 a 233 |

## Análisis

### Actividad 16: conservar la bitácora

**Un resumen SHA-256, ¿impide que alguien modifique la bitácora? ¿Qué permite demostrar?**

No. El archivo se puede seguir editando. Lo que permite es detectar el cambio: si alguien modifica un solo carácter y se vuelve a calcular el hash, ya no coincide con el guardado. Demuestra que el archivo no ha cambiado desde que se calculó el hash, y nada más:

- No demuestra que el contenido sea cierto o esté completo. El hash se calculó sobre lo que ya había, con sus huecos.
- No dice quién hizo un cambio ni cuándo, solo que lo hubo.
- Este hash es de la copia exportada, con las cinco líneas tapadas, no de los archivos originales del servidor.
- Solo sirve si el hash guardado es de fiar: quien pueda cambiar el archivo y también el hash no deja diferencia.

**¿Dónde debería guardarse el hash para que sea útil como control de integridad?**

Lejos de quien puede modificar la bitácora. NIST pide guardar el resumen de forma segura y protegerlo contra alteraciones, por ejemplo en un medio de solo lectura (sección 3.2). Si el hash se queda junto a la bitácora, en el mismo servidor, quien controle el servidor cambia los dos y no queda diferencia.

En este laboratorio, `bitacora-lab01.sha256` está al lado de la bitácora, como pide la guía. Eso por sí solo no protege: con permiso de escritura se podrían cambiar los dos en otro commit. Lo que ayuda es que ya salieron de `dba-u3-pg` y quedan en el historial de Git, en GitHub, donde un cambio posterior se ve como otro commit. En una empresa lo razonable sería entregar el hash a otra área, como auditoría interna, en un medio que el DBA no pueda editar.

**La guía NIST SP 800-92 trata la conservación y protección de bitácoras. ¿Qué riesgos tiene conservar la bitácora solo en el servidor que la produce?**

- **Que la alteren o la borren.** Una bitácora mal protegida se puede alterar o destruir, y con eso ocultar lo ocurrido o quién lo hizo (sección 2.3.2). En un incidente, quien comprometió el servidor puede modificar las bitácoras de ese servidor, pero normalmente no las que están en otra parte (sección 5.1.2). La [evidencia 13](13-manipulacion.md) mostró lo mismo con el administrador: controla el dato y también lo que lo vigila.
- **Perderla junto con el servidor.** Si falla el disco o se recrea el servidor, la evidencia se va con él. Aquí la bitácora está en el volumen `dba-u3-pg-data`: borrar el volumen borraría los datos y también el registro de lo que les pasó.
- **Que no alcance el espacio.** Si la bitácora tiene un límite de tamaño, puede sobrescribir lo viejo o dejar de registrar, y conservarla más tiempo del que soporta el servidor obliga a archivarla (sección 2.3.2).
- **Que cualquiera con acceso lea lo que contiene.** Las bitácoras pueden capturar contraseñas (sección 2.3.2), como la línea 41 antes de taparla.
- **No tener con qué comparar.** Con una copia en el servidor y otra fuera, se puede ver qué se cambió o se quitó (sección 5.1.2). Con una sola, no.

**Propón durante cuánto tiempo conservarías esta bitácora y justifica tu criterio.**

Se propone conservarla en dos lugares, con plazos distintos:

| Dónde | Plazo | Para qué |
| --- | --- | --- |
| En el servidor | 3 meses | Revisar incidentes recientes sin pedir el archivo |
| Fuera del servidor, con su hash y acceso restringido | 12 meses | Investigar lo que se detecta tarde |
| Copia preservada por una investigación o reclamación | Hasta que se cierre | Lo que NIST llama preservación: guardar lo que normalmente se descartaría (sección 3.2) |

- **Por qué no menos.** El incidente de este laboratorio lo detectó un reporte de facturación, no una alerta. NIST advierte que los datos de un evento pueden necesitarse semanas o meses después (sección 4.2), y doce meses cubren un ejercicio fiscal completo.
- **Por qué no más.** La bitácora también trae datos personales, como el correo y el RFC de Pedro Ruiz (línea 209), y conservarlos también es tratarlos (LFPDPPP, art. 2, fr. XIX). Guardarla sin límite crea más copias que proteger y depurar ([evidencia 14](14-limites.md)).
- **La referencia.** NIST no da una cifra obligatoria. Sus ejemplos van de 1 a 2 semanas en sistemas de bajo impacto a entre 3 y 12 meses en los de alto impacto (tabla 4-1), y aclara que no deben adoptarse tal cual. Se usa el extremo alto porque `clientes` tiene datos personales y fiscales.
- **Los cinco años del CFF (art. 30).** La [política de retención de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/10-retencion.md) los usó para la documentación fiscal, como las facturas. Esta bitácora no es documentación fiscal, así que no se aplicaron; si una revisión fiscal necesitara una parte de ella, se preservaría.

Es una propuesta. Según la [matriz de gobierno de la Unidad II](../../../unidad-02/laboratorio-03-privacidad-cumplimiento/evidencias/11-gobierno-datos.md), el plazo lo fija el área jurídica, y el criterio formal se completa en el LAB-03.

### Actividad 17: las preguntas de Dirección

Dirección preguntó quién hizo el cambio, cuándo, desde qué aplicación o equipo, si hubo intentos fallidos antes y qué valor tenía el RFC antes del cambio (sección 5 de la guía). Para cada cambio del RFC de María García:

| Cambio | RFC nuevo | ¿Quién? | ¿Cuándo? | ¿Desde qué aplicación o equipo? | ¿Valor anterior? | Fuente |
| --- | --- | --- | --- | --- | --- | --- |
| Actividad 3 | `GAMA780912XXX` | No hay evidencia | No hay evidencia | No hay evidencia | No hay evidencia | — |
| Actividad 7 | `GAMA780912XYZ` | No hay evidencia | No hay evidencia | No hay evidencia | No hay evidencia | — |
| Actividad 12 | `GAMA780912ZZZ` | `app_ventas` | 31/10 09:50:08.326 | 127.0.0.1, `app-ventas-web` | `GAMA780912XYZ` | Línea 196, evento 1 |
| Actividad 14 | `GAMA780912GHI` | `postgres` | 31/10 10:05:15.748 | Socket local, `psql` | `GAMA780912ZZZ`, por deducción | Línea 227, eventos 1 y 8 |

**¿Quién cambió el RFC la primera vez (Actividad 3)? ¿Y en las Actividades 7, 12 y 14?**

- **Actividad 3: no hay evidencia.** El servidor no guardó la conexión ni la sentencia, y la auditoría no existía. Que fue `app_ventas` se sabe solo porque el cambio se simuló así ([evidencia 03](03-incidente-sin-bitacora.md)).
- **Actividad 7: no hay evidencia.** La bitácora muestra a `app_ventas` conectada 14 milisegundos a las 11:49:46 (líneas 76 y 77), pero no qué hizo en ese tiempo ([evidencia 07](07-modificaciones.md)). Una conexión no demuestra una modificación.
- **Actividad 12: `app_ventas`.** Lo dicen por separado la bitácora (línea 196) y la auditoría (evento 1), y coinciden en la hora, la IP y la aplicación.
- **Actividad 14: `postgres`.** Solo lo dice la bitácora (línea 227). La auditoría no lo registró porque el disparador estaba apagado (líneas 226 a 228).

En todos los casos la evidencia identifica una cuenta, no a una persona. `app_ventas` la usa la aplicación y cualquiera que conozca su contraseña. `postgres` entró por el socket con la regla `trust`, así que solo dice qué nombre se usó ([evidencia 12](12-altas-bajas.md)). Y `app-ventas-web` lo declara el propio cliente al conectarse ([evidencia 10](10-diseno-auditoria.md)).

**¿Quién cambió el teléfono?**

`app_ventas`, el 29 de octubre a las 11:51:13.931, desde 127.0.0.1 con `app-ventas-web` (línea 87). Puso `6679990000`. Qué valor había antes: no hay evidencia, porque la bitácora solo guarda la sentencia y la auditoría todavía no existía.

**¿Hubo intentos de acceso fallidos? ¿De qué usuarios y desde dónde?**

Sí, siete, todos el 29 de octubre y desde 127.0.0.1:

| Usuario | Intentos | Horas | Líneas |
| --- | --- | --- | --- |
| `app_ventas` | 5 | 11:00:33, 11:33:22, 11:34:05, 11:39:45 y 11:43:22 | 20, 47, 56, 65 y 68 |
| `usuario_inexistente` | 1 | 11:00:38 | 23 |
| `soporte_ana` | 1 | 12:10:56 | 111 |

- **Desde dónde.** 127.0.0.1 es el propio contenedor, porque las conexiones se hicieron con `docker exec`. Aquí la IP no distingue un equipo de otro.
- **Por qué fallaron.** La bitácora dice que fallaron, no por qué: no distingue un error de captura de un ataque. La secuencia sí deja una pregunta para investigar: cuatro rechazos de `app_ventas`, `postgres` le cambia la contraseña a las 11:49:31 (línea 72) y 15 segundos después la cuenta entra (línea 76).
- **¿Antes del cambio?** Antes del cambio de la Actividad 12 hubo cinco de `app_ventas`, el último 46 horas antes, y ninguno ese día. Para los cambios de las Actividades 3 y 7 no se puede decir, porque no tienen hora.

**¿Qué valor tenía el RFC antes de cada cambio?**

- **Actividad 3: no hay evidencia en los registros del servidor.** `GAMA780912GHI` es lo que se cargó en la sección 6.5, y esa carga tampoco quedó registrada.
- **Actividad 7: no hay evidencia en los registros del servidor.** `GAMA780912XXX` solo aparece en la consulta guardada en la [evidencia 03](03-incidente-sin-bitacora.md), un resultado sin hora.
- **Actividad 12: `GAMA780912XYZ`.** Está en `valores_antes` del evento 1. Es el primer cambio en el que el servidor lo demuestra.
- **Actividad 14: `GAMA780912ZZZ`, por deducción.** Ese cambio no guardó el valor anterior. Se deduce porque el evento 1 terminó en ese valor y, entre las líneas 196 y 227, la bitácora no tiene otro `UPDATE` del RFC. El evento 8 confirma el valor nuevo: su `rfc_antes` es `GAMA780912GHI`.

## Conclusión

La bitácora salió del servidor sin secretos, con un hash comprobado dentro del servidor y en Windows, y protegida contra las conversiones de Git. Ese hash no impide cambios, pero permite detectarlos si se guarda lejos de quien puede hacerlos. Con ella se reconstruyó lo ocurrido: de los dos primeros cambios del RFC no se puede responder nada, porque lo que no se registró en su momento no se recupera después. Con `log_statement = 'mod'` y el disparador, el cambio de la Actividad 12 se responde completo, con dos fuentes que coinciden. El de la Actividad 14 marca el límite: solo lo registra la bitácora, y solo demuestra qué cuenta se usó. Por eso la bitácora tiene que salir del servidor y la tiene que revisar alguien distinto de quien lo administra.

## Referencias

- Guía del LAB-01 de la Unidad III, secciones 5, 22 y 23.
- NIST. SP 800-92: Guide to Computer Security Log Management, septiembre de 2006. Secciones 2.3.2, 3.2, 4.2 (tabla 4-1) y 5.1.2: https://csrc.nist.gov/pubs/sp/800/92/final
- Ley Federal de Protección de Datos Personales en Posesión de los Particulares, artículo 2, fracción XIX. Texto vigente, última reforma publicada en el DOF el 14 de noviembre de 2025. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/LFPDPPP.pdf
- Código Fiscal de la Federación, artículo 30. Texto vigente, última reforma publicada en el DOF el 9 de abril de 2026. Cámara de Diputados: https://www.diputados.gob.mx/LeyesBiblio/pdf/CFF.pdf

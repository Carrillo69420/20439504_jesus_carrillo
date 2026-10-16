# Evidencia 03 — El problema de la gestión de claves

LAB-02, Actividad 3 (sección 9 de la guía). No tiene script propio: el archivo de demostración `sql/ejemplo-mala-practica.sql` era temporal y se borró antes de cualquier commit, como pide la sección 9.2.

## Objetivo

Identificar por qué escribir la clave de cifrado dentro del código es una mala práctica y comprobar en qué lugares del entorno quedó copiada la clave que se usó en la Actividad 2.

## Comando o procedimiento

Todo se hizo el 15/10/2026; los comandos se corrieron en PowerShell, desde la raíz del repositorio.

**Archivo de mala práctica (sección 9.1).** Se creó `sql/ejemplo-mala-practica.sql` con la consulta de la guía, que lleva la clave escrita en el código. La clave es ficticia, y el archivo no se ejecutó porque la guía solo pide crearlo y analizarlo:

```sql
SELECT pgp_sym_decrypt(
    rfc_cifrado,
    'CLAVE-DE-PRUEBA'
)
FROM clientes_protegidos;
```

**¿Git ya ve el archivo?**

```powershell
git status --short
```

**¿Dónde más quedó la clave?** En el registro de la sesión de psql de las Actividades 1 y 2 (`-L /tmp/lab02.log`), en el historial de psql y en el log del servidor, en el minuto en que falló el descifrado con la clave incorrecta:

```powershell
docker exec dba-practica grep -n "CLAVE" /tmp/lab02.log
docker exec dba-practica grep -n "CLAVE" /root/.psql_history
docker logs --since 2026-10-15T12:04:00 --until 2026-10-15T12:05:00 dba-practica
```

**Limpieza (sección 9.2).** Se borró el archivo temporal y se comprobó que no quedó en Git:

```powershell
git status
git log --all --oneline -- unidad-02/laboratorio-02-cifrado-credenciales/sql/ejemplo-mala-practica.sql
git ls-files unidad-02/laboratorio-02-cifrado-credenciales/sql
```

## Resultado obtenido

Antes de borrarlo, Git ya mostraba el archivo como nuevo y sin seguimiento:

```text
?? unidad-02/laboratorio-02-cifrado-credenciales/sql/ejemplo-mala-practica.sql
```

En el registro de psql aparecen las dos claves: la de prueba en el cifrado y en el descifrado, y la incorrecta en el intento que falló:

```text
201:    pgp_sym_encrypt('LOPA900101ABC', 'CLAVE-DE-PRUEBA')
222:        'CLAVE-DE-PRUEBA'
238:        'CLAVE-INCORRECTA'
```

En el historial, que psql escribe al cerrar la sesión, están las mismas tres consultas completas. psql guarda cada consulta en un solo renglón y cambia los saltos de línea por un carácter de control (0x01), que aquí se omite:

```text
63:INSERT INTO clientes_protegidos (    nombre,    rfc_cifrado)VALUES (    'Ana López',    pgp_sym_encrypt('LOPA900101ABC', 'CLAVE-DE-PRUEBA'));SELECT *FROM clientes_protegidos;
64:SELECT    id,    nombre,    pgp_sym_decrypt(        rfc_cifrado,        'CLAVE-DE-PRUEBA'    ) AS rfcFROM clientes_protegidos;
65:SELECT    id,    nombre,    pgp_sym_decrypt(        rfc_cifrado,        'CLAVE-INCORRECTA'    ) AS rfcFROM clientes_protegidos;
```

En el log del servidor quedó la consulta que falló, completa y con la clave:

```text
2026-10-15 12:04:10.979 MST [681] ERROR:  Wrong key or corrupt data
2026-10-15 12:04:10.979 MST [681] STATEMENT:  SELECT
	    id,
	    nombre,
	    pgp_sym_decrypt(
	        rfc_cifrado,
	        'CLAVE-INCORRECTA'
	    ) AS rfc
	FROM clientes_protegidos;
```

Después de borrar el archivo, `git status` respondió:

```text
On branch lab-02-cifrado-credenciales
Your branch is up to date with 'origin/lab-02-cifrado-credenciales'.

nothing to commit, working tree clean
```

`git log --all` no devolvió ningún commit para `ejemplo-mala-practica.sql`, y `git ls-files` solo lista los dos scripts que sí forman parte de la entrega:

```text
unidad-02/laboratorio-02-cifrado-credenciales/sql/01-credenciales.sql
unidad-02/laboratorio-02-cifrado-credenciales/sql/02-cifrado-datos.sql
```

## Análisis

**¿Qué ocurriría si esta clave fuera una clave utilizada realmente por una organización y el archivo se publicara en un repositorio Git?** Cualquiera con acceso al repositorio tendría la clave y podría descifrar todos los RFC de `clientes_protegidos`, tanto en la base como en cualquier respaldo o copia que consiga, así que el cifrado dejaría de proteger. Borrar el archivo en un commit posterior no lo arregla: el historial de Git conserva el commit que lo agregó, y cada clon del repositorio ya tiene una copia. Si el repositorio es público, además, hay herramientas automáticas que revisan los repositorios buscando claves y contraseñas. Lo único que resuelve el problema es dar la clave por comprometida: generar una nueva, volver a cifrar todos los RFC con ella y dejar de usar la anterior. Reescribir el historial para quitar el archivo ayuda, pero no borra las copias que ya salieron. Y como el RFC es un dato personal, la organización tendría un incidente de seguridad con datos de sus clientes.

**Lo que mostró el entorno del laboratorio.** El archivo era solo una de las copias. Con ejecutar las consultas de la Actividad 2, la clave ya había quedado en otros tres lugares que nadie pensó para guardar secretos: el registro de psql, el historial de psql y el log del servidor. Quien pueda leer esos archivos (administradores, respaldos, herramientas de monitoreo) puede leer la clave. El log del servidor solo guardó la clave incorrecta porque este servidor únicamente registra las sentencias que fallan (`log_statement = none` y `log_min_error_statement = error`). Si una consulta con la clave real fallara, quedaría registrada igual, y con `log_statement = 'all'`, que a veces se activa para depurar, quedarían todas.

**Git y la regla 9.2.** Git ya veía el archivo (`??`). La sección 21 de la guía usa `git add .` antes de cada commit, así que bastaba un commit más para que entrara al historial. Por eso, desde la Actividad 2, los archivos se agregan por nombre, y el temporal se borró antes de cualquier commit; `git log --all` confirma que ningún commit lo contiene. La clave ficticia sí está en `sql/02-cifrado-datos.sql` y en `evidencias/02-cifrado-datos.md`, porque la Actividad 2 la pide así. Eso se permite solo porque es ficticia: con una clave real, esos dos archivos ya serían una filtración.

## Conclusión

Escribir la clave en el código hace que se copie a todos lados: al script, a Git si se sube, al registro y al historial de psql, y al log del servidor cuando una consulta falla. Aquí la clave es ficticia, pero con una real bastaría cualquiera de esas copias para descifrar todos los RFC, y borrar el archivo después no la recupera. Por eso el archivo de demostración se borró antes de cualquier commit, y una clave real debe administrarse fuera del código y del repositorio, como se define en la Actividad 10.

# Evidencia 02 — Cifrado de información sensible

LAB-02, Actividad 2 (sección 8 de la guía). Script: [`sql/02-cifrado-datos.sql`](../sql/02-cifrado-datos.sql). Capturas: [`02-cifrado-datos.pdf`](02-cifrado-datos.pdf).

## Objetivo

Proteger el RFC con cifrado simétrico (`pgp_sym_encrypt()` de pgcrypto), comprobar que en la tabla ya no se puede leer y que solo se recupera con la clave correcta.

## Comando o procedimiento

El script se ejecutó el 15/10/2026 en la misma sesión de `psql` de la Actividad 1 (contenedor `dba-practica`, base `comercializadora`, registro con `-L /tmp/lab02.log`). Antes se activó `\pset format wrapped`, para que el RFC cifrado, de 160 caracteres, se partiera dentro de su columna en lugar de desbordar la ventana.

**Tabla de demostración (sección 8.1).** El RFC se guarda en una columna `BYTEA`, porque el resultado del cifrado son bytes y no texto:

```sql
CREATE TABLE clientes_protegidos (
    id BIGSERIAL PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    rfc_cifrado BYTEA NOT NULL
);
```

**Cifrado.** `'CLAVE-DE-PRUEBA'` es una clave ficticia, solo para la práctica:

```sql
INSERT INTO clientes_protegidos (
    nombre,
    rfc_cifrado
)
VALUES (
    'Ana López',
    pgp_sym_encrypt('LOPA900101ABC', 'CLAVE-DE-PRUEBA')
);
```

**Recuperación (sección 8.2).** La misma consulta con la clave correcta y con `'CLAVE-INCORRECTA'`:

```sql
SELECT
    id,
    nombre,
    pgp_sym_decrypt(
        rfc_cifrado,
        'CLAVE-DE-PRUEBA'
    ) AS rfc
FROM clientes_protegidos;
```

## Resultado obtenido

Sesión: `postgres | comercializadora | 2026-10-15 12:01:49.317597-07`.

El `DROP TABLE IF EXISTS` avisó `table "clientes_protegidos" does not exist, skipping`, porque la tabla aún no existía; después salieron `CREATE TABLE` e `INSERT 0 1`.

`SELECT * FROM clientes_protegidos;` devolvió la fila de Ana López, pero en `rfc_cifrado` solo aparecen bytes en hexadecimal (79 bytes):

```text
\xc30d04070302c2fd333bcc1fa32161d23e0100c4ef0ea8650df2d31a24cb849702a375445d0cb1772d88bfd517e6b90146eab6ee717509a1c3745cfa1cbcd40b05192abb4cc3edf8e70d16e943790a
```

Con la clave correcta, `pgp_sym_decrypt()` regresó el RFC original:

```text
 id |  nombre   |      rfc
----+-----------+---------------
  1 | Ana López | LOPA900101ABC
```

Con `'CLAVE-INCORRECTA'` la consulta falló con `ERROR:  Wrong key or corrupt data` y no mostró nada del RFC.

## Análisis

**¿Qué diferencia existe entre `crypt()` y `pgp_sym_encrypt()`?** `crypt()` genera un hash de un solo sentido: no usa clave y no se puede revertir, solo sirve para comparar. `pgp_sym_encrypt()` cifra con una clave, y con esa misma clave `pgp_sym_decrypt()` regresa el dato original.

**¿Cuál de los dos permite recuperar el dato original?** `pgp_sym_encrypt()`, siempre que se tenga la clave. Por eso se usa para datos que hay que volver a leer, como el RFC, y `crypt()` para contraseñas, que solo hay que verificar.

**¿Qué ocurre si se utiliza una clave incorrecta?** PostgreSQL rechaza el descifrado con `Wrong key or corrupt data` y no entrega ni una parte del RFC.

**¿Qué problema de seguridad representa colocar la clave directamente en una consulta?** La clave se copia a todos lados junto con la consulta: al script, al repositorio Git, al registro de `psql`, a las capturas de pantalla y, si la consulta falla, al log del servidor, que guarda la sentencia completa. Quien lea cualquiera de esos lugares puede descifrar todos los RFC. Esto se analiza en la Actividad 3.

## Conclusión

Con `pgp_sym_encrypt()` el RFC deja de leerse en la tabla y solo se recupera con la clave correcta; con otra clave, el descifrado falla. La protección depende por completo de la clave: si se escribe dentro de las consultas, termina expuesta en scripts, registros y capturas, así que hay que administrarla fuera del código.

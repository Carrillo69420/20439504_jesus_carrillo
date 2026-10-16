# Evidencia 01 — Protección de credenciales

LAB-02, Actividad 1 (secciones 6 y 7 de la guía). Script: [`sql/01-credenciales.sql`](../sql/01-credenciales.sql). Capturas: [`01-credenciales.pdf`](01-credenciales.pdf).

## Objetivo

Comprobar por qué una contraseña no debe guardarse en texto claro y protegerla con un hash no reversible usando `crypt()` y `gen_salt('bf')` de pgcrypto, para después verificar una contraseña correcta y una incorrecta sin recuperar la original.

## Comando o procedimiento

El script se ejecutó el 15/10/2026 en `psql`, dentro del contenedor `dba-practica` (PostgreSQL 16, base `comercializadora`), pegando un bloque por paso. La sesión se abrió con `-L /tmp/lab02.log` para guardar las consultas y sus resultados en texto.

**Preparación (sección 6).** Identificación de la sesión, `\d clientes` y `CREATE EXTENSION IF NOT EXISTS pgcrypto;`.

**Texto claro (sección 7.1).** Tabla `usuarios_insegura`, que guarda la contraseña tal cual.

**Hash con sal (sección 7.3).** Una sal y dos hashes de la misma contraseña; la consulta de `crypt()` se ejecutó dos veces:

```sql
SELECT gen_salt('bf') AS sal;

SELECT crypt(
    'Password123',
    gen_salt('bf')
);
```

**Credenciales protegidas (sección 7.4).** Tabla `usuarios_segura`, que guarda solo el hash:

```sql
INSERT INTO usuarios_segura (usuario, password_hash)
VALUES (
    'juan',
    crypt('Password123', gen_salt('bf'))
);
```

**Verificación (sección 7.5).** La misma consulta con la contraseña correcta y con `'OtraPassword'`:

```sql
SELECT
    usuario,
    password_hash = crypt('Password123', password_hash)
        AS contraseña_correcta
FROM usuarios_segura
WHERE usuario = 'juan';
```

## Resultado obtenido

Sesión: `postgres | comercializadora | 2026-10-15 11:20:49.685406-07`.

pgcrypto ya estaba instalada desde el LAB-01: salió el aviso `extension "pgcrypto" already exists, skipping` y la consulta a `pg_extension` devolvió `pgcrypto`.

En `usuarios_insegura` la contraseña se lee tal cual:

```text
 id | usuario |  password
----+---------+-------------
  1 | juan    | Password123
```

La sal y los dos hashes de `Password123` salieron distintos:

| Consulta | Resultado |
|---|---|
| `gen_salt('bf')` | `$2a$06$61TjxLNhHxbQBSNEO974De` |
| `crypt()`, primera vez | `$2a$06$IMwIlRGtKvjEM8tc5Vh34uML0Azx2W5gfSSMIZwyxp.EzlLngP0sq` |
| `crypt()`, segunda vez | `$2a$06$m0ywB/ZggWJaDZHcQAyw6.z62kIQa5dBQnyjDu70cPsLDqoeqF0J6` |

En `usuarios_segura` solo queda el hash, de 60 caracteres:

```text
 id | usuario |                        password_hash
----+---------+--------------------------------------------------------------
  1 | juan    | $2a$06$FeBt6lM229PcoH6zAB/NUe5.4AoERHZJln2Ngt/3bD4gn7MaYvrdq
```

La verificación devolvió `t` (verdadero) con `Password123` y `f` (falso) con `OtraPassword`.

La consulta opcional `SELECT * FROM clientes;` no se ejecutó: en el bloque iba justo después de `\d clientes` y psql tomó sus palabras como argumentos de `\d` (son los avisos `\d: extra argument "SELECT" ignored` y similares de la Evidencia 1.1). La estructura de `clientes`, que es lo que pide la sección 6, sí se verificó.

## Análisis

**¿Qué ocurriría si una persona obtiene acceso de lectura a `usuarios_insegura`?** Vería la contraseña tal cual y podría entrar como juan de inmediato. Una filtración o un respaldo de esa tabla se vuelve directamente una filtración de credenciales, y como mucha gente repite contraseñas, el daño puede llegar a otros sistemas.

**¿Son iguales los dos resultados de `crypt()`? Si no, ¿por qué?** No. Cada `gen_salt('bf')` genera una sal aleatoria distinta y la sal queda dentro del resultado: `$2a$` indica bcrypt, `06` es el costo y los 22 caracteres que siguen son la sal. Con otra sal el hash cambia aunque la contraseña sea la misma, así que dos usuarios con la misma contraseña no tienen el mismo hash.

**¿Qué función cumple `gen_salt()`?** Genera la sal aleatoria y le indica a `crypt()` qué algoritmo y qué costo usar (`'bf'` es bcrypt, con costo 6 por defecto).

**¿Qué función cumple `crypt()`?** Calcula el hash de la contraseña con la sal que recibe. Si en lugar de una sal nueva recibe un hash ya guardado, toma de ahí la sal y el costo, y por eso sirve también para verificar.

**¿Esto es cifrado reversible?** No. Es un hash de un solo sentido: no hay clave ni función para regresar de `$2a$06$…` a `Password123`.

**¿Qué resultado obtuviste con la contraseña correcta y con la incorrecta?** `t` con la correcta y `f` con la incorrecta.

**¿Por qué no es necesario recuperar la contraseña original?** Porque basta calcular `crypt()` con lo que escribe el usuario y el hash guardado: si sale exactamente el mismo hash, la contraseña es correcta. La base nunca necesita conocer la contraseña, solo comparar.

**¿Por qué un hash no debe confundirse con cifrado?** El cifrado se revierte con la clave y sirve para datos que hay que volver a leer, como el RFC de la Actividad 2. El hash no se revierte y sirve cuando solo hay que comprobar, como una contraseña. Si las contraseñas se cifraran con una clave fija, quien obtuviera esa clave las recuperaría todas.

## Conclusión

Guardar contraseñas en texto claro hace que cualquier acceso de lectura o filtración exponga las credenciales. Con `crypt()` y `gen_salt('bf')` la tabla solo guarda un hash con sal aleatoria: la misma contraseña produce hashes distintos, la original no se puede recuperar y aun así se puede verificar. Esto se hizo con pgcrypto con fines didácticos; en una aplicación real el algoritmo se elige según las recomendaciones actuales y lo que ofrezca el framework, sin implementar uno propio (sección 7.6).

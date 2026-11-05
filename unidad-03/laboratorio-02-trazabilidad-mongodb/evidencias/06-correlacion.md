# Evidencia 06 — Correlación de un cambio de configuración con su autor

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-02 de la Unidad III, Actividad 6 (sección 12 de la guía)
- Servidor: `dba-u3-mongo`, MongoDB 7.0.45 en Docker, base `comercial`
- Fecha: 5 de noviembre de 2026

## Objetivo

Encontrar en la bitácora de `mongod` los cambios de configuración del perfilador y averiguar qué usuario los hizo. El evento del cambio no trae el usuario, así que se liga con la autenticación de la misma conexión (`ctx`).

## Comandos

En la sesión del DBA:

```javascript
bitacora().filter(e => e.msg === "Profiler settings changed").map(e => ({ t: e.t, ctx: e.ctx, msg: e.msg, attr: e.attr }))
bitacora().filter(e => e.ctx === "conn13" && e.msg === "Successfully authenticated").map(e => ({ t: e.t, ctx: e.ctx, user: e.attr.user, db: e.attr.db, client: e.attr.client }))
```

Son las consultas de la guía, cada una en una sola línea. La primera busca los avisos de que cambió la configuración del perfilador, y la segunda, la autenticación de la conexión que los escribió. La guía usa `conn31`, su número de conexión; aquí va `conn13`, el que dio la primera consulta.

## Resultado obtenido

```text
comercial> bitacora().filter(e => e.msg === "Profiler settings changed").map(e => ({ t: e.t, ctx: e.ctx, msg: e.msg, attr: e.attr }))
[
  {
    t: { '$date': '2026-11-05T17:51:51.745+00:00' },
    ctx: 'conn13',
    msg: 'Profiler settings changed',
    attr: {
      from: { level: 0, slowms: 100, sampleRate: 1 },
      to: { level: 2, slowms: 100, sampleRate: 1 },
      db: 'comercial'
    }
  },
  {
    t: { '$date': '2026-11-05T18:07:24.336+00:00' },
    ctx: 'conn13',
    msg: 'Profiler settings changed',
    attr: {
      from: { level: 2, slowms: 100, sampleRate: 1 },
      to: { level: 0, slowms: 100, sampleRate: 1 },
      db: 'comercial'
    }
  },
  {
    t: { '$date': '2026-11-05T18:07:34.039+00:00' },
    ctx: 'conn13',
    msg: 'Profiler settings changed',
    attr: {
      from: { level: 0, slowms: 100, sampleRate: 1 },
      to: {
        level: 1,
        slowms: 100,
        sampleRate: 1,
        filter: { op: { '$in': [ 'insert', 'remove', 'update' ] } }
      },
      db: 'comercial'
    }
  }
]
```

La guía muestra solo el último evento; aquí salen los tres cambios del laboratorio. En cada uno, `attr` trae la configuración anterior (`from`), la nueva (`to`) y la base (`db`):

| Momento (UTC) | Hora en Culiacán | `ctx` | De | A | Actividad |
| --- | --- | --- | --- | --- | --- |
| 17:51:51.745 | 10:51:51 | `conn13` | Nivel 0 | Nivel 2 | 3, activar el perfilador |
| 18:07:24.336 | 11:07:24 | `conn13` | Nivel 2 | Nivel 0 | 4, apagarlo antes de `drop()` |
| 18:07:34.039 | 11:07:34 | `conn13` | Nivel 0 | Nivel 1 con el filtro | 4, aplicar el filtro |

Los tres los escribió la misma conexión, `conn13`, y ninguno dice qué usuario los hizo.

```text
comercial> bitacora().filter(e => e.ctx === "conn13" && e.msg === "Successfully authenticated").map(e => ({ t: e.t, ctx: e.ctx, user: e.attr.user, db: e.attr.db, client: e.attr.client }))
[
  {
    t: { '$date': '2026-11-05T17:18:41.269+00:00' },
    ctx: 'conn13',
    user: 'admin',
    db: 'admin',
    client: '127.0.0.1:43264'
  }
]
```

`conn13` se autenticó a las 17:18:41 UTC (10:18 en Culiacán) como `admin`, el usuario definido en la base `admin`, desde `127.0.0.1:43264`. Es la sesión del DBA, la misma en la que se ejecutaron los `setProfilingLevel` de las actividades 3 y 4.

## Análisis

**¿Qué usuario cambió la configuración del perfilador? ¿Qué dos eventos lo demuestran?** `admin`, definido en la base `admin`. Lo demuestran dos eventos de la misma conexión. El primero es «Profiler settings changed», que dice qué cambió y cuándo, por ejemplo el filtro de las 18:07:34, y que lo hizo `conn13`. El segundo es «Successfully authenticated» de `conn13`, a las 17:18:41, que dice que esa conexión era de `admin`. Ninguno de los dos basta solo: el primero no trae el usuario y el segundo no dice qué hizo la conexión.

**¿Qué condición debe cumplirse para que esta correlación sea válida?** Que los dos eventos sean del mismo arranque del servidor. Mientras el servidor está encendido, cada conexión nueva recibe el número siguiente y ninguno se repite, así que `conn13` es una sola conexión. Pero al reiniciar, la cuenta vuelve a empezar desde `conn1`, y un `conn13` de después del reinicio sería otra conexión, quizá de otro usuario. Además, la autenticación tiene que ser anterior al cambio. Aquí se cumple: el servidor no se ha reiniciado desde que se creó para este laboratorio, y `conn13` se autenticó antes de los tres cambios. En la Actividad 8 se reinicia el servidor, y a partir de ahí los números de conexión vuelven a empezar.

**¿Por qué es relevante que quede registrado un cambio de configuración del propio mecanismo de registro?** Porque apagar o reducir el registro es la forma más sencilla de actuar sin dejar rastro. Entre las 18:07:24 y las 18:07:34 el perfilador estuvo en nivel 0, y lo que se hubiera hecho en esos diez segundos no habría quedado en `system.profile`. Lo único que deja ver ese hueco son estas líneas, que dicen quién apagó el perfilador y cuándo lo volvió a encender. También explican por qué cambia lo que hay en `system.profile`: desde las 18:07:34 ya no aparecen las consultas, por el filtro, y no porque nadie haya consultado. Quien puede cambiar el perfilador, como `admin`, es justo quien podría ocultar algo, y este registro lo deja expuesto.

## Conclusión

La línea del cambio no dice quién lo hizo, pero su `ctx` la liga con la autenticación de la misma conexión, y con eso se sabe que fue `admin`. La correlación solo vale dentro del mismo arranque del servidor. Que queden registrados los cambios del propio perfilador permite ver cuándo se dejó de registrar y quién lo decidió.

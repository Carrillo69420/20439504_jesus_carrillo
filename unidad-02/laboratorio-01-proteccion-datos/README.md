# Laboratorio 01 — Protección de datos

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504 · Grupo 4 · Periodo 2026-2027-1
- Materia: Gestión de Seguridad y Desempeño de Bases de Datos
- Unidad II, tema 2.3 — Datos sensibles, privacidad y protección de la información
- Entorno: PostgreSQL 16.15 en un contenedor de Docker (dba-practica), base comercializadora

## Objetivo

Aplicar en PostgreSQL varias técnicas de protección de datos según lo que necesita ver cada área de la organización: soporte consulta datos enmascarados, analítica trabaja con datos seudonimizados y dirección recibe solo información agregada. Además se clasifican los datos, se controla el acceso con roles y se define una regla de retención. La idea central es que no hay una sola técnica que sirva para todos los casos.

## Contenido

| Actividad | Script | Evidencia | Informe |
|---|---|---|---|
| 1. Clasificación de datos | [01-clasificacion.sql](sql/01-clasificacion.sql) | [01-clasificacion.pdf](evidencias/01-clasificacion.pdf) | Sección 1 |
| 2. Enmascaramiento | [02-enmascaramiento.sql](sql/02-enmascaramiento.sql) | [02-enmascaramiento.pdf](evidencias/02-enmascaramiento.pdf) | Sección 2 |
| 3 y 4. Seudonimización y separación de funciones | [03-seudonimizacion.sql](sql/03-seudonimizacion.sql) | [03-seudonimizacion.pdf](evidencias/03-seudonimizacion.pdf) | Secciones 3 y 4 |
| 5 y 6. Anonimización y riesgo de reidentificación | [04-anonimizacion.sql](sql/04-anonimizacion.sql) | [04-anonimizacion.pdf](evidencias/04-anonimizacion.pdf) | Secciones 5 y 6 |
| 7. Retención de datos y verificación final | [05-retencion.sql](sql/05-retencion.sql) | [05-retencion.pdf](evidencias/05-retencion.pdf) | Secciones 7 y 8 |

El script 01 también crea y llena la tabla `clientes` que usan las demás actividades. El [informe](informe.md) explica cada actividad y termina con las conclusiones, las preguntas de reflexión y las referencias legales.

## Cómo se ejecutó

Los scripts se ejecutaron en orden, del 01 al 05, en psql dentro del contenedor y conectado como `postgres` a la base `comercializadora`:

```
docker exec -it dba-practica psql -U postgres -d comercializadora
```

- Los scripts 01 a 03 crean objetos (la tabla `clientes`, la vista `v_clientes_soporte`, los esquemas `pii` y `analitica` con sus tablas y los roles `soporte` y `analista`), por eso se ejecutan una sola vez.
- Los scripts 04 y 05 solo hacen consultas y se pueden repetir.
- En los scripts 02, 03 y 05 hay consultas que fallan a propósito: se ejecutan con `SET ROLE` como `soporte` o `analista` para demostrar que esos roles no pueden leer la tabla original ni el mapa de correspondencia.

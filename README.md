# Gestión de Seguridad y Desempeño de Bases de Datos

## Datos del estudiante

* **Nombre:** jesus_carrillo
* **Cuenta:** 20439504
* **Grupo:** 4
* **Periodo:** 2026-2027-1

---

## Propósito

Este repositorio concentra las evidencias, configuraciones, scripts, pruebas, documentación y entregables desarrollados durante el curso.

El trabajo seguirá el ciclo:

**Problema → Diagnóstico → Decisión → Implementación → Verificación → Evidencia → Conclusión**

---

## Estructura del repositorio

```text
20439504_jesus_carrillo/
├── README.md
├── unidad-01/
│   ├── README.md
│   └── evidencias/
├── unidad-02/
│   ├── README.md
│   ├── laboratorio-01-proteccion-datos/
│   ├── laboratorio-02-cifrado-credenciales/
│   ├── laboratorio-03-privacidad-cumplimiento/
│   ├── laboratorio-04-hardening/
│   └── entregable-unidad-02/
├── unidad-03/
│   ├── README.md
│   └── evidencias/
├── unidad-04/
│   ├── README.md
│   └── evidencias/
├── unidad-05/
│   ├── README.md
│   └── evidencias/
├── unidad-06/
│   ├── README.md
│   └── evidencias/
└── proyecto-integrador/
    ├── README.md
    ├── diagnostico/
    ├── configuracion/
    ├── pruebas/
    ├── evidencias/
    └── informe-final/
```

---

## Flujo de trabajo

El repositorio debe permitir relacionar cada actividad con su evidencia:

**Actividad → Código/Configuración → Commit → Prueba → Evidencia → Entregable**

Cada actividad importante debe dejar evidencia suficiente para identificar:

* qué se hizo
* por qué se hizo
* cómo se realizó
* cómo se verificó
* cuál fue el resultado

---

## Estrategia de ramas

Se utilizará una estrategia sencilla basada en `main` y ramas de trabajo.

### `main`

Contiene la versión estable del repositorio y el trabajo listo para revisión.

### Ramas de trabajo

Las actividades importantes pueden desarrollarse en ramas específicas.

Ejemplos:

```text
lab-01-proteccion-datos
lab-04-hardening
fix-regla-pg-hba
docs-actualizar-readme
test-validar-privilegios
```

Flujo recomendado:

```text
Rama de trabajo
       ↓
Desarrollo y pruebas
       ↓
Merge Request
       ↓
main
```

Los cambios pequeños de documentación pueden realizarse directamente en `main`.

---

## Conventional Commits

Los mensajes de commit deben describir claramente el cambio realizado.

Tipos principales:

* `feat` — nueva funcionalidad
* `fix` — corrección
* `docs` — documentación
* `test` — pruebas
* `refactor` — reorganización o mejora del código
* `chore` — tareas de mantenimiento

Ejemplos:

```text
feat: agregar configuracion de hardening de PostgreSQL
fix: corregir regla de acceso en pg_hba.conf
docs: documentar procedimiento de revision de privilegios
test: validar acceso con usuario sin privilegios
refactor: reorganizar scripts del laboratorio
chore: agregar estructura de Unidad V
```

---

## Semantic Versioning

Para scripts, configuraciones, herramientas o componentes que evolucionen de manera independiente se puede utilizar Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Ejemplos:

```text
v1.0.0
v1.1.0
v1.1.1
```

Interpretación:

* **MAJOR:** cambios incompatibles
* **MINOR:** nuevas funcionalidades compatibles
* **PATCH:** correcciones compatibles

No es necesario crear una versión para cada laboratorio.

---

## Evidencias

Las evidencias deben demostrar el trabajo realizado.

Pueden incluir:

* comandos ejecutados
* resultados de consultas
* configuraciones relevantes
* pruebas de acceso
* pruebas de privilegios
* resultados de hardening
* comparaciones antes y después
* capturas de pantalla cuando sean necesarias
* logs relevantes
* conclusiones técnicas

Las evidencias deben ser claras y estar relacionadas con la actividad correspondiente.

---

## Seguridad del repositorio

Nunca subir al repositorio:

* contraseñas reales
* tokens
* claves privadas
* certificados privados
* credenciales
* cadenas de conexión con credenciales
* archivos `.env` que contengan secretos
* información sensible innecesaria

Antes de realizar un commit:

```bash
git status
git diff
```

Verifica que no existan credenciales o información sensible.

---

## Criterio de documentación

Cada actividad importante debe responder:

1. ¿Cuál era el problema?
2. ¿Qué riesgo o necesidad se identificó?
3. ¿Qué decisión se tomó?
4. ¿Qué configuración o implementación se realizó?
5. ¿Cómo se verificó?
6. ¿Qué evidencia demuestra el resultado?
7. ¿Qué conclusión se obtiene?

---

## Unidades

* [Unidad I](./unidad-01/)
* [Unidad II](./unidad-02/)
* [Unidad III](./unidad-03/)
* [Unidad IV](./unidad-04/)
* [Unidad V](./unidad-05/)
* [Unidad VI](./unidad-06/)

---

## Proyecto integrador

[Ir al Proyecto Integrador](./proyecto-integrador/)

---

## Repositorio

Este repositorio será utilizado durante todo el periodo académico para documentar el desarrollo progresivo de las actividades, prácticas y proyecto integrador.

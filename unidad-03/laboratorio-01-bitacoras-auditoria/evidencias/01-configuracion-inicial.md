# Evidencia 01 — Configuración de registro por defecto

- Alumno: Jesús Arturo Carrillo Avilez · Cuenta: 20439504
- LAB-01 de la Unidad III, Actividad 1 (sección 7 de la guía)
- Servidor: `dba-u3-pg`, PostgreSQL 16.15 en Docker, base `comercial`
- Fecha: 29 de octubre de 2026

## Objetivo

Revisar qué registra el servidor con la configuración que trae de fábrica, antes de cambiar nada.

## Comando

En la sesión de administrador (`docker exec -it dba-u3-pg psql -U postgres -d comercial -P pager=off`):

```sql
SELECT name, setting, source
FROM pg_settings
WHERE name IN ('log_destination', 'logging_collector', 'log_directory', 'log_filename',
               'log_connections', 'log_disconnections', 'log_line_prefix',
               'log_statement', 'log_min_error_statement', 'log_timezone')
ORDER BY name;
```

## Resultado obtenido

```text
          name           |            setting             |       source
-------------------------+--------------------------------+--------------------
 log_connections         | off                            | default
 log_destination         | stderr                         | default
 log_directory           | log                            | default
 log_disconnections      | off                            | default
 log_filename            | postgresql-%Y-%m-%d_%H%M%S.log | default
 logging_collector       | off                            | default
 log_line_prefix         | %m [%p]                        | default
 log_min_error_statement | error                          | default
 log_statement           | none                           | default
 log_timezone            | America/Mazatlan               | configuration file
(10 rows)
```

Nueve de los diez parámetros están en su valor por defecto. El único que viene de un archivo es `log_timezone`. Al crear el servidor, `initdb` lo escribió en `postgresql.conf` (línea 608, `log_timezone = 'America/Mazatlan'`) a partir de la variable `TZ` del contenedor. En el servidor de la guía sale `Etc/UTC` porque se creó sin esa variable.

## Análisis

**Con esta configuración, ¿se registra quién se conecta?** No. `log_connections` y `log_disconnections` están en `off`, así que el servidor no escribe los intentos de conexión ni el fin de las sesiones. Una conexión de `app_ventas` no deja rastro.

**¿Se registran las sentencias UPDATE?** No. `log_statement` vale `none`, así que no se registra ninguna sentencia que funcione, ni UPDATE ni cambios de estructura. Por `log_min_error_statement = error` solo quedaría escrita una sentencia que falle con un error, junto con su mensaje.

**¿La línea de bitácora incluye el usuario o la dirección IP del cliente?** No. El prefijo `%m [%p]` solo pone la fecha y hora con milisegundos y el número de proceso (PID). Sin `%u`, `%d` y `%h`, aunque se registrara algo, la línea no diría quién lo hizo, en qué base ni desde dónde.

**¿En qué zona horaria se registran los eventos? ¿Por qué importa al reconstruir una cronología?** En `America/Mazatlan`, que es UTC−7 todo el año. Importa porque una cronología junta eventos de varias fuentes: la bitácora, el reporte de facturación y lo que digan las personas. Si una fuente está en UTC y otra en hora local, los eventos quedan desfasados siete horas, y puede parecer que algo ocurrió antes o después de lo que pasó en realidad. Hay que anotar la zona de cada fuente y llevar todo a una sola.

**Con `logging_collector = off`, ¿quién decide dónde termina la bitácora: PostgreSQL o el mecanismo con que se desplegó el servidor?** El mecanismo de despliegue. PostgreSQL solo escribe en su salida de error (`log_destination = stderr`), y en un contenedor esa salida la guarda Docker, que se lee con `docker logs`. Cuánto se conserva y dónde lo decide Docker, y si el contenedor se borra, esa bitácora se pierde con él.

## Conclusión

Con la configuración de fábrica, el servidor no puede responder las preguntas de Dirección. No registra conexiones ni sentencias, sus líneas no dicen quién ni desde dónde, y la bitácora queda en manos de Docker. Lo único que ya está bien es la zona horaria.

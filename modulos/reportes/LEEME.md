# Módulo de Reportes

Responsable: Desarrollador 9

## Objetivo

Mostrar información resumida del funcionamiento del evento y permitir obtener reportes útiles.

## Archivos principales

index.html
estilos.css
interfaz.js
datos.js

## Qué debe desarrollar

Reportes de:

- participantes registrados;
- inscritos en ponencias;
- inscritos en concursos;
- asistencia;
- ingresos;
- salidas;
- certificados.
- exportación de información.

Si el tiempo lo permite:

- estadísticas;
- filtros.

## index.html

Debe mostrar:

- tablas;
- cantidades;
- filtros;
- botones de exportación.

## estilos.css

Diseño del módulo de reportes.

## interfaz.js

Controla:

- filtros;
- botones;
- tablas;
- visualización.

## datos.js

Debe consultar información almacenada en Supabase.

No debe guardar información nueva salvo que sea necesario.

## Dependencias

Este módulo depende de los datos generados por:

- usuarios;
- ponencias;
- concursos;
- asistencia;
- certificados.

Por este motivo su funcionamiento completo será posterior al desarrollo de esos módulos.

## Trabajo adelantado

Puede comenzar con:

- diseño;
- tablas;
- filtros;
- información ficticia.

## Comunicación

Debe consultar qué información necesita cada gerencia.

Ejemplos:

- total de inscritos;
- asistencia por ponencia;
- participantes por concurso;
- certificados emitidos.

## No hacer

- No modificar información de otros módulos.
- No crear otra conexión a Supabase.
- No duplicar consultas que ya existan en servicios comunes.
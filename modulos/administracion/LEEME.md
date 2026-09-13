# Módulo de Administración

Responsable: Desarrollador 9

## Objetivo

Permitir que los responsables del evento puedan consultar y administrar la información de la plataforma.

## Archivos principales

index.html
estilos.css
interfaz.js
datos.js

## Qué debe desarrollar

Panel administrativo para consultar:

- usuarios;
- ponencias;
- concursos;
- inscripciones;
- asistencia;
- certificados.
- configurar funciones solo para administradores.

También podrá incorporar funciones básicas de administración cuando sean necesarias.

## index.html

Debe mostrar el panel principal.

Puede contener:

- número de usuarios;
- inscritos;
- asistentes;
- accesos a cada sección;
- información general.

## estilos.css

Diseño exclusivo del panel administrativo.

## interfaz.js

Controla:

- menús;
- botones;
- tablas;
- filtros;
- ventanas;
- mensajes.

## datos.js

Consulta información desde Supabase.

Ejemplos:

- obtener usuarios;
- obtener inscripciones;
- obtener asistencia;
- obtener certificados.

## Dependencias

Depende de los módulos principales porque mostrará información generada por ellos.

Puede comenzar desarrollando la interfaz con información ficticia.

## Seguridad

El panel no debe estar disponible para cualquier participante.

Los permisos solo para administradores serán definidos junto con los responsables de arquitectura.

## Comunicación

Debe coordinar con los responsables que utilizarán el panel para conocer qué información necesitan visualizar.

## No hacer

- No crear otra base de datos.
- No modificar directamente las funciones internas de los demás módulos.
- No crear otro sistema de login.
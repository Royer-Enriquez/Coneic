# Módulo de Información

Responsable: Desarrollador 3

## Objetivo

Crear y mantener las páginas informativas del evento.

Este módulo es principalmente visual y puede desarrollarse sin depender del sistema de usuarios.

## Archivos principales

cronograma.html
ubicacion.html
estilos.css
interfaz.js

## Qué debe desarrollar

- Página de información general.
- Cronograma del evento.
- Ubicación.
- Contacto.
- Información importante para participantes.
- Enlaces externos necesarios.
- Información relacionada con pagos mediante Yape o formularios externos, si corresponde. (probablemente esto lo haga otro desarrollador)
- Informacion de los desarrolladores
- Informacion de sponsors
- preguntas frecuentes.

## cronograma.html

Debe contener:

- fechas;
- horarios;
- actividades;
- lugares;
- ponencias;
- concursos.
- otras actividades de ser necesarias

## ubicacion.html

Debe mostrar:

- dirección;
- referencia;
- información del lugar;
- enlace de ubicación si se utiliza.

## estilos.css

Contiene únicamente el diseño de este módulo.

No colocar estilos generales de toda la plataforma.

## interfaz.js

Puede utilizarse para:

- mostrar u ocultar información;
- filtros;
- cambios visuales;
- interacción con botones.

## Dependencias

Este módulo no depende directamente del inicio de sesión.

Puede desarrollarse desde el inicio.

## Comunicación

El desarrollador debe mantener comunicación con las gerencias que proporcionen información oficial del evento.

Debe confirmar:

- horarios;
- lugares;
- actividades;
- cambios de programación.
- Mantener comunicación con la gerencia de marketing

## Recursos compartidos

Los logos e imágenes institucionales deben tomarse de:

recursos/imagenes/

No duplicar las mismas imágenes dentro del módulo.

## No hacer

- No crear sistema de login.
- No crear conexiones nuevas a Supabase.
- No programar QR.
- No programar certificados.
- No copiar logos dentro de esta carpeta si ya existen en recursos/.
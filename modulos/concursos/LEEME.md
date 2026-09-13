# Módulo de Concursos

Responsable: Desarrollador 6

## Objetivo

Permitir que los participantes conozcan los concursos disponibles y puedan registrarse.

## Archivos principales

index.html
estilos.css
interfaz.js
datos.js

## Qué debe programar

- Lista de concursos.
- Información de cada concurso.
- Requisitos.
- Bases.
- Fechas.
- Inscripciones.
- Registro individual o grupal, según corresponda.
La información de cada cada item será proporcionado por la gerencia de concursos

## index.html

Debe mostrar:

- nombre;
- descripción;
- fecha;
- lugar;
- requisitos;
- bases;
- botón de inscripción.

## estilos.css

Contiene únicamente el diseño del módulo.

## interfaz.js

Controla:

- formularios;
- botones;
- mensajes;
- selección de concursos;
- visualización de información.

## datos.js

Debe encargarse de:

- obtener concursos;
- registrar participantes;
- consultar inscripciones;
- registrar equipos si se necesita.

Debe utilizar:

servicios/supabase.js

## Dependencias

Necesita:

- usuario registrado;
- sesión;
- base de datos.

## Comunicación

Debe mantener comunicación constante con la Gerencia de Concursos.

Debe solicitar:

- concursos oficiales;
- bases;
- requisitos;
- fechas;
- categorías;
- número máximo de participantes;
- reglas de inscripción.

## No hacer

- No crear otro sistema de usuarios.
- No crear otra conexión a Supabase.
- No programar QR.
- No programar certificados.
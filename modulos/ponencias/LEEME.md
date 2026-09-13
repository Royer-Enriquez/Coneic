# Módulo de Ponencias

Responsable: Desarrollador 5

## Objetivo

Permitir que los participantes consulten las ponencias disponibles y puedan inscribirse.

## Archivos principales

index.html
estilos.css
interfaz.js
datos.js

## Qué debe desarrollar

- Lista de ponencias.
- Información de cada ponencia.
- Horarios.
- Ponentes.
- Cupos.
- Botón de inscripción.
- Confirmación de inscripción.
- Visualización del estado de inscripción.

## index.html

Debe mostrar:

- título de la ponencia;
- ponente;
- descripción;
- fecha;
- hora;
- lugar;
- botón de inscripción. (por ver)

## estilos.css

Contiene solamente el diseño del módulo.

## interfaz.js

Controla:

- botones;
- mostrar ponencias;
- mensajes;
- cambios visuales;
- estado de inscripción.

## datos.js

Debe contener funciones relacionadas con:

- obtener ponencias;
- obtener información de una ponencia;
- registrar inscripción;
- consultar inscripción;
- consultar cupos.

Debe utilizar:

servicios/supabase.js

## Dependencias

Necesita:

- usuarios;
- inicio de sesión;
- base de datos.

Para identificar al usuario debe utilizar:

servicios/sesion.js

## Importante

Mientras autenticación todavía no esté terminada, el desarrollador puede avanzar con:

- interfaz;
- diseño;
- tarjetas;
- botones;
- datos de prueba.

Después se conectará con usuarios reales.

## Comunicación

Debe estar en comunicación constante con la Gerencia de Ponencias.

Debe solicitar:

- lista oficial de ponencias;
- ponentes;
- horarios;
- lugares;
- modificaciones.

## No hacer

- No crear otro login.
- No crear otra conexión a Supabase.
- No copiar funciones del módulo autenticación.
- No programar QR.
- No programar certificados.
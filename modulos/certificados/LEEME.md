# Módulo de Certificados

Responsable: Desarrollador 8

## Objetivo

Generar certificados digitales para los participantes que cumplan los requisitos definidos.

## Archivos principales

index.html
verificar.html
estilos.css
interfaz.js
datos.js

## Qué debe desarrollar

- Visualización de certificados disponibles.
- Comprobación de requisitos.
- Generación del certificado.
- Creación de PDF.
- Descarga.
- Código único de certificado.
- Verificación del certificado.

## index.html

Debe mostrar:

- certificados disponibles;
- estado;
- botón de descarga.

## verificar.html

Debe permitir ingresar o consultar un código para confirmar que un certificado es válido.

## estilos.css

Contiene únicamente el diseño del módulo.

## interfaz.js

Controla:

- botones;
- generación visual;
- mensajes;
- descarga.

## datos.js

Debe consultar:

- usuario;
- asistencia;
- evento;
- certificado existente;
- código de validación.

Debe utilizar:

servicios/supabase.js

## Dependencias

Necesita:

- usuarios;
- asistencia;
- información del evento.

## Importante

Este módulo NO debe depender directamente del código interno del QR.

Debe consultar la asistencia desde la base de datos.

Flujo:

QR y asistencia
↓
Base de datos
↓
Certificados

## Trabajo adelantado

Mientras el módulo de asistencia no esté terminado, se puede desarrollar:

- diseño del certificado;
- PDF;
- página de descarga;
- verificación;
- pruebas con datos ficticios.

## Comunicación

Debe confirmar con los responsables del evento:

- qué participantes reciben certificado;
- porcentaje o condición de asistencia;
- nombre oficial;
- firmas;
- texto;
- logos;
- formato.

## No hacer

- No leer directamente archivos del módulo QR.
- No crear otra conexión a Supabase.
- No modificar asistencia.
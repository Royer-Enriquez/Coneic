# ARQUITECTURA DEL PROYECTO

## Objetivo

Este documento explica cómo está organizado el proyecto y cómo deben comunicarse los diferentes módulos.

La finalidad principal es evitar:

- código duplicado;
- archivos demasiado grandes;
- modificaciones innecesarias;
- conflictos entre desarrolladores;
- múltiples conexiones a la base de datos;
- dependencia directa entre archivos internos de distintos módulos.

## Estructura general

ANIVERSARIO-FIC/

index.html

recursos/
comun/
servicios/
base-de-datos/
modulos/
documentacion/

La arquitectura de cada parte estan explicadas en todos los LEEME de cada archivo, ver para comprobar funciones, etc.
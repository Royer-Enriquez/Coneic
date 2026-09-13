# ANIVERSARIO-FIC

Plataforma web desarrollada como prueba para la organización de eventos de la Facultad de Ingeniería Civil y como preparación para el PRECONGRESO CONEIC 2027.

El proyecto utilizará como base el prototipo web existente y se reemplazarán progresivamente las funciones simuladas por funciones reales.

## Tecnologías utilizadas

- HTML
- CSS
- JavaScript
- Supabase
- GitHub

## Objetivo del proyecto

La plataforma deberá permitir:

- Mostrar información del evento.
- Registrar participantes.
- Iniciar sesión.
- Inscribirse a ponencias.
- Inscribirse a concursos.
- Generar códigos QR para participantes.
- Registrar ingreso y salida mediante QR.
- Generar certificados digitales.
- Administrar información del evento.
- Obtener reportes de participantes y asistencia.
- Mostrar enlaces o formularios externos para pagos mediante Yape u otros medios.

## Regla principal

Cada desarrollador debe trabajar únicamente en los archivos relacionados con su módulo y en su rama principal.

Si necesita modificar otro módulo, primero debe comunicarse con el desarrollador responsable.

## Organización de archivos dentro de los módulos

La mayoría de módulos utilizan la siguiente estructura:

index.html
estilos.css
interfaz.js
datos.js
LEEME.md

### index.html

Contiene únicamente la estructura visible de la página.

### estilos.css

Contiene únicamente el diseño visual del módulo.

### interfaz.js

Controla las acciones visibles para el usuario.

### datos.js

Se utiliza para leer, guardar, modificar o eliminar información relacionada con el módulo.

Ejemplos:

- obtener ponencias;
- registrar una inscripción;
- consultar asistencia;
- guardar un concurso.

Debe utilizar la conexión común ubicada en servicios/supabase.js.

### LEEME.md

Explica:

- quién es responsable del módulo;
- qué funciones debe desarrollar;
- qué información necesita;
- de qué otros módulos depende.

No debe contener código funcional.

## Supabase

Existe una sola configuración general:

servicios/supabase.js

Ningún desarrollador debe crear otra conexión independiente a Supabase.

## Sesión del usuario

Las funciones comunes relacionadas con la sesión estarán en:

servicios/sesion.js

Ejemplos:

- obtener usuario actual;
- comprobar si existe una sesión;
- cerrar sesión.

Los demás módulos utilizarán estas funciones cuando las necesiten.

## Base de datos

Los archivos relacionados con la estructura de la base de datos se encuentran en:

base-de-datos/

No modificar estos archivos sin coordinar con los Desarrolladores 1 y 2.

## GitHub

La rama principal contiene la versión estable del proyecto.

No trabajar directamente en main.

Cada módulo deberá utilizar una rama separada.

Ejemplos:

feature/autenticacion
feature/ponencias
feature/concursos
feature/qr
feature/certificados
feature/administracion

Antes de integrar cambios se debe comprobar que el módulo funciona.

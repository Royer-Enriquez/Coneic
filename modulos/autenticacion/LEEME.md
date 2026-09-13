# Módulo de Autenticación

Responsable: Desarrollador 4

## Objetivo

Permitir que una persona pueda crear una cuenta, iniciar sesión y utilizar la plataforma como usuario registrado.

## Archivos principales

iniciar-sesion.html
registro.html
perfil.html
estilos.css
interfaz.js
datos.js

## Qué debe desarrollar

- Registro de usuarios.
- Inicio de sesión.
- Cierre de sesión.
- Perfil del participante.
- Comprobación de sesión.
- Manejo básico de tipos de usuario.

## registro.html

Debe contener el formulario necesario para registrar al participante.

Los datos definitivos serán definidos en la base de datos.

Ejemplos:

- nombres;
- apellidos;
- correo;
- contraseña;
- información necesaria para el evento.
- codigo de matricula
- semestre

## iniciar-sesion.html

Debe contener:

- correo;
- contraseña;
- botón para iniciar sesión.

## perfil.html

Debe mostrar información del participante conectado.

## estilos.css

Solamente contiene estilos de este módulo.

## interfaz.js

Controla:

- botones;
- formularios;
- mensajes;
- mostrar u ocultar elementos;
- redirecciones.

## datos.js

Controla:

- registro del usuario;
- inicio de sesión;
- lectura del perfil;
- actualización de información.

Debe utilizar la conexión ubicada en:

servicios/supabase.js

## Dependencias

Depende de:

- arquitectura;
- Supabase;
- base de datos.

Este módulo debe estar listo antes de que otros módulos puedan utilizar usuarios reales.

## Código compartido

Las funciones generales de sesión deben colocarse en:

servicios/sesion.js

Por ejemplo:

obtenerUsuarioActual()
verificarSesion()
cerrarSesion()

No duplicar estas funciones dentro del módulo.

## No hacer

- No crear otra conexión a Supabase.
- No programar ponencias.
- No programar QR.
- No programar certificados.
- No modificar directamente módulos de otros desarrolladores.
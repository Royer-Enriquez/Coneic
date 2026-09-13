# Módulo de QR y Asistencia

Responsable: Desarrollador 7

## Objetivo

Permitir que cada participante tenga un código QR y utilizarlo para registrar ingreso y salida.

## Archivos principales

mi-qr.html
escaner.html
estilos.css
interfaz.js
datos.js

## Qué debe desarrollar

- QR único por participante.
- Página para visualizar el QR.
- Escáner mediante cámara.
- Registro de ingreso.
- Registro de salida.
- Confirmación visual del registro.
- Consulta de asistencia.

## mi-qr.html

Debe mostrar:

- nombre del participante;
- código QR;
- información básica necesaria.

No mostrar información personal innecesaria dentro del QR.

## escaner.html

Debe permitir:

- activar cámara;
- leer QR;
- identificar participante;
- registrar entrada;
- registrar salida;
- mostrar resultado.

## estilos.css

Contiene solamente el diseño del módulo.

## interfaz.js

Controla:

- cámara;
- botones;
- lectura visual;
- mensajes;
- confirmaciones.

## datos.js

Se encarga de:

- consultar usuario;
- guardar ingreso;
- guardar salida;
- comprobar registros anteriores;
- consultar asistencia.

Debe utilizar:

servicios/supabase.js

## Dependencias

Necesita:

- usuarios registrados;
- inicio de sesión;
- base de datos.

## Comunicación

Debe coordinar con los responsables de:

- ingreso;
- salida;
- control de participantes;
- organización del evento.

Debe definir claramente:

- cuándo registrar entrada;
- cuándo registrar salida;
- qué pasa si se escanea dos veces;
- quién puede utilizar el escáner.

## Importante

La asistencia debe quedar guardada en la base de datos.

El módulo Certificados y otras funcionalidades que correspondan consultarán posteriormente esos datos.

## No hacer

- No generar certificados.
- No modificar autenticación.
- No crear otra conexión a Supabase.
- No guardar la asistencia únicamente en el navegador.
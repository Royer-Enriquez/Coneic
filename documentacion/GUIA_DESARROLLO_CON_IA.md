# GUÍA PARA DESARROLLAR CÓDIGO CON IA

## 1. Objetivo

Esta guía explica cómo debe trabajar cada desarrollador cuando utilice inteligencia artificial para crear o corregir código.

La meta es evitar código duplicado, cambios en carpetas ajenas, nuevas conexiones innecesarias a Supabase y errores difíciles de integrar.

Regla principal:

> Cada desarrollador trabaja principalmente dentro de su módulo y debe saber exactamente qué archivo está modificando antes de copiar código generado por IA.

## 2. Antes de pedir código a la IA

Antes de solicitar código, identificar:

1. Módulo asignado.
2. Carpeta del módulo.
3. Función que se quiere implementar.
4. Archivos y funciones que ya existen.
5. Archivos que no se deben modificar.
6. Que no debe duplicar código.
7. Que no debe crear una nueva conexión a Supabase.

Ejemplo:

```text
Módulo: Ponencias
Carpeta: modulos/ponencias/
Archivos: index.html, estilos.css, interfaz.js, datos.js, LEEME.md
Función: permitir que un usuario se inscriba a una ponencia.
```

No pedir solamente: “Hazme un sistema de ponencias completo”.

## 3. Prompt recomendado

Prompt recomendado 1:

"Estoy trabajando en un proyecto HTML, CSS y JavaScript organizado por módulos. Mi módulo es [NOMBRE DEL MODULO]. Debes modificar únicamente los archivos de este módulo. No crees otra conexión a Supabase, no dupliques funciones existentes y no modifiques archivos pertenecientes a otros módulos. Si necesitas una función compartida, indícame primero dónde debería colocarse."

prompt recomendado 2:
Estoy trabajando en una plataforma web creada con HTML, CSS, JavaScript y Supabase.

El proyecto está dividido en módulos.

Mi responsabilidad es únicamente el módulo:

[ESCRIBIR MODULO]

Mi carpeta es:

[ESCRIBIR RUTA]

Dentro de mi carpeta existen:

[ESCRIBIR ARCHIVOS]

REGLAS:

1. No modifiques otros módulos.
2. No crees una nueva conexión con Supabase.
3. La conexión ya existe en servicios/supabase.js.
4. Las funciones de sesión están en servicios/sesion.js.
5. No dupliques funciones.
6. Mantén HTML, CSS y JavaScript separados.
7. Si necesitas una función compartida por varios módulos, indícalo antes de crearla.
8. Antes de darme código, indícame exactamente en qué archivo debo colocarlo.
9. Si debes reemplazar código, dime qué parte debo reemplazar.
10. No cambies la estructura del proyecto sin indicármelo primero.

Quiero implementar lo siguiente:

[EXPLICAR FUNCIÓN]

Antes de darme código, indícame exactamente en qué archivo debo colocarlo

Y adjuntas todos los documentos NECESARIOS para que la IA pueda hacerlo con la mayor calidad posible y para evitar duplicados, confusiones, etc.

## 4. Dónde colocar cada tipo de código

### HTML

Va en archivos `.html`.

Contiene estructura visible: títulos, formularios, botones, tablas, tarjetas y campos.

No colocar consultas directas a Supabase ni grandes bloques de JavaScript.

### CSS

Va en `estilos.css`.

Contiene diseño exclusivo del módulo.

Si un estilo se usa en varios módulos, debe evaluarse moverlo a `compartido/estilos/`.

### interfaz.js

Controla lo que sucede en pantalla:

- clics;
- mensajes;
- mostrar u ocultar elementos;
- llenar tablas;
- actualizar elementos visuales.

No debe configurar Supabase.

### datos.js

Contiene las funciones para leer, guardar, modificar o eliminar datos del módulo.

Debe utilizar la conexión existente en:

```text
servicios/supabase.js
```

### LEEME.md

Explica qué debe hacer el módulo, sus dependencias y sus límites.

No contiene código funcional de la aplicación.

## 5. Diferencia entre carpetas

### recursos/

Archivos que no son código:

- logos;
- fotografías;
- iconos;
- PDFs;
- documentos.

### compartido/

Código que usan dos o más módulos:

- componentes;
- validaciones;
- funciones de fechas;
- estilos comunes.

### servicios/

Funciones centrales del sistema:

- conexión a Supabase;
- sesión del usuario.

### modulos/

Código específico de cada parte de la plataforma.

## 6. Cómo probar el código

Todo desarrollador debe probar antes de hacer Commit.

Flujo:

```text
Crear función
↓
Guardar archivos
↓
Ejecutar página
↓
Probar
↓
Revisar errores
↓
Corregir
↓
Volver a probar
↓
Commit
```

## 7. Ejecutar la página

Se recomienda utilizar la extensión **Live Server** en Visual Studio Code.

Pasos:

1. Abrir el archivo HTML.
2. Clic derecho.
3. Elegir `Open with Live Server`.
4. Probar en el navegador.

Para módulos JavaScript y Supabase, usar Live Server es preferible a abrir el HTML con doble clic.

## 8. Revisar errores

En Chrome o Edge:

1. Abrir la página.
2. Presionar `F12`.
3. Abrir `Console / Consola`.

Si aparece un error en rojo, copiarlo y entregarlo a la IA junto con el archivo relacionado.

Ejemplo:

```text
Estoy probando modulos/ponencias/interfaz.js.

Aparece este error:
[PEGAR ERROR]

Este es mi código actual:
[PEGAR CÓDIGO]

Explícame el error y dime exactamente qué debo cambiar.
No modifiques otros módulos.
```

## 9. Probar por partes

No desarrollar todo el módulo y probar al final.

Ejemplo en Ponencias:

1. ¿Se muestran las ponencias?
2. ¿El botón funciona?
3. ¿Reconoce al usuario?
4. ¿Guarda la inscripción?
5. ¿Evita duplicados?
6. ¿Actualiza los cupos?

Corregir una etapa antes de continuar.

## 10. Usar datos de prueba

Si otro módulo todavía no está listo, se pueden usar datos ficticios.

```javascript
const usuarioPrueba = {
    id: "usuario-prueba-01",
    nombre: "Usuario de prueba"
};
```

Cuando la dependencia real esté lista, sustituir esos datos por información real de Supabase.

No dejar datos ficticios en la versión final.

## 11. Dependencias entre módulos

Que un módulo dependa de otro no significa que tenga que quedarse detenido.

Ejemplo: Ponencias depende de Login.

Mientras Login no esté listo puede desarrollar:

- diseño;
- botones;
- tarjetas;
- formularios;
- datos ficticios.

Cuando Login esté listo, se reemplazan los datos de prueba por `servicios/sesion.js`.

Lo mismo aplica a Certificados respecto a Asistencia.

## 12. Prueba y error con IA

La primera respuesta de una IA no debe asumirse como correcta.

Proceso:

```text
Pedir código
↓
Revisar archivo destino
↓
Copiar solo lo necesario
↓
Guardar
↓
Probar
↓
Revisar consola
↓
Corregir con IA
↓
Volver a probar
```

Repetir hasta obtener una versión estable.

## 13. Si la IA pide modificar otro módulo

No aceptar inmediatamente.

Consultar al responsable o preguntar a la IA:

```text
¿Se puede implementar sin modificar directamente ese módulo, usando servicios/sesion.js, servicios/supabase.js o una función compartida?
```

## 14. Evitar duplicados

Si dos módulos necesitan la misma función, no copiarla.

Ejemplo:

```text
formatearFecha()
```

Si la necesitan Ponencias y Concursos, informar a los responsables de arquitectura para evaluar moverla a:

```text
compartido/utilidades/fechas.js
```

## 15. Lista antes de hacer Commit

```text
[ ] Guardé todos los archivos.
[ ] Probé la función.
[ ] Revisé la consola.
[ ] No hay errores graves conocidos.
[ ] No modifiqué carpetas ajenas sin coordinación.
[ ] No dupliqué funciones.
[ ] No agregué claves privadas ni contraseñas.
[ ] Sé exactamente qué cambios voy a guardar.
```

Solo después pasar al proceso de Git. (VER ARCHIVO GUIA_GIT_GITHUB_VSCODE.md)

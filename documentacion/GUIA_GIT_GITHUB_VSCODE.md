# GUÍA BÁSICA DE GIT Y GITHUB EN VISUAL STUDIO CODE

## 1. Objetivo

Esta guía explica cómo guardar, revisar, subir y compartir cambios del proyecto utilizando Git y GitHub.

Está pensada para desarrolladores principiantes.

## 2. Diferencia entre Git y GitHub

### Git

Git funciona en la computadora y permite:

- registrar cambios;
- crear versiones;
- comparar modificaciones;
- trabajar con ramas.

### GitHub

GitHub guarda el repositorio en Internet y permite:

- compartir el proyecto;
- colaborar;
- revisar cambios;
- subir ramas;
- realizar Pull Requests.

## 3. Guardar un archivo no es lo mismo que subirlo

Presionar:

Ctrl + S

solo guarda el archivo en tu computadora.

No significa:

- Commit;
- Push;
- subirlo a GitHub.

Flujo completo:

Modificar archivo
↓
Ctrl + S
↓
Git detecta el cambio
↓
Commit
↓
Push
↓
GitHub

## 4. Panel Control de Código Fuente

En Visual Studio Code aparece el icono de **Control de código fuente**.

Los archivos pueden mostrar letras como:

U = archivo nuevo
M = archivo modificado
D = archivo eliminado

## 5. Preparar cambios o Stage

Antes de hacer Commit, se seleccionan los archivos que formarán parte de ese Commit.

En VS Code:

1. Abrir Control de código fuente.
2. Pasar el cursor sobre un archivo.
3. Presionar `+`.

También puede hacerse desde terminal:

```bash
git add .
```

Eso prepara todos los cambios.

Para preparar un archivo específico:

```bash
git add modulos/ponencias/index.html
```

## 6. Qué es un Commit

Un Commit registra un avance del proyecto.

Ejemplos de buenos mensajes:

Crear estructura inicial del proyecto

```text
Agregar formulario de inicio de sesión
```

```text
Corregir inscripción duplicada en ponencias
```

Evitar mensajes como:

```text
cambio
prueba
xd
```

En terminal:

```bash
git commit -m "Crear estructura inicial del proyecto"
```

Importante:

El Commit queda guardado primero en tu repositorio local.

Todavía no está en GitHub.

## 7. Qué es Push

`Push` envía tus commits desde tu computadora hacia GitHub.

```text
Tu computadora
↓
Commit
↓
Push
↓
GitHub
```

En terminal:

```bash
git push
```

La primera vez que subes una rama puede ser necesario:

```bash
git push -u origin feature/ponencias
```

Después normalmente bastará con:

```bash
git push
```

## 8. Qué es Pull

`Pull` trae a tu computadora los cambios que ya están en GitHub.

```text
GitHub
↓
Pull
↓
Tu computadora
```

En terminal:

```bash
git pull
```

Antes de comenzar a trabajar conviene actualizar la rama correspondiente.

Ejemplo:

```bash
git switch develop
git pull origin develop
```

## 9. Qué significa descartar cambios

Descartar cambios significa eliminar una modificación local y volver al estado anterior registrado por Git.

En VS Code:

1. Abrir Control de código fuente.
2. Clic derecho sobre el archivo.
3. Elegir `Descartar cambios`.

Advertencia:

Si el cambio no estaba guardado en un Commit, se puede perder.

Si existe duda, no descartar.

## 10. Cómo revisar qué cambió

En Control de código fuente:

1. Hacer clic sobre el archivo modificado.
2. VS Code mostrará una comparación.
3. Revisar las líneas agregadas, eliminadas o modificadas.

Es recomendable hacer esto antes de un Commit.

## 11. Qué es una rama

Una rama permite trabajar sin modificar directamente la versión principal.

Estructura recomendada:

```text
main
│
└── develop
    │
    ├── feature/autenticacion
    ├── feature/ponencias
    ├── feature/concursos
    ├── feature/qr
    └── feature/certificados
```

### main

Versión estable del proyecto.

No trabajar directamente aquí.

### develop

Versión donde se integran los módulos.

### feature/...

Ramas de trabajo de cada módulo.

## 12. Crear una rama

Primero actualizar `develop`:

```bash
git switch develop
git pull origin develop
```

Después crear la rama:

```bash
git switch -c feature/ponencias
```

Comprobar la rama actual:

```bash
git branch
```

Debe aparecer algo como:

```text
* feature/ponencias
```

## 13. Flujo recomendado para cada desarrollador

Antes de comenzar:

```bash
git switch develop
git pull origin develop
```

Crear o entrar a la rama correspondiente.

Si no existe:

```bash
git switch -c feature/ponencias
```

Si ya existe:

```bash
git switch feature/ponencias
```

Después de programar y probar:

```bash
git status
git add .
git commit -m "Agregar inscripción a ponencias"
git push
```

Si es el primer Push de esa rama:

```bash
git push -u origin feature/ponencias
```

## 14. Qué es un Pull Request

Un Pull Request es una solicitud para unir una rama con otra.

Ejemplo:

```text
feature/ponencias
↓
Pull Request
↓
develop
```

No se recomienda subir directamente a `main`.

En GitHub suele aparecer una opción similar a:

```text
Compare & pull request
```

Ejemplo de título:

```text
Agregar módulo de inscripción a ponencias
```

Ejemplo de descripción:

```text
- Se agregó listado de ponencias.
- Se agregó botón de inscripción.
- Se agregó validación básica.
- Se probó con datos de prueba.
```

## 15. Quién revisa los cambios

Se recomienda que:

- Desarrollador 1;
- Desarrollador 2;

revisen los Pull Requests importantes antes de integrarlos.

## 16. Cómo pedir permiso para subir código al repositorio

Si el repositorio pertenece a otra persona, debes tener acceso de escritura.

El propietario debe agregarte como colaborador.

Proceso general en GitHub:

1. Entrar al repositorio.
2. Abrir `Settings`.
3. Buscar la sección de acceso, colaboradores o colaboradores y equipos.
4. Elegir la opción para agregar una persona.
5. Escribir el usuario de GitHub o correo.
6. Enviar la invitación.
7. El desarrollador invitado debe aceptar.

Si al hacer:

```bash
git push
```

aparece:

```text
Permission denied
```

o:

403

probablemente la cuenta no tiene permiso de escritura.

## 17. Mensaje recomendado para pedir acceso

```text
Hola. Mi usuario de GitHub es:

[NOMBRE DE USUARIO]

Necesito acceso al repositorio ANIVERSARIO-FIC para subir mi rama:

feature/[MI-MODULO]

No realizaré cambios directamente en main.
```

## 18. Descargar el proyecto por primera vez

En GitHub:

1. Abrir el repositorio.
2. Presionar `Code`.
3. Copiar la dirección HTTPS.

Después:
 
```bash
git clone DIRECCION_DEL_REPOSITORIO
```

Ejemplo conceptual:

```bash
git clone https://github.com/usuario/ANIVERSARIO-FIC.git
```

Luego:

```bash
cd ANIVERSARIO-FIC
code .
```

## 19. Qué significa Sincronizar cambios

VS Code puede mostrar:

```text
Sincronizar cambios
```

Esta función puede realizar operaciones de sincronización entre la computadora y GitHub.

Para principiantes es mejor entender primero por separado:


Pull
Commit
Push

antes de usar automáticamente `Sincronizar cambios`.

## 20. Qué hacer antes de trabajar cada día

1. Abrir VS Code.
2. Revisar la rama actual.
3. Ejecutar:

```bash
git status
```

4. Actualizar la rama base si corresponde.
5. Empezar a programar.

## 21. Qué hacer al terminar una sesión

1. Guardar con `Ctrl + S`.
2. Probar el código.
3. Revisar la consola.
4. Abrir Control de código fuente.
5. Revisar archivos modificados.
6. Preparar cambios.
7. Crear Commit.
8. Hacer Push de la rama.

Ejemplo:

```bash
git status
git add .
git commit -m "Agregar formulario de inscripción a concursos"
git push
```

## 22. No subir información privada

Nunca subir:

- contraseñas;
- claves privadas;
- tokens privados;
- credenciales administrativas;
- información sensible.

Especialmente:

No colocar una clave privada de Supabase como `service_role` dentro del código del navegador.

## 23. Qué hacer si algo sale mal

No ejecutar comandos que no entiendas.

Evitar sin supervisión:

```text
git reset --hard
git push --force
rebase
```

Si aparece un problema:

1. No borrar archivos al azar.
2. No hacer force push.
3. Ejecutar:

```bash
git status
```

4. Tomar captura.
5. Pedir ayuda a los responsables de integración.

## 24. Resumen rápido

### Guardar

```text
Ctrl + S
```

Guarda en tu computadora.

### Stage

```bash
git add .
```

Selecciona cambios para el próximo Commit.

### Commit

```bash
git commit -m "Descripción"
```

Registra una versión local.

### Push

```bash
git push
```

Sube commits a GitHub.

### Pull

```bash
git pull
```

Descarga cambios de GitHub.

### Branch

```bash
git switch -c feature/nombre
```

Crea una rama nueva.

### Pull Request

Solicita unir tu rama con `develop`.

## 25. Flujo oficial recomendado

```text

↓
2. Crear o entrar a rama feature
↓
3. Programar
↓
4. Probar
↓
5. Guardar
↓
6. Revisar cambios
↓
7. Stage
↓
8. Commit
↓
9. Push
↓
10. Pull Request
↓
11. Revisión
↓
```

`main` debe reservarse para versiones estables del proyecto.

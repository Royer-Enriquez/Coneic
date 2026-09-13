# GUÍA DE CONEXIÓN CON SUPABASE V3.2.1
## ANIVERSARIO FIC / PRECONGRESO CONEIC 2027

**Estado de la base:** V3.2.1 estable para integración  
**Proyecto de trabajo:** Supabase DEV  
**Stack:** HTML + CSS + JavaScript + Supabase  
**Objetivo:** Que todos los desarrolladores conecten sus módulos a la misma base de datos sin duplicar conexiones, saltarse las reglas de seguridad ni modificar funciones que pertenecen a otros módulos.

---

# 1. REGLA PRINCIPAL

Todos los módulos deben usar **una sola conexión a Supabase**:

```text
servicios/supabase.js
```

Ningún desarrollador debe crear archivos como:

```text
supabase2.js
conexion-supabase.js
mi-supabase.js
config-supabase.js
```

La conexión central ya existe y todos deben importarla.

Ejemplo:

```javascript
import { supabase } from '../../servicios/supabase.js'
```

La cantidad de `../` depende de la ubicación del archivo.

Ejemplo desde:

```text
modulos/ponencias/datos.js
```

la ruta será normalmente:

```javascript
import { supabase } from '../../servicios/supabase.js'
```

---

# 2. ARCHIVOS DE CADA MÓDULO

La estructura recomendada es:

```text
modulos/
└── ponencias/
    ├── index.html
    ├── estilos.css
    ├── interfaz.js
    ├── datos.js
    └── LEEME.md
```

Responsabilidad:

```text
index.html
→ estructura visual

estilos.css
→ diseño exclusivo del módulo

interfaz.js
→ botones, formularios, DOM y comportamiento visual

datos.js
→ comunicación con Supabase

LEEME.md
→ documentación del módulo
```

## Regla importante

Las llamadas a Supabase deben concentrarse preferentemente en:

```text
datos.js
```

No llenar el HTML con lógica de base de datos.

---

# 3. REGLAS DE SEGURIDAD OBLIGATORIAS

## NUNCA usar `service_role` en el navegador

Solo se utiliza la clave pública permitida para el cliente web.

Nunca colocar en HTML o JavaScript:

```text
service_role
database password
contraseña del proyecto Supabase
credenciales privadas
```

## No desactivar RLS

La base utiliza **Row Level Security (RLS)**.

No ejecutar:

```sql
alter table ... disable row level security;
```

## No escribir directamente en tablas protegidas

Cuando exista una función RPC para una acción, debe utilizarse la RPC.

Ejemplo incorrecto:

```javascript
await supabase
    .from('certificados')
    .insert(...)
```

Ejemplo correcto:

```javascript
await supabase.rpc(
    'emitir_mi_certificado',
    {
        p_evento_id: eventoId
    }
)
```

## No llamar funciones del schema `private`

Nunca:

```javascript
supabase.rpc('private.algo')
```

El frontend solo utiliza las funciones públicas documentadas en esta guía.

## No permitir que el usuario envíe su propio `usuario_id`

Cuando la operación pertenece al usuario conectado, la base obtiene el usuario mediante:

```text
auth.uid()
```

Por ejemplo, `emitir_mi_certificado()` no recibe `usuario_id`.

Esto evita que un usuario genere certificados para otra persona.

---

# 4. AUTENTICACIÓN

Responsable principal:

```text
Desarrollador 4 — Autenticación
```

Supabase Auth administra:

```text
correo
contraseña
sesión
identidad del usuario
```

La tabla:

```text
public.perfiles
```

guarda:

```text
nombres
apellidos
tipo_documento
documento_identidad
telefono
institucion
carrera
correo
rol
activo
```

Roles disponibles:

```text
participante
control
admin
```

---

## 4.1 Registrar usuario

Los nombres y apellidos deben enviarse en `options.data`.

```javascript
const { data, error } =
    await supabase.auth.signUp({
        email: correo,
        password: password,
        options: {
            data: {
                nombres: nombres,
                apellidos: apellidos
            }
        }
    })
```

La base crea automáticamente:

```text
public.perfiles
```

cuando Supabase crea el usuario en:

```text
auth.users
```

### Importante

No registrar usuarios reales sin nombres y apellidos.

Los certificados requieren esos datos.

---

## 4.2 Iniciar sesión

```javascript
const { data, error } =
    await supabase.auth.signInWithPassword({
        email: correo,
        password: password
    })
```

---

## 4.3 Usuario actual

```javascript
const { data, error } =
    await supabase.auth.getUser()

const usuario = data.user
```

---

## 4.4 Cerrar sesión

```javascript
const { error } =
    await supabase.auth.signOut()
```

---

## 4.5 Consultar perfil propio

```javascript
const { data: usuarioData } =
    await supabase.auth.getUser()

const usuarioId =
    usuarioData.user?.id

const { data, error } =
    await supabase
        .from('perfiles')
        .select(`
            id,
            nombres,
            apellidos,
            tipo_documento,
            documento_identidad,
            telefono,
            institucion,
            carrera,
            correo,
            rol,
            activo
        `)
        .eq('id', usuarioId)
        .single()
```

RLS impide que un participante consulte perfiles ajenos.

---

# 5. PÁGINA INFORMATIVA

Responsable principal:

```text
Desarrollador 3 — Información
```

Puede consultar públicamente:

```text
eventos
salas
actividades
ponentes
actividad_ponentes
```

Solo aparecerán públicamente los registros permitidos por RLS.

Ejemplo:

```javascript
const { data, error } =
    await supabase
        .from('actividades')
        .select(`
            id,
            tipo,
            titulo,
            descripcion,
            fecha_inicio,
            fecha_fin,
            lugar,
            imagen_url
        `)
        .eq('estado', 'publicado')
        .order('fecha_inicio')
```

## No necesita iniciar sesión

Las consultas públicas permitidas pueden ejecutarse como `anon`.

---

# 6. INSCRIPCIÓN GENERAL AL EVENTO

RPC:

```text
inscribirse_evento(uuid)
```

Uso:

```javascript
const { data, error } =
    await supabase.rpc(
        'inscribirse_evento',
        {
            p_evento_id: eventoId
        }
    )
```

Respuesta aproximada:

```json
{
  "ok": true,
  "estado": "inscrito",
  "estado_pago": "no_requiere"
}
```

Para evento con pago:

```json
{
  "ok": true,
  "estado": "pendiente",
  "estado_pago": "pendiente"
}
```

La función ya controla:

```text
sesión
usuario activo
estado del evento
periodo de inscripción
pago
duplicados
```

No repetir esas reglas manualmente en JavaScript.

---

# 7. VERIFICACIÓN DE PAGO

Responsable:

```text
Administrador
Desarrollador 9 — Administración
```

RPC:

```text
verificar_pago_evento(
    uuid,
    boolean,
    text
)
```

JavaScript:

```javascript
const { data, error } =
    await supabase.rpc(
        'verificar_pago_evento',
        {
            p_inscripcion_id: inscripcionId,
            p_aprobado: true,
            p_referencia: referencia
        }
    )
```

Solo usuarios con:

```text
rol = admin
```

pueden ejecutar correctamente esta operación.

---

# 8. PONENCIAS

Responsable:

```text
Desarrollador 5 — Ponencias
```

Las ponencias están en:

```text
public.actividades
```

con:

```text
tipo = 'ponencia'
```

---

## 8.1 Listar ponencias

```javascript
const { data, error } =
    await supabase
        .from('actividades')
        .select(`
            id,
            evento_id,
            titulo,
            descripcion,
            fecha_inicio,
            fecha_fin,
            lugar,
            sala_id,
            capacidad,
            inscripciones_abiertas,
            cuenta_para_certificado,
            estado
        `)
        .eq('tipo', 'ponencia')
        .eq('estado', 'publicado')
        .order('fecha_inicio')
```

---

## 8.2 Inscripción individual a ponencia

RPC:

```text
inscribirse_actividad(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'inscribirse_actividad',
        {
            p_actividad_id: actividadId
        }
    )
```

La función controla automáticamente:

```text
usuario activo
inscripción al evento
cupos
periodo de inscripción
modalidad individual
duplicados
conflicto con equipo
```

---

# 9. CONCURSOS Y EQUIPOS

Responsable:

```text
Desarrollador 6 — Concursos
```

Los concursos también están en:

```text
public.actividades
```

con:

```text
tipo = 'concurso'
```

Una actividad puede permitir:

```text
individual
equipo
ambos
```

---

## 9.1 Crear equipo

RPC:

```text
crear_equipo(
    actividad_id,
    nombre
)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'crear_equipo',
        {
            p_actividad_id: actividadId,
            p_nombre: nombreEquipo
        }
    )
```

Respuesta:

```json
{
  "ok": true,
  "equipo_id": "UUID",
  "codigo_invitacion": "UUID"
}
```

Guardar ambos valores.

---

## 9.2 Unirse a equipo

RPC:

```text
unirse_equipo(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'unirse_equipo',
        {
            p_codigo_invitacion: codigo
        }
    )
```

Regla importante:

```text
una persona solo puede pertenecer a un equipo
dentro de la misma actividad/disciplina
```

Pero puede pertenecer a otro equipo en otra actividad.

---

## 9.3 Inscribir equipo al concurso

Solo el líder.

RPC:

```text
inscribir_equipo_actividad(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'inscribir_equipo_actividad',
        {
            p_equipo_id: equipoId
        }
    )
```

La base verifica:

```text
líder
mínimo de integrantes
máximo de integrantes
inscripción de todos al evento
cupos
actividad abierta
duplicados
```

---

# 10. QR

Responsable:

```text
Desarrollador 7 — QR y asistencia
```

Cada participante posee un QR por evento.

La imagen QR debe representar el UUID que devuelve la base.

---

## 10.1 Obtener QR

RPC:

```text
obtener_o_crear_qr(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'obtener_o_crear_qr',
        {
            p_evento_id: eventoId
        }
    )

const tokenQr = data
```

`data` es un UUID.

Ejemplo:

```text
2e095880-7f08-48e1-8e2a-a27101c48955
```

Ese UUID es el contenido que se transforma visualmente en QR.

---

## 10.2 Regenerar QR

RPC:

```text
regenerar_qr(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'regenerar_qr',
        {
            p_evento_id: eventoId
        }
    )
```

Regenerar invalida el token anterior.

Utilizar cuando:

```text
el participante perdió su QR
alguien obtuvo una captura
se necesita invalidar un código anterior
```

---

# 11. ASISTENCIA POR SALA

La V3.2.1 NO registra asistencia directamente por ponencia.

La lógica es:

```text
QR
↓
entrada a sala
↓
sesión de presencia
↓
ponencias que ocurren mientras permanece dentro
↓
cálculo automático
↓
salida
```

---

## 11.1 Escanear QR

RPC:

```text
registrar_escaneo_sala(
    token,
    sala_id
)
```

Solo:

```text
control
admin
```

```javascript
const { data, error } =
    await supabase.rpc(
        'registrar_escaneo_sala',
        {
            p_token: tokenQr,
            p_sala_id: salaId
        }
    )
```

Puede devolver tres acciones.

### Entrada

```json
{
  "ok": true,
  "accion": "entrada",
  "sala": "Auditorio Principal",
  "participante": "Nombre Apellido",
  "sesion_id": "UUID",
  "momento": "..."
}
```

### Salida

```json
{
  "ok": true,
  "accion": "salida",
  "sala": "Auditorio Principal",
  "participante": "Nombre Apellido",
  "sesion_id": "UUID",
  "momento": "..."
}
```

### Cambio de sala

```json
{
  "ok": true,
  "accion": "cambio_sala",
  "sala_anterior": "Auditorio A",
  "sala_nueva": "Auditorio B",
  "participante": "Nombre Apellido"
}
```

---

## 11.2 Escaneo duplicado

Si se escanea nuevamente en menos de 30 segundos:

```text
Escaneo duplicado. Espera unos segundos antes de volver a escanear.
```

No quitar esta protección desde el frontend.

---

## 11.3 Almuerzo / reingreso

El sistema acepta:

```text
08:00 entrada
12:00 salida

14:00 entrada
18:00 salida
```

Cada periodo se guarda como una sesión diferente.

---

# 12. CONSULTAR MI ASISTENCIA

RPC:

```text
mi_asistencia_evento(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'mi_asistencia_evento',
        {
            p_evento_id: eventoId
        }
    )
```

Devuelve:

```text
actividad_id
actividad
sala
fecha_inicio
fecha_fin
primera_entrada
ultima_salida
minutos_presentes
porcentaje_presencia
```

Ejemplo:

```json
[
  {
    "actividad": "Ponencia de prueba",
    "sala": "Auditorio",
    "minutos_presentes": 55,
    "porcentaje_presencia": 91.67
  }
]
```

## Importante

El participante puede consultar su asistencia.

Nunca debe poder modificarla.

---

# 13. CURSOS ACADÉMICOS

La relación es libre.

No existe:

```text
ponencia obligatoriamente relacionada con Mecánica de Suelos
```

El participante puede elegir cualquier ponencia con control de asistencia para cualquiera de sus cursos activos.

---

## 13.1 Agregar curso a mis cursos

RPC:

```text
agregar_mi_curso(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'agregar_mi_curso',
        {
            p_curso_id: cursoId
        }
    )
```

---

## 13.2 Elegir que una ponencia cuente para un curso

RPC:

```text
seleccionar_curso_asistencia(
    actividad_id,
    curso_id
)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'seleccionar_curso_asistencia',
        {
            p_actividad_id: actividadId,
            p_curso_id: cursoId
        }
    )
```

La misma ponencia puede seleccionarse para:

```text
Curso A
Curso B
Curso C
```

si esos cursos pertenecen al usuario y al mismo evento.

---

## 13.3 Quitar una ponencia de un curso

RPC:

```text
quitar_curso_asistencia(
    actividad_id,
    curso_id
)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'quitar_curso_asistencia',
        {
            p_actividad_id: actividadId,
            p_curso_id: cursoId
        }
    )
```

---

# 14. REPORTES POR CURSO

Responsable:

```text
Desarrollador 9 — Administración y reportes
```

RPC:

```text
reporte_asistencia_curso(
    curso_id,
    actividad_id
)
```

Solo administrador.

```javascript
const { data, error } =
    await supabase.rpc(
        'reporte_asistencia_curso',
        {
            p_curso_id: cursoId,
            p_actividad_id: actividadId
        }
    )
```

Devuelve:

```text
usuario_id
correo
participante
curso
docente
actividad
seleccionado_para_curso
seleccionado_en
primera_entrada
ultima_salida
minutos_presentes
porcentaje_presencia
estado_academico
```

Estados posibles:

```text
ASISTIO
ASISTENCIA_PARCIAL
NO_ASISTIO
NO_REGISTRADO
```

## Excel

La base de datos NO genera el `.xlsx`.

La función RPC devuelve las filas.

JavaScript transforma esas filas a Excel.

El archivo de pruebas V3.2.1 contiene un ejemplo funcional.

---

# 15. CERTIFICADOS

Responsable:

```text
Desarrollador 8 — Certificados
```

La V3.2.1 permite que el propio participante genere su certificado si cumple los requisitos.

---

## 15.1 Consultar elegibilidad

RPC:

```text
mi_elegibilidad_certificado(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'mi_elegibilidad_certificado',
        {
            p_evento_id: eventoId
        }
    )
```

Respuesta aproximada:

```json
{
  "apto": true,
  "motivo": "Cumples el porcentaje mínimo de asistencia para generar tu certificado.",
  "ya_emitido": false,
  "codigo_existente": null,
  "minutos_presentes": 510,
  "minutos_programados": 600,
  "porcentaje_obtenido": 85,
  "porcentaje_requerido": 70,
  "actividades_pendientes": 0,
  "actividades_consideradas": 8
}
```

---

## 15.2 Generar mi certificado

RPC:

```text
emitir_mi_certificado(uuid)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'emitir_mi_certificado',
        {
            p_evento_id: eventoId
        }
    )
```

Respuesta:

```json
{
  "ok": true,
  "codigo": "CERT-XXXXXXXXXXXX",
  "porcentaje_asistencia": 85,
  "porcentaje_requerido": 70,
  "mensaje": "Tu certificado fue generado correctamente."
}
```

Si ya existe:

```json
{
  "ok": true,
  "codigo": "CERT-XXXXXXXXXXXX",
  "mensaje": "Tu certificado ya estaba generado."
}
```

## Regla

Nunca crear certificados mediante:

```javascript
supabase
    .from('certificados')
    .insert(...)
```

RLS lo bloqueará.

---

## 15.3 Verificar certificado

RPC pública:

```text
verificar_certificado(text)
```

No requiere iniciar sesión.

```javascript
const { data, error } =
    await supabase.rpc(
        'verificar_certificado',
        {
            p_codigo: codigo
        }
    )
```

Devuelve:

```text
valido
codigo
participante
evento
actividad
emitido_en
```

No expone:

```text
DNI
correo
teléfono
```

---

## 15.4 Emisión manual administrativa

Solo para casos excepcionales.

RPC:

```text
emitir_certificado_manual(
    evento_id,
    usuario_id,
    tipo,
    actividad_id,
    pdf_url
)
```

```javascript
const { data, error } =
    await supabase.rpc(
        'emitir_certificado_manual',
        {
            p_evento_id: eventoId,
            p_usuario_id: usuarioId,
            p_tipo: 'participacion',
            p_actividad_id: null,
            p_pdf_url: null
        }
    )
```

No debe ser el flujo normal.

El flujo normal es:

```text
participante
→ elegibilidad
→ autoemisión
```

---

# 16. TABLAS PRINCIPALES

```text
perfiles
→ información adicional del usuario

eventos
→ eventos generales

inscripciones_evento
→ participación general y pagos

salas
→ auditorios/salas

actividades
→ ponencias, concursos, talleres, ceremonias

ponentes
→ información de ponentes

actividad_ponentes
→ relación ponencia-ponente

equipos
→ equipos de concursos

miembros_equipo
→ integrantes de los equipos

inscripciones_actividad
→ inscripciones individuales o por equipo

credenciales_qr
→ QR activo de cada participante

cursos
→ cursos académicos

curso_participantes
→ cursos que lleva cada participante

asignaciones_asistencia_curso
→ actividad que el usuario eligió para un curso

sesiones_presencia
→ entradas y salidas físicas por sala

certificados
→ certificados emitidos
```

---

# 17. QUÉ TABLAS PUEDE USAR CADA DESARROLLADOR

## Desarrollador 3 — Información

Consultar:

```text
eventos
salas
actividades
ponentes
actividad_ponentes
```

No modificar directamente.

---

## Desarrollador 4 — Autenticación

Utilizar:

```text
Supabase Auth
perfiles
```

Puede trabajar con:

```text
signUp
signInWithPassword
getUser
signOut
```

No cambiar directamente:

```text
rol
activo
```

---

## Desarrollador 5 — Ponencias

Consultar:

```text
actividades
ponentes
actividad_ponentes
inscripciones_actividad
```

Usar:

```text
inscribirse_actividad()
```

---

## Desarrollador 6 — Concursos

Consultar:

```text
actividades
equipos
miembros_equipo
inscripciones_actividad
```

Usar:

```text
inscribirse_actividad()
crear_equipo()
unirse_equipo()
inscribir_equipo_actividad()
```

---

## Desarrollador 7 — QR y asistencia

Consultar:

```text
salas
credenciales_qr
sesiones_presencia
actividades
```

Usar:

```text
obtener_o_crear_qr()
regenerar_qr()
registrar_escaneo_sala()
mi_asistencia_evento()
```

El escáner requiere rol:

```text
control
admin
```

---

## Desarrollador 8 — Certificados

Consultar:

```text
certificados
```

Usar:

```text
mi_elegibilidad_certificado()
emitir_mi_certificado()
verificar_certificado()
```

Solo admin en casos excepcionales:

```text
emitir_certificado_manual()
```

---

## Desarrollador 9 — Administración y reportes

Puede consultar, según RLS:

```text
perfiles
eventos
inscripciones_evento
salas
actividades
equipos
miembros_equipo
inscripciones_actividad
credenciales_qr
cursos
curso_participantes
asignaciones_asistencia_curso
sesiones_presencia
certificados
```

Usar principalmente:

```text
verificar_pago_evento()
reporte_asistencia_curso()
emitir_certificado_manual()
```

El panel administrativo puede realizar CRUD permitido por las políticas RLS, pero debe validar cuidadosamente cada acción.

---

# 18. SERVICIO DE SESIÓN COMPARTIDO

Archivo recomendado:

```text
servicios/sesion.js
```

Ejemplo:

```javascript
import { supabase } from './supabase.js'


export async function obtenerUsuarioActual() {

    const { data, error } =
        await supabase.auth.getUser()

    if (error) {
        return null
    }

    return data.user
}


export async function obtenerPerfilActual() {

    const usuario =
        await obtenerUsuarioActual()

    if (!usuario) {
        return null
    }

    const { data, error } =
        await supabase
            .from('perfiles')
            .select('*')
            .eq('id', usuario.id)
            .single()

    if (error) {
        return null
    }

    return data
}


export async function cerrarSesion() {

    return await supabase.auth.signOut()
}
```

Los módulos pueden reutilizar estas funciones.

---

# 19. MANEJO DE ERRORES

Patrón recomendado:

```javascript
const { data, error } =
    await supabase.rpc(
        'inscribirse_evento',
        {
            p_evento_id: eventoId
        }
    )

if (error) {

    console.error(error)

    mostrarMensaje(
        error.message
    )

    return
}

// continuar con data
```

El mensaje para el usuario debe ser simple.

Ejemplo técnico:

```text
P0001
new row violates...
```

No mostrarlo completo en producción.

Mostrar:

```text
No fue posible completar la operación.
```

o el mensaje de negocio de la base:

```text
No quedan cupos disponibles.
```

---

# 20. NO DUPLICAR REGLAS DE NEGOCIO EN JAVASCRIPT

Ejemplo incorrecto:

```javascript
if (equipo.length >= 5) {
    // bloquear aquí y asumir que basta
}
```

La interfaz puede ayudar al usuario, pero la decisión final siempre debe quedar en PostgreSQL.

La base ya valida:

```text
cupos
roles
pagos
equipos
inscripciones
QR
asistencia
porcentajes
certificados
duplicados
```

JavaScript presenta la interfaz.

PostgreSQL decide si la operación es válida.

---

# 21. DATOS DE PRUEBA VS DATOS REALES

Durante desarrollo:

```text
ANIVERSARIO-FIC-DEV
```

puede contener:

```text
participante1@example.com
participante2@example.com
admin1@example.com
control1@example.com
eventos ficticios
cursos ficticios
```

No borrar todavía esos datos.

Sirven para integrar los módulos.

Producción será independiente:

```text
ANIVERSARIO-FIC-PROD
```

En producción NO ejecutar:

```text
datos-prueba.sql
preparar-usuarios-prueba-cursos.sql
adaptar-datos-prueba...
```

---

# 22. IDs FIJOS DE PRUEBA

Los IDs utilizados en las pruebas pertenecen únicamente al entorno DEV.

Ejemplo:

```text
10000000-0000-0000-0000-000000000001
```

No programar módulos reales dependiendo permanentemente de esos UUID.

Incorrecto:

```javascript
const EVENTO =
    '10000000-0000-0000-0000-000000000001'
```

Correcto para el proyecto final:

```javascript
const eventoId =
    obtenerEventoSeleccionado()
```

o cargar el evento desde Supabase.

Los UUID fijos solo sirven durante las pruebas.

---

# 23. TRABAJO CON IA

Cuando un desarrollador pida código a una IA, debe indicar:

```text
Estoy trabajando en un proyecto HTML, CSS y JavaScript con Supabase.

Mi módulo es: [NOMBRE DEL MÓDULO].

Solo debes modificar archivos de este módulo.

La conexión existente está en:
servicios/supabase.js

No crees una segunda conexión a Supabase.
No uses service_role.
No desactives RLS.
No insertes directamente en tablas si existe una función RPC.
No modifiques funciones SQL existentes sin indicármelo primero.

Antes de darme código:
1. dime qué archivo debo modificar;
2. dime si reemplazo o agrego código;
3. utiliza únicamente las RPC documentadas en GUIA_CONEXION_SUPABASE_V3_2_1.md.
```

---

# 24. ANTES DE HACER COMMIT

Cada desarrollador debe comprobar:

```text
[ ] Mi módulo abre sin errores en consola.
[ ] No creé otra conexión Supabase.
[ ] No coloqué claves privadas.
[ ] No modifiqué otro módulo sin autorización.
[ ] No desactivé RLS.
[ ] No uso service_role.
[ ] Utilizo las RPC correctas.
[ ] Probé usuario sin sesión.
[ ] Probé usuario autenticado.
[ ] Probé al menos un error esperado.
[ ] Probé el caso correcto.
[ ] No dejé UUID ficticios como configuración final.
```

Después:

```bash
git add .
git commit -m "Describe brevemente el cambio"
git push
```

y se solicita revisión antes de integrar a:

```text
main
```

---

# 25. RESUMEN DE RPC DISPONIBLES

| RPC | Uso principal | Usuario |
|---|---|---|
| `inscribirse_evento(p_evento_id)` | Inscribirse al evento | Participante |
| `verificar_pago_evento(...)` | Aprobar/rechazar pago | Admin |
| `inscribirse_actividad(p_actividad_id)` | Inscripción individual | Participante |
| `crear_equipo(p_actividad_id, p_nombre)` | Crear equipo | Participante |
| `unirse_equipo(p_codigo_invitacion)` | Unirse a equipo | Participante |
| `inscribir_equipo_actividad(p_equipo_id)` | Inscribir equipo | Líder |
| `obtener_o_crear_qr(p_evento_id)` | Obtener QR | Participante |
| `regenerar_qr(p_evento_id)` | Invalidar/generar QR | Participante |
| `agregar_mi_curso(p_curso_id)` | Registrar curso | Participante |
| `seleccionar_curso_asistencia(...)` | Asociar ponencia a curso | Participante |
| `quitar_curso_asistencia(...)` | Retirar asociación | Participante |
| `registrar_escaneo_sala(...)` | Entrada/salida/cambio | Control/Admin |
| `mi_asistencia_evento(p_evento_id)` | Consultar asistencia | Participante |
| `reporte_asistencia_curso(...)` | Reporte académico | Admin |
| `mi_elegibilidad_certificado(p_evento_id)` | Saber si puede certificar | Participante |
| `emitir_mi_certificado(p_evento_id)` | Autoemitir certificado | Participante apto |
| `emitir_certificado_manual(...)` | Emisión excepcional | Admin |
| `verificar_certificado(p_codigo)` | Validación pública | Cualquiera |

---

# 26. REGLA FINAL PARA TODO EL EQUIPO

La arquitectura debe mantenerse así:

```text
INTERFAZ
HTML / CSS / interfaz.js
        ↓
datos.js
        ↓
servicios/supabase.js
        ↓
RPC / SELECT permitido
        ↓
RLS + funciones PostgreSQL
        ↓
BASE DE DATOS
```

No convertir el proyecto en diez aplicaciones distintas.

Todos los módulos forman parte de una sola plataforma y utilizan:

```text
1 Supabase
1 base de datos
1 sistema de usuarios
1 arquitectura
```

**Versión documentada: V3.2.1**

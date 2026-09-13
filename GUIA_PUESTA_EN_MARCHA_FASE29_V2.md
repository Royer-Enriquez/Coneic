# Guía completa de puesta en marcha — Fase 29 V2

Esta guía asume que partes de un proyecto Supabase nuevo y del ZIP integrado V2.

> Regla crítica: no muevas solamente `index.html`. La raíz publicada debe conservar junto a él `servicios/`, `modulos/`, `compartido-codigo reutilizable/`, `manifest.json` y `service-worker.js`.

---

## 0. Estructura que debes abrir en VS Code

Abre la carpeta que contiene directamente:

```text
index.html
manifest.json
service-worker.js
servicios/
modulos/
recursos/
base-de-datos/
```

Compruébalo en PowerShell:

```powershell
Get-Location
Test-Path .\index.html
Test-Path .\servicios\supabase.js
```

Los dos `Test-Path` deben devolver `True`.

Para evitar problemas de Live Server, puedes hacer doble clic en `INICIAR_LOCAL.bat`. El script cambia automáticamente a la raíz del proyecto y ejecuta Python HTTP Server en:

```text
http://127.0.0.1:5500/
```

Si prefieres terminal:

```powershell
cd "RUTA\A\ANIVERSARIO-FIC-main"
py -m http.server 5500 --bind 127.0.0.1
```

En desarrollo local esta versión NO registra el Service Worker, precisamente para evitar caché vieja y errores de recarga en vivo. En producción HTTPS sí se registra.

---

## 1. Crear el proyecto en Supabase

1. Entra al Dashboard de Supabase.
2. Crea un proyecto nuevo.
3. Define un nombre, por ejemplo `coneic-huancayo-2027`.
4. Crea una contraseña PostgreSQL fuerte y guárdala en un gestor de contraseñas.
5. Elige una región adecuada.
6. Espera a que el proyecto termine de aprovisionarse.

La contraseña de PostgreSQL NO se coloca en HTML ni JavaScript.

---

## 2. Ejecutar la base de datos desde cero

Ve a `SQL Editor > New query`. Ejecuta cada archivo completo, uno por uno, en este orden exacto:

```text
1. base-de-datos/esquema.sql
2. base-de-datos/funciones.sql
3. base-de-datos/permisos.sql
4. base-de-datos/FASE29_01_COMPATIBILIDAD.sql
5. base-de-datos/FASE29_02_INTEGRACION.sql
6. base-de-datos/FASE29_03_DATOS_INICIALES.sql
```

No ejecutes las migraciones `MIGRACION_*` ni `ACTUALIZACION_*` sobre un proyecto nuevo.

### Por qué existe FASE29_01_COMPATIBILIDAD.sql

Las políticas RLS originales de lectura pública usan `private.usuario_tiene_rol(...)`. El SQL original concede `EXECUTE` a `authenticated`, pero un visitante público usa el rol `anon`. Sin el GRANT complementario, PostgreSQL puede responder `42501 permission denied for function usuario_tiene_rol`, que el navegador muestra como `401 Unauthorized`.

El script complementario concede al rol `anon` solamente la posibilidad de evaluar ese helper. Con `auth.uid() = NULL`, el helper devuelve `false`; no convierte al visitante en administrador.

---

## 3. Verificar la instalación SQL

Ejecuta completo:

```text
base-de-datos/FASE29_99_VERIFICACION.sql
```

Comprueba especialmente:

- existen `contenido_sitio`, `tarifas_fase29` y `pagos_fase29`;
- aparecen las RPC principales;
- `rowsecurity` es `true` en las tablas protegidas;
- `anon_schema_private_ok = true`;
- `anon_rol_helper_ok = true`;
- existe el evento `coneic-huancayo-2027`;
- aparecen tarifas Estándar, VIP y Premium.

Los datos iniciales dejan `requiere_pago = false` para poder probar primero registro, inscripción, QR y asistencia sin mezclar pagos.

---

## 4. Configurar Supabase Auth para desarrollo

En el Dashboard abre `Authentication`.

### Email/Password

En `Providers` / `Sign In / Providers`:

- habilita Email;
- habilita creación de nuevos usuarios (`Allow new users to sign up`, `Enable email signup` o nombre equivalente);
- para la primera prueba puedes dejar `Confirm Email = OFF`.

Con Confirm Email desactivado, el registro devuelve sesión inmediatamente. Para producción debe activarse y debe configurarse SMTP propio.

### URL Configuration

Durante desarrollo configura:

```text
Site URL:
http://127.0.0.1:5500/
```

Añade Redirect URLs de desarrollo:

```text
http://127.0.0.1:5500/**
http://localhost:5500/**
```

Cuando publiques, reemplaza Site URL por la URL real de GitHub Pages y agrega la URL exacta de producción a la allow-list.

---

## 5. Obtener URL y Publishable key

En Supabase abre `Connect` o `Settings > API Keys`.

Necesitas solamente:

```text
Project URL
Publishable key (sb_publishable_...)
```

NO uses en el navegador:

```text
sb_secret_...
service_role
contraseña PostgreSQL
```

Abre:

```text
servicios/supabase.js
```

Reemplaza únicamente:

```js
export const SUPABASE_URL = 'TU_SUPABASE_URL'
export const SUPABASE_PUBLISHABLE_KEY = 'TU_SUPABASE_PUBLISHABLE_KEY'
```

por tus valores reales. Guarda el archivo.

---

## 6. Primera prueba pública

Inicia `INICIAR_LOCAL.bat` y abre:

```text
http://127.0.0.1:5500/
```

Pulsa `F12 > Console`.

No debes ver errores de Supabase 401/42501. Las librerías opcionales de PDF/Excel/QRCode dependen de Internet, pero su caída no debe impedir Auth, inscripción o base de datos.

Puedes ejecutar en Console:

```js
await CONEIC_DIAGNOSTICO()
```

Esto muestra estado de conexión, evento, rol, generadores y lector QR nativo.

---

## 7. Registrar la primera cuenta

Desde la propia página pulsa `Registrarse` y crea tu cuenta.

Después verifica en Supabase:

```text
Authentication > Users
```

Tu correo debe aparecer.

Luego ejecuta:

```sql
select id, nombres, apellidos, correo, rol, activo, creado_en
from public.perfiles
order by creado_en desc;
```

El trigger debe haber creado tu perfil automáticamente con:

```text
rol = participante
activo = true
```

---

## 8. Convertir tu primera cuenta en administrador

Abre `base-de-datos/FASE29_PROMOVER_ADMIN_EJEMPLO.sql`, reemplaza `TU_CORREO@EJEMPLO.COM` por tu correo y ejecuta el script en SQL Editor.

La consulta final debe devolver:

```text
rol = admin
activo = true
```

Cierra sesión en la web y vuelve a iniciar sesión para refrescar el rol.

Nunca programes una contraseña maestra o un código de administrador en el frontend.

---

## 9. Crear una segunda cuenta participante

Usa otro navegador o una ventana incógnita:

```text
Navegador A -> admin
Navegador B/incógnito -> participante
```

Registra una segunda cuenta. Verifica:

```sql
select correo, rol, activo
from public.perfiles
order by creado_en;
```

Debes tener un admin y un participante.

---

## 10. Probar inscripción sin pago

Asegúrate de que:

```sql
select requiere_pago
from public.eventos
where slug = 'coneic-huancayo-2027';
```

devuelva `false`.

Con el participante, realiza la inscripción desde la web.

Comprueba:

```sql
select p.correo, ie.estado, ie.estado_pago, ie.inscrito_en
from public.inscripciones_evento ie
join public.perfiles p on p.id = ie.usuario_id
join public.eventos e on e.id = ie.evento_id
where e.slug = 'coneic-huancayo-2027'
order by ie.inscrito_en desc;
```

Para un evento sin pago obligatorio se espera:

```text
estado = inscrito
estado_pago = no_requiere
```

---

## 11. Probar talleres

Con el participante inscríbete a un taller.

Comprueba:

```sql
select p.correo, a.titulo, ia.estado, ia.inscrito_en
from public.inscripciones_actividad ia
join public.perfiles p on p.id = ia.usuario_id
join public.actividades a on a.id = ia.actividad_id
order by ia.inscrito_en desc;
```

La RPC es quien valida publicación, fechas, cupos, inscripción general y reglas de modalidad.

---

## 12. Probar QR

En el panel del participante abre el QR. La aplicación llama a `obtener_o_crear_qr`.

Comprueba:

```sql
select q.id, p.correo, q.token, q.activo, q.creado_en
from public.credenciales_qr q
join public.perfiles p on p.id = q.usuario_id
order by q.creado_en desc;
```

El QR representa un token; no contiene contraseña ni debe depender de datos privados como DNI.

Si QRCode.js no carga, la interfaz conserva y muestra el token para control manual.

---

## 13. Probar escáner de asistencia

Entra como admin. Abre el panel de escaneo y selecciona una sala.

La V2 usa `BarcodeDetector` nativo cuando el navegador lo soporta. Se recomienda Chrome o Edge actualizado. La cámara requiere `localhost` o HTTPS y permiso del usuario.

Si el lector nativo no está disponible, el operador puede pegar el token manualmente; la validación de seguridad sigue ocurriendo en Supabase mediante `registrar_escaneo_sala`.

Después del escaneo:

```sql
select p.correo, s.nombre as sala,
       sp.entrada_en, sp.salida_en, sp.estado
from public.sesiones_presencia sp
join public.perfiles p on p.id = sp.usuario_id
join public.salas s on s.id = sp.sala_id
order by sp.entrada_en desc;
```

La base controla entradas, salidas, cambio de sala y doble lectura accidental.

---

## 14. Activar pagos Yape solamente después de probar lo anterior

Ejecuta:

```sql
update public.eventos
set requiere_pago = true,
    enlace_pago = 'TU_ENLACE_O_INFORMACION_DE_PAGO',
    actualizado_en = now()
where slug = 'coneic-huancayo-2027';
```

Crea una TERCERA cuenta participante para probar el flujo desde cero.

El proceso esperado es:

```text
participante se inscribe
-> inscripción pendiente
-> elige tarifa
-> registra medio/referencia
-> pagos_fase29 queda pendiente
-> admin revisa
-> admin aprueba o rechaza
-> al aprobar: inscripción inscrito + pago verificado
-> QR habilitado
```

Comprueba pagos:

```sql
select p.correo, pf.tipo_entrada, pf.monto,
       pf.medio, pf.referencia, pf.estado_pago
from public.pagos_fase29 pf
join public.perfiles p on p.id = pf.usuario_id
order by pf.creado_en desc;
```

El navegador envía la clave de tarifa; la RPC obtiene nombre y monto desde `tarifas_fase29`. No confíes en precios calculados solamente en HTML.

---

## 15. Tarjetas

La interfaz de tarjeta es solo maqueta. NO almacenes PAN, CVV ni fecha de expiración en Supabase.

Para cobro real integra Culqi, Mercado Pago u otra pasarela que tokenice la tarjeta y confirme el pago mediante backend/Edge Function/webhook. La aprobación de una transacción bancaria nunca debe depender de JavaScript del cliente.

---

## 16. Certificados

La base calcula elegibilidad a partir de actividades configuradas para asistencia y del porcentaje mínimo del evento.

Los datos demo usan fechas de noviembre de 2027. No falsifiques el evento real para “hacer funcionar” un certificado durante desarrollo. Para pruebas completas crea posteriormente un evento específico de QA con fechas actuales.

---

## 17. Producción: SMTP y Confirm Email

Antes de abrir registro a participantes reales:

1. Configura un proveedor SMTP propio en Supabase Auth.
2. Activa `Confirm Email`.
3. Revisa las plantillas de confirmación/recuperación.
4. Verifica SPF/DKIM/DMARC con tu proveedor.
5. Ajusta rate limits para el volumen esperado del evento.
6. Considera CAPTCHA para signup/sign-in si la página será pública.

El SMTP incorporado por Supabase es para pruebas y tiene restricciones fuertes; no lo uses como sistema de correo de un evento real.

---

## 18. Git y GitHub

Trabaja desde el repositorio que ya conserva `.git`.

```powershell
git status
git checkout -b feature/fase29-v2
git add .
git commit -m "Integra Fase 29 V2 con Supabase"
git push -u origin feature/fase29-v2
```

No ejecutes `git init` dentro de una copia ZIP si quieres conservar el historial del repositorio original.

Nunca subas claves secretas. La Publishable key es una credencial de cliente de bajo privilegio diseñada para frontend con RLS; una Secret key/service_role no lo es.

---

## 19. GitHub Pages

Después de fusionar la rama estable a `main`:

```text
GitHub > Settings > Pages
Source: Deploy from a branch
Branch: main
Folder: / (root)
```

`index.html` debe estar en la raíz que publiques.

Si tu URL final fuera:

```text
https://usuario.github.io/ANIVERSARIO-FIC/
```

configura en Supabase:

```text
Site URL:
https://usuario.github.io/ANIVERSARIO-FIC/
```

Y agrega esa URL (preferiblemente exacta) a Redirect URLs. Conserva localhost si seguirás desarrollando.

---

## 20. Checklist final antes de abrir al público

Ejecuta `PRUEBAS_ACEPTACION_FASE29_V2.md` con al menos:

- una cuenta admin;
- una cuenta participante sin pago;
- una cuenta participante con pago pendiente/aprobado;
- una operación rechazada;
- inscripción a taller;
- QR generado;
- entrada y salida de sala;
- reporte administrativo;
- prueba desde la URL HTTPS final.

---

## Fuentes oficiales de referencia

- Supabase API keys: https://supabase.com/docs/guides/getting-started/api-keys
- Supabase JS initialization: https://supabase.com/docs/reference/javascript/initializing
- Supabase Auth URL configuration: https://supabase.com/docs/guides/auth/redirect-urls
- Supabase Custom SMTP: https://supabase.com/docs/guides/auth/auth-smtp
- Supabase production checklist: https://supabase.com/docs/guides/deployment/going-into-prod
- GitHub Pages publishing source: https://docs.github.com/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

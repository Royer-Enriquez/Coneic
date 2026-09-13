# Pruebas de aceptación — Fase 29 V2

No uses el sistema con público real hasta completar esta lista.

## Instalación

- [ ] Los 6 scripts se ejecutaron en el orden indicado en la guía.
- [ ] `FASE29_99_VERIFICACION.sql` muestra tablas, RPC y permisos esperados.
- [ ] `servicios/supabase.js` contiene Project URL + Publishable key del proyecto correcto.
- [ ] No existe `sb_secret_`, `service_role` ni contraseña PostgreSQL en el repositorio.

## Público

- [ ] La página abre sin errores rojos de aplicación en Console.
- [ ] Evento, talleres y tarifas se leen desde Supabase.
- [ ] `contenido_sitio` no produce 401/42501.
- [ ] Mover la carpeta completa no rompe rutas; nunca se mueve solo `index.html`.

## Auth

- [ ] Email provider habilitado.
- [ ] Nuevos usuarios pueden registrarse.
- [ ] El usuario aparece en `Authentication > Users`.
- [ ] El trigger crea su fila en `public.perfiles`.
- [ ] Login y logout funcionan.
- [ ] Confirm Email está definido conscientemente (OFF en prueba / ON en producción).

## Roles

- [ ] Existe al menos una cuenta `admin` activa.
- [ ] Un participante no puede abrir el panel admin.
- [ ] Un admin sí puede abrirlo.
- [ ] RLS permanece habilitado; no se desactiva para “arreglar” permisos.

## Inscripción / talleres

- [ ] Con `requiere_pago=false`, la inscripción queda `inscrito/no_requiere`.
- [ ] El participante puede inscribirse a un taller con cupo.
- [ ] Una actividad llena no acepta más inscripciones.

## QR / asistencia

- [ ] El participante inscrito obtiene token QR.
- [ ] El admin/control puede seleccionar una sala.
- [ ] Chrome/Edge actualizado reconoce QR mediante `BarcodeDetector`, o el operador puede pegar el token manualmente.
- [ ] Primer escaneo registra entrada.
- [ ] Escaneo duplicado inmediato se rechaza.
- [ ] Escaneo posterior registra salida/cambio según la RPC.
- [ ] `sesiones_presencia` refleja los registros.

## Pagos

- [ ] Tras activar `requiere_pago=true`, un usuario nuevo queda pendiente.
- [ ] El participante registra medio + referencia + tipo de entrada.
- [ ] El monto proviene de `tarifas_fase29`.
- [ ] Admin puede aprobar/rechazar.
- [ ] Solo pagos `verificado` se suman como recaudación.
- [ ] No se guardan números de tarjeta, CVV ni fecha de expiración.

## Producción

- [ ] GitHub Pages sirve el sitio por HTTPS.
- [ ] Site URL y Redirect URLs de Supabase apuntan al dominio final.
- [ ] SMTP propio configurado antes de abrir el registro al público.
- [ ] Confirm Email habilitado en producción.
- [ ] CAPTCHA/rate limits revisados para una convocatoria masiva.
- [ ] Cuenta de Supabase/GitHub protegida con MFA/2FA.

const CACHE_NAME = "coneic2027-supabase-fase29-v3";
const APP_SHELL = [
  "./index.html",
  "./manifest.json",
  "./icon-192.png",
  "./icon-512.png",
  "./compartido-codigo%20reutilizable/estilos/global.css",
  "./servicios/supabase.js",
  "./servicios/sesion.js",
  "./modulos/autenticacion/datos.js",
  "./modulos/informacion/interfaz.js",
  "./modulos/ponencias/datos.js",
  "./modulos/qr-asistencia/datos.js",
  "./modulos/certificados/datos.js",
  "./modulos/administracion/datos.js",
  "./modulos/concursos/datos.js",
  "./modulos/reportes/datos.js"
];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)));
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  const esCodigo = event.request.mode === "navigate" || /\.(?:html|js)$/.test(url.pathname);

  if (esCodigo) {
    // Network-first evita conservar una configuración vieja de servicios/supabase.js
    // después de que el proyecto sea conectado o actualizado en GitHub Pages.
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response && response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          }
          return response;
        })
        .catch(() => caches.match(event.request).then((cached) => cached || caches.match("./index.html")))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request).then((response) => {
      if (response && response.status === 200) {
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
      }
      return response;
    }))
  );
});

// ============================================================
// CONEXIÓN ÚNICA A SUPABASE
// Reemplaza SOLO SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.
// Nunca pongas aquí sb_secret_..., service_role ni la contraseña PostgreSQL.
// ============================================================

export const SUPABASE_URL = 'TU_SUPABASE_URL'
export const SUPABASE_PUBLISHABLE_KEY = 'TU_SUPABASE_PUBLISHABLE_KEY'

export const supabaseConfigurado =
  /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(SUPABASE_URL) &&
  SUPABASE_PUBLISHABLE_KEY !== 'TU_SUPABASE_PUBLISHABLE_KEY' &&
  SUPABASE_PUBLISHABLE_KEY.length > 20

let createClient = null
export let supabaseSdkError = null

async function cargarSupabaseSdk() {
  // 1) ESM directo. Es la ruta más limpia para los módulos del proyecto.
  try {
    const sdk = await import('https://esm.sh/@supabase/supabase-js@2')
    if (typeof sdk.createClient === 'function') return sdk.createClient
  } catch (error) {
    supabaseSdkError = error
  }

  // 2) Respaldo UMD desde jsDelivr, CDN admitido por la documentación de Supabase.
  try {
    if (!globalThis.supabase?.createClient) {
      await new Promise((resolve, reject) => {
        const existente = document.querySelector('script[data-supabase-sdk="fallback"]')
        if (existente) {
          existente.addEventListener('load', resolve, { once: true })
          existente.addEventListener('error', () => reject(new Error('No se pudo cargar Supabase JS desde el CDN de respaldo.')), { once: true })
          return
        }
        const script = document.createElement('script')
        script.src = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
        script.async = true
        script.dataset.supabaseSdk = 'fallback'
        script.onload = resolve
        script.onerror = () => reject(new Error('No se pudo cargar Supabase JS desde el CDN de respaldo.'))
        document.head.appendChild(script)
      })
    }
    if (typeof globalThis.supabase?.createClient === 'function') {
      supabaseSdkError = null
      return globalThis.supabase.createClient
    }
  } catch (error) {
    supabaseSdkError = error
  }

  return null
}

if (supabaseConfigurado) {
  createClient = await cargarSupabaseSdk()
}

export const supabase = supabaseConfigurado && createClient
  ? createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      }
    })
  : null

export function exigirSupabase() {
  if (!supabaseConfigurado) {
    throw new Error(
      'Supabase todavía no está configurado. Edita servicios/supabase.js y coloca SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.'
    )
  }
  if (!supabase) {
    const detalle = supabaseSdkError?.message ? ` Detalle: ${supabaseSdkError.message}` : ''
    throw new Error('La configuración existe, pero no se pudo cargar el SDK de Supabase desde Internet.' + detalle)
  }
  return supabase
}

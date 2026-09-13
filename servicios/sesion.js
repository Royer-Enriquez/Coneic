import { exigirSupabase, supabase } from './supabase.js'

export async function obtenerUsuarioActual() {
  if (!supabase) return null
  const { data, error } = await supabase.auth.getUser()
  if (error) return null
  return data.user || null
}

export async function obtenerSesionActual() {
  if (!supabase) return null
  const { data, error } = await supabase.auth.getSession()
  if (error) return null
  return data.session || null
}

export async function obtenerPerfilActual() {
  const cliente = exigirSupabase()
  const usuario = await obtenerUsuarioActual()
  if (!usuario) return null

  const { data, error } = await cliente
    .from('perfiles')
    .select('*')
    .eq('id', usuario.id)
    .single()

  if (error) throw error
  return data
}

export async function cerrarSesion() {
  const cliente = exigirSupabase()
  return await cliente.auth.signOut()
}

export function observarSesion(callback) {
  if (!supabase) return { unsubscribe() {} }
  const { data } = supabase.auth.onAuthStateChange((_event, session) => {
    callback(session)
  })
  return data.subscription
}

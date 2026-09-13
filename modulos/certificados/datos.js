import { exigirSupabase } from '../../servicios/supabase.js'

export async function obtenerElegibilidad(eventoId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('mi_elegibilidad_certificado', { p_evento_id: eventoId })
  if (error) throw error
  return data
}

export async function emitirMiCertificado(eventoId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('emitir_mi_certificado', { p_evento_id: eventoId })
  if (error) throw error
  return data
}

export async function verificarCertificado(codigo) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('verificar_certificado', { p_codigo: codigo })
  if (error) throw error
  return data
}

export async function listarMisCertificados() {
  const cliente = exigirSupabase()
  const { data: authData, error: authError } = await cliente.auth.getUser()
  if (authError || !authData.user) return []
  const { data, error } = await cliente
    .from('certificados')
    .select('*')
    .eq('usuario_id', authData.user.id)
    .order('emitido_en', { ascending: false })
  if (error) throw error
  return data || []
}

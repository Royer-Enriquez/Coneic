import { exigirSupabase, supabase } from '../../servicios/supabase.js'

export async function obtenerOCrearQr(eventoId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('obtener_o_crear_qr', { p_evento_id: eventoId })
  if (error) throw error
  return data
}

export async function regenerarQr(eventoId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('regenerar_qr', { p_evento_id: eventoId })
  if (error) throw error
  return data
}

export async function registrarEscaneoSala(token, salaId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('registrar_escaneo_sala', {
    p_token: token,
    p_sala_id: salaId
  })
  if (error) throw error
  return data
}

export async function miAsistenciaEvento(eventoId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('mi_asistencia_evento', { p_evento_id: eventoId })
  if (error) throw error
  return data || []
}

export async function listarSalasEvento(eventoId) {
  if (!supabase || !eventoId) return []
  const { data, error } = await supabase
    .from('salas')
    .select('id,nombre,ubicacion,activo')
    .eq('evento_id', eventoId)
    .eq('activo', true)
    .order('nombre')
  if (error) throw error
  return data || []
}

import { exigirSupabase, supabase } from '../../servicios/supabase.js'

export async function obtenerPonencias(eventoId) {
  if (!supabase || !eventoId) return []
  const { data, error } = await supabase
    .from('actividades')
    .select('*')
    .eq('evento_id', eventoId)
    .eq('tipo', 'ponencia')
    .eq('estado', 'publicado')
    .order('fecha_inicio')
  if (error) throw error
  return data || []
}

export async function obtenerTalleres(eventoId) {
  if (!supabase || !eventoId) return []
  const [{ data, error }, { data: cupos, error: cuposError }] = await Promise.all([
    supabase
      .from('actividades')
      .select('*')
      .eq('evento_id', eventoId)
      .eq('tipo', 'taller')
      .eq('estado', 'publicado')
      .order('fecha_inicio'),
    supabase.rpc('cupos_publicos_talleres_evento', { p_evento_id: eventoId })
  ])
  if (error) throw error
  if (cuposError) throw cuposError
  const countMap = new Map((cupos || []).map(x => [x.actividad_id, Number(x.inscritos || 0)]))
  return (data || []).map(x => ({ ...x, inscritos: countMap.get(x.id) || 0 }))
}

export async function inscribirseActividad(actividadId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('inscribirse_actividad', { p_actividad_id: actividadId })
  if (error) throw error
  return data
}

export async function misInscripcionesActividad(eventoId) {
  const cliente = exigirSupabase()
  const { data: authData, error: authError } = await cliente.auth.getUser()
  if (authError || !authData.user) return []
  const { data, error } = await cliente
    .from('inscripciones_actividad')
    .select('id,estado,inscrito_en,actividades!inner(id,titulo,tipo,evento_id,fecha_inicio,lugar)')
    .eq('usuario_id', authData.user.id)
    .eq('actividades.evento_id', eventoId)
    .neq('estado', 'cancelado')
  if (error) throw error
  return data || []
}

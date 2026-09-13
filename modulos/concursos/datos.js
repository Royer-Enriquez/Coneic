import { exigirSupabase, supabase } from '../../servicios/supabase.js'

export async function obtenerConcursos(eventoId) {
  if (!supabase || !eventoId) return []
  const { data, error } = await supabase
    .from('actividades')
    .select('*')
    .eq('evento_id', eventoId)
    .eq('tipo', 'concurso')
    .eq('estado', 'publicado')
    .order('fecha_inicio')
  if (error) throw error
  return data || []
}

export async function inscribirseConcursoIndividual(actividadId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('inscribirse_actividad', { p_actividad_id: actividadId })
  if (error) throw error
  return data
}

export async function crearEquipo(actividadId, nombre) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('crear_equipo', { p_actividad_id: actividadId, p_nombre: nombre })
  if (error) throw error
  return data
}

export async function unirseEquipo(codigoInvitacion) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('unirse_equipo', { p_codigo_invitacion: codigoInvitacion })
  if (error) throw error
  return data
}

export async function inscribirEquipo(equipoId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('inscribir_equipo_actividad', { p_equipo_id: equipoId })
  if (error) throw error
  return data
}

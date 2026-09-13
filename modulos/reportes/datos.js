import { exigirSupabase } from '../../servicios/supabase.js'
import { exigirRolAdmin } from '../administracion/datos.js'

export async function reporteAsistenciaCurso(cursoId, actividadId) {
  const cliente = exigirSupabase()
  await exigirRolAdmin()
  const { data, error } = await cliente.rpc('reporte_asistencia_curso', {
    p_curso_id: cursoId,
    p_actividad_id: actividadId
  })
  if (error) throw error
  return data || []
}

export async function listarCursos(eventoId) {
  const cliente = exigirSupabase()
  await exigirRolAdmin()
  const { data, error } = await cliente.from('cursos').select('*').eq('evento_id', eventoId).order('nombre')
  if (error) throw error
  return data || []
}

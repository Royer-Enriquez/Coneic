import { exigirSupabase, supabase } from '../../servicios/supabase.js'
import { obtenerPerfilActual } from '../../servicios/sesion.js'

export async function exigirRolAdmin() {
  const perfil = await obtenerPerfilActual()
  if (!perfil || perfil.rol !== 'admin' || !perfil.activo) {
    throw new Error('Esta función requiere una cuenta con rol admin.')
  }
  return perfil
}

export async function exigirRolControlOAdmin() {
  const perfil = await obtenerPerfilActual()
  if (!perfil || !['control', 'admin'].includes(perfil.rol) || !perfil.activo) {
    throw new Error('Esta función requiere rol control o admin.')
  }
  return perfil
}

export async function listarParticipantes(eventoId = null) {
  const cliente = exigirSupabase()
  await exigirRolAdmin()
  let q = cliente
    .from('perfiles')
    .select('id,nombres,apellidos,telefono,institucion,carrera,correo,rol,activo,creado_en')
    .eq('rol', 'participante')
    .order('creado_en', { ascending: false })
  const { data: perfiles, error } = await q
  if (error) throw error

  if (!eventoId || !perfiles?.length) return perfiles || []
  const ids = perfiles.map(p => p.id)
  const resultados = await Promise.all([
    cliente.from('inscripciones_evento').select('*').eq('evento_id', eventoId).in('usuario_id', ids),
    cliente.from('sesiones_presencia').select('usuario_id,id').eq('evento_id', eventoId).neq('estado', 'anulada').in('usuario_id', ids),
    cliente.from('certificados').select('usuario_id,codigo,estado').eq('evento_id', eventoId).eq('estado', 'emitido').in('usuario_id', ids),
    cliente.from('pagos_fase29').select('*').eq('evento_id', eventoId).in('usuario_id', ids)
  ])
  for (const r of resultados) if (r.error) throw r.error
  const [inscripcionesR, presenciasR, certificadosR, pagosR] = resultados
  const insMap = new Map((inscripcionesR.data || []).map(x => [x.usuario_id, x]))
  const presSet = new Set((presenciasR.data || []).map(x => x.usuario_id))
  const certMap = new Map((certificadosR.data || []).map(x => [x.usuario_id, x]))
  const pagoMap = new Map((pagosR.data || []).map(x => [x.usuario_id, x]))
  return perfiles.map(p => ({
    ...p,
    inscripcion: insMap.get(p.id) || null,
    pagoFase29: pagoMap.get(p.id) || null,
    acreditado: presSet.has(p.id),
    certificado: certMap.get(p.id) || null
  }))
}

export async function verificarPago(inscripcionId, aprobado, referencia = null) {
  const cliente = exigirSupabase()
  await exigirRolAdmin()
  const { data, error } = await cliente.rpc('verificar_pago_evento', {
    p_inscripcion_id: inscripcionId,
    p_aprobado: !!aprobado,
    p_referencia: referencia
  })
  if (error) throw error
  return data
}

export async function obtenerResumenAdmin(eventoId) {
  const cliente = exigirSupabase()
  await exigirRolAdmin()
  const [perfiles, inscripciones, presencias, actividades, certificados, inscripcionesActividad, pagos] = await Promise.all([
    cliente.from('perfiles').select('id,nombres,apellidos,correo,institucion,carrera,rol,activo,creado_en').eq('rol', 'participante'),
    cliente.from('inscripciones_evento').select('*').eq('evento_id', eventoId),
    cliente.from('sesiones_presencia').select('*').eq('evento_id', eventoId).neq('estado', 'anulada'),
    cliente.from('actividades').select('id,tipo,titulo,capacidad').eq('evento_id', eventoId),
    cliente.from('certificados').select('*').eq('evento_id', eventoId).eq('estado', 'emitido'),
    cliente.from('inscripciones_actividad').select('id,usuario_id,equipo_id,estado,inscrito_en,actividades!inner(id,evento_id,tipo,titulo)').eq('actividades.evento_id', eventoId).neq('estado', 'cancelado'),
    cliente.from('pagos_fase29').select('*').eq('evento_id', eventoId)
  ])
  for (const r of [perfiles, inscripciones, presencias, actividades, certificados, inscripcionesActividad, pagos]) if (r.error) throw r.error
  return {
    perfiles: perfiles.data || [],
    inscripciones: inscripciones.data || [],
    presencias: presencias.data || [],
    actividades: actividades.data || [],
    certificados: certificados.data || [],
    inscripcionesActividad: inscripcionesActividad.data || [],
    pagos: pagos.data || []
  }
}

export async function guardarTarifas(eventoId, tickets) {
  const cliente = exigirSupabase()
  const perfil = await exigirRolAdmin()
  if (!eventoId) throw new Error('Falta el evento para guardar las tarifas.')
  const filas = Object.entries(tickets || {}).map(([clave, t]) => ({
    evento_id: eventoId,
    clave,
    nombre: String(t?.nombre || clave).trim(),
    monto: Math.max(0, Number(t?.precio) || 0),
    activo: true,
    actualizado_por: perfil.id,
    actualizado_en: new Date().toISOString()
  }))
  if (!filas.length) return []
  const { data, error } = await cliente
    .from('tarifas_fase29')
    .upsert(filas, { onConflict: 'evento_id,clave' })
    .select()
  if (error) throw error
  return data || []
}

export async function actualizarEvento(eventoId, cambios) {
  const cliente = exigirSupabase()
  await exigirRolAdmin()
  const { data, error } = await cliente.from('eventos').update(cambios).eq('id', eventoId).select().single()
  if (error) throw error
  return data
}

export { supabase }

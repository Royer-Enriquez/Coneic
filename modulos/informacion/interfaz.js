import { exigirSupabase, supabase } from '../../servicios/supabase.js'

export async function obtenerEventoActual() {
  if (!supabase) return null
  const { data, error } = await supabase
    .from('eventos')
    .select('*')
    .eq('estado', 'publicado')
    .eq('es_prueba', false)
    .order('fecha_inicio', { ascending: true })
    .limit(1)
    .maybeSingle()
  if (error) throw error
  return data || null
}

export async function obtenerActividadesPublicas(eventoId, tipo = null) {
  if (!supabase || !eventoId) return []
  let q = supabase
    .from('actividades')
    .select('id,evento_id,tipo,titulo,descripcion,imagen_url,enlace_bases,fecha_inicio,fecha_fin,lugar,sala_id,capacidad,requiere_inscripcion,inscripciones_abiertas,modalidad_inscripcion,minimo_integrantes_equipo,maximo_integrantes_equipo,cuenta_para_certificado,estado')
    .eq('evento_id', eventoId)
    .eq('estado', 'publicado')
    .order('fecha_inicio', { ascending: true })
  if (tipo) q = q.eq('tipo', tipo)
  const { data, error } = await q
  if (error) throw error
  return data || []
}

export async function obtenerPonentesPublicos(eventoId) {
  if (!supabase || !eventoId) return []
  const { data, error } = await supabase
    .from('actividad_ponentes')
    .select(`
      actividad_id,
      ponentes(id,nombres,apellidos,cargo,institucion,biografia,foto_url),
      actividades!inner(id,evento_id,titulo,estado)
    `)
    .eq('actividades.evento_id', eventoId)
    .eq('actividades.estado', 'publicado')
  if (error) throw error
  const vistos = new Set()
  return (data || []).map(x => x.ponentes).filter(p => p && !vistos.has(p.id) && vistos.add(p.id))
}

export async function obtenerSalasPublicas(eventoId) {
  if (!supabase || !eventoId) return []
  const { data, error } = await supabase
    .from('salas')
    .select('id,nombre,ubicacion,evento_id,activo')
    .eq('evento_id', eventoId)
    .eq('activo', true)
    .order('nombre')
  if (error) throw error
  return data || []
}


export async function obtenerTarifasPublicas(eventoId) {
  if (!supabase || !eventoId) return []
  const { data, error } = await supabase
    .from('tarifas_fase29')
    .select('evento_id,clave,nombre,monto,activo')
    .eq('evento_id', eventoId)
    .eq('activo', true)
    .order('monto', { ascending: true })
  if (error) throw error
  return data || []
}

export async function obtenerEstadisticasPublicas(eventoId) {
  if (!supabase || !eventoId) return { registrados: 0, talleres: 0 }
  const { data, error } = await supabase.rpc('estadisticas_publicas_evento', { p_evento_id: eventoId })
  if (error) return { registrados: 0, talleres: 0 }
  return data || { registrados: 0, talleres: 0 }
}

export async function leerContenidoSitio(clave = 'site:content') {
  if (!supabase) return null
  const { data, error } = await supabase
    .from('contenido_sitio')
    .select('valor')
    .eq('clave', clave)
    .maybeSingle()
  if (error) {
    // Si el SQL complementario aún no se ejecutó, la web puede seguir con defaults.
    console.warn('No se pudo leer contenido_sitio:', error.message)
    return null
  }
  return data ? { value: data.valor } : null
}

export async function guardarContenidoSitio(clave, valor, publico = true) {
  const cliente = exigirSupabase()
  const { data: authData } = await cliente.auth.getUser()
  const { data, error } = await cliente
    .from('contenido_sitio')
    .upsert({
      clave,
      valor: String(valor ?? ''),
      publico,
      actualizado_por: authData.user?.id || null,
      actualizado_en: new Date().toISOString()
    }, { onConflict: 'clave' })
    .select()
    .single()
  if (error) throw error
  return data
}

export async function eliminarContenidoSitio(clave) {
  const cliente = exigirSupabase()
  const { error } = await cliente.from('contenido_sitio').delete().eq('clave', clave)
  if (error) throw error
}

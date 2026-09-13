import { exigirSupabase, supabase } from '../../servicios/supabase.js'
import { obtenerUsuarioActual, obtenerPerfilActual } from '../../servicios/sesion.js'

function separarNombreCompleto(nombreCompleto = '') {
  const limpio = nombreCompleto.trim().replace(/\s+/g, ' ')
  if (!limpio) return { nombres: '', apellidos: '' }
  // La interfaz Fase 29 usa un solo campo. Guardamos el nombre completo en
  // nombres para no inventar apellidos; el usuario puede editarlo después.
  return { nombres: limpio, apellidos: '' }
}

export async function registrarUsuario({ nombre, correo, password, telefono, universidad, carrera, ciudad, tipoParticipante }) {
  const cliente = exigirSupabase()
  const { nombres, apellidos } = separarNombreCompleto(nombre)

  const { data, error } = await cliente.auth.signUp({
    email: correo,
    password,
    options: {
      data: {
        nombres,
        apellidos,
        telefono: telefono || '',
        institucion: universidad || '',
        carrera: carrera || '',
        ciudad: ciudad || '',
        tipo_participante: tipoParticipante || 'Estudiante'
      }
    }
  })
  if (error) throw error

  // Si Confirm email está desactivado, signUp devuelve sesión y podemos
  // completar el perfil inmediatamente. Si está activado, se sincroniza al login.
  if (data.session && data.user) {
    await sincronizarPerfilDesdeMetadata(data.user)
  }
  return data
}

export async function iniciarSesion(correo, password) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.auth.signInWithPassword({ email: correo, password })
  if (error) throw error
  if (data.user) await sincronizarPerfilDesdeMetadata(data.user)
  return data
}

export async function sincronizarPerfilDesdeMetadata(usuario = null) {
  const cliente = exigirSupabase()
  const user = usuario || await obtenerUsuarioActual()
  if (!user) return null
  const m = user.user_metadata || {}
  const cambios = {}
  if (m.nombres) cambios.nombres = m.nombres
  if (m.apellidos !== undefined) cambios.apellidos = m.apellidos || ''
  if (m.telefono) cambios.telefono = m.telefono
  if (m.institucion) cambios.institucion = m.institucion
  if (m.carrera) cambios.carrera = m.carrera
  if (!Object.keys(cambios).length) return null

  const { data, error } = await cliente
    .from('perfiles')
    .update(cambios)
    .eq('id', user.id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function actualizarPerfil({ nombre, telefono, universidad, carrera, ciudad }) {
  const cliente = exigirSupabase()
  const user = await obtenerUsuarioActual()
  if (!user) throw new Error('Debes iniciar sesión.')
  const { nombres, apellidos } = separarNombreCompleto(nombre)

  const { data, error } = await cliente
    .from('perfiles')
    .update({
      nombres,
      apellidos,
      telefono: telefono || null,
      institucion: universidad || null,
      carrera: carrera || null
    })
    .eq('id', user.id)
    .select()
    .single()
  if (error) throw error

  // ciudad y tipo_participante son datos de presentación de Fase 29 y se
  // conservan en metadata de Auth porque el esquema V3.2.1 no tiene esas columnas.
  const { error: metaError } = await cliente.auth.updateUser({
    data: { ...(user.user_metadata || {}), ciudad: ciudad || '' }
  })
  if (metaError) throw metaError
  return data
}

export async function eliminarMiCuenta() {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('eliminar_mi_cuenta')
  if (error) throw error
  try { await cliente.auth.signOut() } catch (_) {}
  return data
}

export async function obtenerRegistroParticipante(eventoId) {
  if (!supabase) return null
  const user = await obtenerUsuarioActual()
  if (!user) return null
  const perfil = await obtenerPerfilActual()
  const meta = user.user_metadata || {}

  let inscripcion = null
  let pagoFase29 = null
  let talleres = []
  let certificado = null
  let acreditado = false

  if (eventoId) {
    const { data: ie } = await supabase
      .from('inscripciones_evento')
      .select('*')
      .eq('evento_id', eventoId)
      .eq('usuario_id', user.id)
      .maybeSingle()
    inscripcion = ie || null

    const { data: pago } = await supabase
      .from('pagos_fase29')
      .select('tipo_entrada,monto,medio,referencia,estado_pago,creado_en')
      .eq('evento_id', eventoId)
      .eq('usuario_id', user.id)
      .maybeSingle()
    pagoFase29 = pago || null

    const { data: ia } = await supabase
      .from('inscripciones_actividad')
      .select('id, estado, inscrito_en, actividades!inner(id,titulo,tipo,evento_id)')
      .eq('usuario_id', user.id)
      .eq('actividades.evento_id', eventoId)
      .eq('actividades.tipo', 'taller')
      .neq('estado', 'cancelado')
    talleres = (ia || []).map(x => ({
      id: x.actividades?.id,
      nombre: x.actividades?.titulo || 'Taller',
      fecha: x.inscrito_en
    }))

    const { data: sesionPresencia } = await supabase
      .from('sesiones_presencia')
      .select('id')
      .eq('evento_id', eventoId)
      .eq('usuario_id', user.id)
      .neq('estado', 'anulada')
      .limit(1)
    acreditado = !!(sesionPresencia && sesionPresencia.length)

    const { data: cert } = await supabase
      .from('certificados')
      .select('*')
      .eq('evento_id', eventoId)
      .eq('usuario_id', user.id)
      .eq('estado', 'emitido')
      .order('emitido_en', { ascending: false })
      .limit(1)
      .maybeSingle()
    certificado = cert || null
  }

  const nombre = [perfil?.nombres, perfil?.apellidos].filter(Boolean).join(' ').trim() || user.email || 'Participante'
  const compras = inscripcion ? [{
    tipo: pagoFase29?.tipo_entrada || 'Inscripción general',
    monto: pagoFase29?.monto ?? 0,
    metodo: pagoFase29?.medio || inscripcion.medio_pago || (inscripcion.estado_pago === 'no_requiere' ? 'no_requiere' : 'pendiente'),
    fecha: pagoFase29?.creado_en || inscripcion.inscrito_en,
    estado: inscripcion.estado,
    estadoPago: inscripcion.estado_pago,
    referencia: pagoFase29?.referencia || inscripcion.referencia_pago
  }] : []

  return {
    id: user.id,
    nombre,
    correo: user.email || perfil?.correo || '',
    telefono: perfil?.telefono || '',
    universidad: perfil?.institucion || '',
    carrera: perfil?.carrera || '',
    ciudad: meta.ciudad || '',
    tipoParticipante: meta.tipo_participante || 'Estudiante',
    estado: acreditado ? 'Acreditado' : (inscripcion?.estado === 'inscrito' ? 'Inscrito' : 'Registrado'),
    compras,
    talleres,
    creado: user.created_at,
    codigoCertificado: certificado?.codigo || null,
    certificado,
    inscripcion
  }
}

export async function inscribirseEvento(eventoId) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('inscribirse_evento', { p_evento_id: eventoId })
  if (error) throw error
  return data
}

export async function registrarReferenciaPago(eventoId, medio, referencia, metaEntrada = {}) {
  const cliente = exigirSupabase()
  const { data, error } = await cliente.rpc('registrar_referencia_pago_evento', {
    p_evento_id: eventoId,
    p_medio: medio,
    p_referencia: referencia,
    p_tipo_entrada: metaEntrada.tipo || null
  })
  if (error) throw error
  return data
}

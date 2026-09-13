export function nombrePerfil(perfil = {}) {
  return [perfil.nombres, perfil.apellidos].filter(Boolean).join(' ').trim() || perfil.correo || 'Participante'
}

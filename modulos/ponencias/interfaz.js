export function mensajeInscripcion(resultado) {
  if (!resultado) return 'Inscripción procesada.'
  return resultado.mensaje || (resultado.ok ? 'Inscripción registrada correctamente.' : 'No fue posible registrar la inscripción.')
}

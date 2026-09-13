export function estadoElegibilidad(info = {}) {
  if (info.apto) return info.ya_emitido ? 'Certificado ya emitido' : 'Apto para emitir certificado'
  return info.motivo || 'Todavía no cumples los requisitos.'
}

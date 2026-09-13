export function describirAccionEscaneo(resultado = {}) {
  if (resultado.accion === 'entrada') return `Entrada registrada en ${resultado.sala || 'la sala'}.`
  if (resultado.accion === 'salida') return `Salida registrada de ${resultado.sala || 'la sala'}.`
  if (resultado.accion === 'cambio_sala') return `Cambio de ${resultado.sala_anterior || 'sala'} a ${resultado.sala_nueva || 'otra sala'}.`
  return resultado.mensaje || 'Escaneo procesado.'
}

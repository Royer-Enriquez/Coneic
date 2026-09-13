export function describirModalidad(modalidad) {
  return ({ individual: 'Individual', equipo: 'Por equipo', ambos: 'Individual o equipo' })[modalidad] || modalidad
}

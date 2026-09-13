export function porcentaje(parte, total) {
  return total ? Math.round((parte / total) * 100) : 0
}

export function mostrarErrorAutenticacion(elemento, mensaje) {
  if (!elemento) return
  elemento.textContent = mensaje || ''
  elemento.className = mensaje ? 'form-msg err' : 'form-msg'
}

// Regla de las imagenes del lado del panel, compartida por misiones y objetos.
// Es la misma que backend/src/validaciones/imagen.js, con el mismo mensaje.
//
// Recibe el texto ya recortado. Devuelve el mensaje de error, o null si la
// imagen esta vacia (es opcional) o es una direccion http o https.
export function errorDeImagen(imagen) {
  if (imagen === '') return null
  try {
    const url = new URL(imagen)
    if (url.protocol === 'http:' || url.protocol === 'https:') return null
  } catch {
    // No es una URL: cae al error de abajo.
  }
  return 'La imagen debe ser una dirección http o https'
}

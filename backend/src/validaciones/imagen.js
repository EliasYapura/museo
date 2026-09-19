// Regla de las imagenes, compartida por misiones (ADM02) y objetos (ADM16).
//
// La imagen es opcional: ausente o vacia se guarda como NULL. Si viene, solo
// se aceptan direcciones http o https. Un esquema como "javascript:" guardado
// en la base podria ejecutar codigo en el navegador de quien abra el registro,
// si algun dia se usa la direccion como enlace.
//
// Devuelve { valor } o { error }, como las demas reglas.
export function validarImagen(valor) {
  if (valor === undefined || valor === null) return { valor: null };
  if (typeof valor !== 'string') return { error: 'La imagen debe ser una dirección http o https' };

  const texto = valor.trim();
  if (texto === '') return { valor: null };

  try {
    const url = new URL(texto);
    if (url.protocol === 'http:' || url.protocol === 'https:') return { valor: texto };
  } catch {
    // No es una URL: cae al error de abajo.
  }
  return { error: 'La imagen debe ser una dirección http o https' };
}

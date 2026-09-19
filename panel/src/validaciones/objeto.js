// Reglas de los datos de un objeto, del lado del panel (ADM15, ADM16).
//
// Son las mismas que aplica la API en backend/src/validaciones/objeto.js, con
// los mismos mensajes. Igual que con las misiones, la copia de la API es la
// que manda: esta existe solo para avisar al instante. Que la sala exista lo
// controla la API; el panel solo ofrece las salas que ella devolvio.

import { errorDeImagen } from './imagen.js'

const LARGO_MAXIMO_NOMBRE = 200

// Cuenta caracteres igual que PostgreSQL: un emoji vale 1, no 2.
const largo = (texto) => [...texto].length

// Recibe los valores del formulario (todos texto) y devuelve los errores por
// campo y el cuerpo listo para enviar a la API.
export function validarObjeto(campos) {
  const errores = {}

  const nombre = campos.nombre.trim()
  if (nombre === '') errores.nombre = 'El nombre es obligatorio'
  else if (largo(nombre) > LARGO_MAXIMO_NOMBRE) {
    errores.nombre = `El nombre no puede superar los ${LARGO_MAXIMO_NOMBRE} caracteres`
  }

  if (campos.sala_id === '') errores.sala_id = 'La sala es obligatoria'

  const datoClave = campos.dato_clave.trim()
  if (datoClave === '') errores.dato_clave = 'El dato clave es obligatorio'

  // La descripcion es opcional y no tiene reglas: vacia, la API la guarda
  // como "sin descripcion".
  const descripcion = campos.descripcion.trim()

  const imagen = campos.imagen_url.trim()
  const errorImagen = errorDeImagen(imagen)
  if (errorImagen) errores.imagen_url = errorImagen

  return {
    errores,
    cuerpo: {
      nombre,
      sala_id: Number(campos.sala_id),
      dato_clave: datoClave,
      descripcion,
      imagen_url: imagen,
    },
  }
}

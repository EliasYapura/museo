// Reglas de los datos de una mision, del lado del panel (ADM02).
//
// Son las mismas que aplica la API en backend/src/validaciones/mision.js, con
// los mismos mensajes. Estan duplicadas porque el panel y la API son proyectos
// separados que no comparten codigo. La copia de la API es la que manda: esta
// existe solo para avisar al instante, sin esperar al servidor. Si se cambia
// una regla, hay que cambiarla en los dos lugares.

import { errorDeImagen } from './imagen.js'

export const DURACION_MINIMA = 1
export const DURACION_MAXIMA = 240
const LARGO_MAXIMO_NOMBRE = 200

// Cuenta caracteres igual que PostgreSQL: un emoji vale 1, no 2.
const largo = (texto) => [...texto].length

// Recibe los valores del formulario (todos texto) y devuelve los errores por
// campo y el cuerpo listo para enviar a la API.
//
// duracionIlegible: un campo type="number" entrega texto vacio tanto si esta
// vacio como si tiene algo que no es un numero (por ejemplo "12abc"). El
// navegador distingue los dos casos en validity.badInput; sin este dato, a
// quien escribio "12abc" se le diria que la duracion es obligatoria.
export function validarMision(campos, { duracionIlegible = false } = {}) {
  const errores = {}

  const nombre = campos.nombre.trim()
  if (nombre === '') errores.nombre = 'El nombre es obligatorio'
  else if (largo(nombre) > LARGO_MAXIMO_NOMBRE) {
    errores.nombre = `El nombre no puede superar los ${LARGO_MAXIMO_NOMBRE} caracteres`
  }

  const descripcion = campos.descripcion.trim()
  if (descripcion === '') errores.descripcion = 'La descripción es obligatoria'

  const duracionTexto = campos.duracion_estimada.trim()
  const duracion = Number(duracionTexto)
  if (duracionIlegible || (duracionTexto !== '' && !Number.isInteger(duracion))) {
    errores.duracion_estimada = 'La duración debe ser un número entero de minutos'
  } else if (duracionTexto === '') {
    errores.duracion_estimada = 'La duración es obligatoria'
  } else if (duracion < DURACION_MINIMA || duracion > DURACION_MAXIMA) {
    errores.duracion_estimada = `La duración debe estar entre ${DURACION_MINIMA} y ${DURACION_MAXIMA} minutos`
  }

  const imagen = campos.imagen_url.trim()
  const errorImagen = errorDeImagen(imagen)
  if (errorImagen) errores.imagen_url = errorImagen

  return {
    errores,
    cuerpo: { nombre, descripcion, duracion_estimada: duracion, imagen_url: imagen },
  }
}

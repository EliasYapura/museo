// Nombre legible de cada tipo de desafio (ADM08). Los valores son los del
// enum tipo_desafio de la base; el texto es lo que ve el administrador.
export const TIPOS_DESAFIO = [
  ['pregunta_opcion_multiple', 'Pregunta de opción múltiple'],
  ['respuesta_corta', 'Respuesta corta'],
  ['escaneo_objeto', 'Escaneo de objeto'],
  ['busqueda_guiada', 'Búsqueda guiada'],
]

const NOMBRES = Object.fromEntries(TIPOS_DESAFIO)

export const nombreDeTipo = (tipo) => NOMBRES[tipo] ?? tipo

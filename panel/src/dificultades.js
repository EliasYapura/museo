// Las tres dificultades de una misión (ADM03), con el nombre que se muestra.
// Son los mismos valores del enum dificultad_mision de la base y de
// backend/src/validaciones/mision.js.

export const DIFICULTADES = [
  ['facil', 'Fácil'],
  ['media', 'Media'],
  ['dificil', 'Difícil'],
]

export const DIFICULTAD_POR_DEFECTO = 'media'

export const nombreDeDificultad = (valor) =>
  DIFICULTADES.find(([clave]) => clave === valor)?.[1] ?? valor

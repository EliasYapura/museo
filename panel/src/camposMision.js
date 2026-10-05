// Conversion entre una mision de la API y los campos del formulario, que los
// maneja todos como texto. Esta separado del componente FormularioMision
// porque la recarga en caliente de Vite (Fast Refresh) solo funciona bien
// cuando un archivo .jsx exporta unicamente componentes.

import { DIFICULTAD_POR_DEFECTO } from './dificultades.js'

export const CAMPOS_VACIOS = {
  nombre: '',
  descripcion: '',
  duracion_estimada: '',
  dificultad: DIFICULTAD_POR_DEFECTO,
  imagen_url: '',
}

export const camposDesdeMision = (mision) => ({
  nombre: mision.nombre,
  descripcion: mision.descripcion,
  duracion_estimada: String(mision.duracion_estimada),
  dificultad: mision.dificultad,
  imagen_url: mision.imagen_url ?? '',
})

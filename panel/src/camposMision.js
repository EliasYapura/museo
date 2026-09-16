// Conversion entre una mision de la API y los campos del formulario, que los
// maneja todos como texto. Esta separado del componente FormularioMision
// porque la recarga en caliente de Vite (Fast Refresh) solo funciona bien
// cuando un archivo .jsx exporta unicamente componentes.

export const CAMPOS_VACIOS = { nombre: '', descripcion: '', duracion_estimada: '', imagen_url: '' }

export const camposDesdeMision = (mision) => ({
  nombre: mision.nombre,
  descripcion: mision.descripcion,
  duracion_estimada: String(mision.duracion_estimada),
  imagen_url: mision.imagen_url ?? '',
})

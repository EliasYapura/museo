// Conversion entre un objeto de la API y los campos del formulario, que los
// maneja todos como texto. Separado del componente por el mismo motivo que
// camposMision.js (Fast Refresh).

export const CAMPOS_VACIOS = { nombre: '', sala_id: '', dato_clave: '' }

export const camposDesdeObjeto = (objeto) => ({
  nombre: objeto.nombre,
  sala_id: String(objeto.sala_id),
  dato_clave: objeto.dato_clave,
})

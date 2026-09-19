// Conversion entre un objeto de la API y los campos del formulario, que los
// maneja todos como texto. Separado del componente por el mismo motivo que
// camposMision.js (Fast Refresh).

export const CAMPOS_VACIOS = { nombre: '', sala_id: '', dato_clave: '', descripcion: '', imagen_url: '' }

// descripcion e imagen_url pueden venir como null (sin dato): el campo del
// formulario los muestra vacios.
export const camposDesdeObjeto = (objeto) => ({
  nombre: objeto.nombre,
  sala_id: String(objeto.sala_id),
  dato_clave: objeto.dato_clave,
  descripcion: objeto.descripcion ?? '',
  imagen_url: objeto.imagen_url ?? '',
})

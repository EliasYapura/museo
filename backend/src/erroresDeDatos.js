// Codigos de error de PostgreSQL que indican datos invalidos. La validacion
// deberia atajarlos antes; esto es la ultima red por si una regla de la base
// y una de la API llegaran a diferir. Sin esta traduccion llegarian al
// manejador general como error 500, que significa "fallo el servidor".
// Lo usan todas las rutas que guardan datos (misiones, objetos).
const ERRORES_DE_DATOS = {
  '23502': 'Falta un dato obligatorio', // not_null_violation
  '23514': 'Algún dato está fuera del rango permitido', // check_violation
  '22P02': 'Algún dato tiene un formato inválido', // invalid_text_representation
  '22003': 'Algún número es demasiado grande', // numeric_value_out_of_range
  '22001': 'Algún texto es demasiado largo', // string_data_right_truncation
};

export function responderSiEsErrorDeDatos(err, res) {
  if (!ERRORES_DE_DATOS[err.code]) return false;
  res.status(400).json({ error: ERRORES_DE_DATOS[err.code] });
  return true;
}

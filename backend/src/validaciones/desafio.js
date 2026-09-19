// Reglas de los datos comunes a todos los desafios (ADM08). Crear y editar
// usan este mismo modulo.
//
// Los campos propios de cada tipo (columna configuracion) son de ADM09 y la
// respuesta correcta es de ADM12: todavia no se validan aca.

// Los cuatro valores del enum tipo_desafio de la base.
export const TIPOS_DESAFIO = [
  'pregunta_opcion_multiple',
  'respuesta_corta',
  'escaneo_objeto',
  'busqueda_guiada',
];

function validarEnunciado(valor) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    return { error: 'El enunciado es obligatorio' };
  }
  return { valor: valor.trim() };
}

function validarTipo(valor) {
  if (valor === undefined || valor === null || valor === '') {
    return { error: 'El tipo de desafío es obligatorio' };
  }
  if (!TIPOS_DESAFIO.includes(valor)) {
    return { error: 'El tipo de desafío no es válido' };
  }
  return { valor };
}

// El objeto del museo es opcional: hay desafios que no apuntan a una pieza
// concreta. Si viene, tiene que ser un id posible; que exista lo controla la
// base con la clave foranea. El tope de 15 digitos es el mismo criterio que
// para los ids de las rutas: con mas, Number() pierde precision.
function validarObjeto(valor) {
  if (valor === undefined || valor === null || valor === '') return { valor: null };
  if (typeof valor !== 'number' || !Number.isInteger(valor) || valor < 1 || valor > 999999999999999) {
    return { error: 'El objeto elegido no existe' };
  }
  return { valor };
}

export function validarDesafio(datos) {
  const resultados = {
    enunciado: validarEnunciado(datos.enunciado),
    tipo: validarTipo(datos.tipo),
    objeto_id: validarObjeto(datos.objeto_id),
  };

  const valores = {};
  const errores = {};
  for (const [campo, resultado] of Object.entries(resultados)) {
    if (resultado.error) errores[campo] = resultado.error;
    else valores[campo] = resultado.valor;
  }
  return { valores, errores };
}

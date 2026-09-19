// Reglas de los datos de un desafio: los comunes a todos (ADM08) y los
// propios de cada tipo, que van en la columna configuracion (ADM09).
// La respuesta correcta es de ADM12: todavia no se valida aca.
//
// La configuracion se arma segun el tipo y solo con las claves de ese tipo:
// lo que venga de mas se descarta, asi cambiar el tipo de un desafio no deja
// guardados los datos del tipo anterior.

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

// Tipos donde el visitante tiene que llegar a una pieza concreta: sin objeto
// asociado no hay nada que escanear ni que buscar.
export const TIPOS_CON_OBJETO = ['escaneo_objeto', 'busqueda_guiada'];

// Como se compara la respuesta escrita en un desafio de respuesta corta.
export const TOLERANCIAS = ['exacta', 'flexible'];

export const MINIMO_OPCIONES = 2;
export const MAXIMO_OPCIONES = 6;
const LARGO_MAXIMO_OPCION = 200;

// Opciones de una pregunta de opcion multiple. Se recortan los espacios y se
// rechazan las repetidas sin distinguir mayusculas: dos opciones que el
// visitante lee como la misma harian la pregunta imposible de responder.
function validarOpciones(valor) {
  if (!Array.isArray(valor)) {
    return { error: `Cargá entre ${MINIMO_OPCIONES} y ${MAXIMO_OPCIONES} opciones` };
  }
  if (valor.some((opcion) => typeof opcion !== 'string')) {
    return { error: 'Las opciones tienen que ser texto' };
  }

  const opciones = valor.map((opcion) => opcion.trim()).filter((opcion) => opcion !== '');
  if (opciones.length < MINIMO_OPCIONES || opciones.length > MAXIMO_OPCIONES) {
    return { error: `Cargá entre ${MINIMO_OPCIONES} y ${MAXIMO_OPCIONES} opciones` };
  }
  if (opciones.some((opcion) => [...opcion].length > LARGO_MAXIMO_OPCION)) {
    return { error: `Cada opción puede tener hasta ${LARGO_MAXIMO_OPCION} caracteres` };
  }

  const vistas = new Set(opciones.map((opcion) => opcion.toLowerCase()));
  if (vistas.size !== opciones.length) return { error: 'No puede haber opciones repetidas' };

  return { valor: opciones };
}

function validarTolerancia(valor) {
  // Sin dato se usa la comparacion flexible, que es la que menos frustra al
  // visitante: una tilde o una mayuscula no deberian dar la respuesta por mal.
  if (valor === undefined || valor === null || valor === '') return { valor: 'flexible' };
  if (!TOLERANCIAS.includes(valor)) return { error: 'La comparación elegida no es válida' };
  return { valor };
}

// Devuelve { configuracion, errores } segun el tipo. Los tipos de escaneo y
// busqueda no guardan nada: lo que hay que escanear se sabe por el objeto
// asociado, asi que si se regenera su codigo (ADM17) el desafio sigue
// apuntando a la pieza correcta.
function validarConfiguracion(tipo, datos) {
  if (tipo === 'pregunta_opcion_multiple') {
    const resultado = validarOpciones(datos.opciones);
    if (resultado.error) return { errores: { opciones: resultado.error } };
    return { configuracion: { opciones: resultado.valor }, errores: {} };
  }

  if (tipo === 'respuesta_corta') {
    const resultado = validarTolerancia(datos.tolerancia);
    if (resultado.error) return { errores: { tolerancia: resultado.error } };
    return { configuracion: { tolerancia: resultado.valor }, errores: {} };
  }

  return { configuracion: {}, errores: {} };
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

  // La configuracion depende del tipo: si el tipo no es valido, no tiene
  // sentido revisarla todavia.
  if (valores.tipo) {
    if (TIPOS_CON_OBJETO.includes(valores.tipo) && !errores.objeto_id && valores.objeto_id === null) {
      errores.objeto_id = 'Para este tipo hay que elegir el objeto';
    }

    const configuracion = validarConfiguracion(valores.tipo, datos);
    Object.assign(errores, configuracion.errores);
    if (Object.keys(configuracion.errores).length === 0) {
      valores.configuracion = configuracion.configuracion;
    }
  }

  return { valores, errores };
}

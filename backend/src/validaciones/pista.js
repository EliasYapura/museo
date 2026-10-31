// Reglas de los datos de una pista (ADM13). Estan en un modulo propio para que
// crear y editar apliquen exactamente las mismas, igual que con las misiones.
//
// Devuelve { valores, errores }, con el mismo criterio que las demas
// validaciones: todos los errores juntos, para no corregirlos de a uno.

import { PUNTOS_MAXIMOS } from './desafio.js';

// Una pista es una ayuda corta que se lee de un vistazo en el telefono, no un
// parrafo. La columna es TEXT y no tiene tope propio, asi que el limite lo
// pone la API.
const LARGO_MAXIMO_TEXTO = 300;

// PostgreSQL cuenta caracteres, pero .length de JavaScript cuenta unidades
// UTF-16: un emoji mide 2. El iterador de strings cuenta como la base.
const largo = (texto) => [...texto].length;

function validarTexto(valor) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    return { error: 'El texto de la pista es obligatorio' };
  }
  const texto = valor.trim();
  if (largo(texto) > LARGO_MAXIMO_TEXTO) {
    return { error: `La pista no puede superar los ${LARGO_MAXIMO_TEXTO} caracteres` };
  }
  return { valor: texto };
}

// Puntos que se le descuentan al visitante por pedir la pista (VIS07). El
// techo es el mismo que el de los puntos de un desafio.
//
// A proposito no se compara contra los puntos del desafio: el administrador
// puede bajarselos despues y las pistas ya cargadas quedarian invalidas de
// forma retroactiva, sin haberlas tocado. El formulario le muestra los puntos
// del desafio para que lo decida, y al cobrarla el puntaje no baja de cero.
//
// El 0 se permite: sirve para una pista de ambiente, que acompana sin castigar.
function validarPenalizacion(valor) {
  if (valor === undefined || valor === null || valor === '') return { valor: 0 };
  if (typeof valor !== 'number' || !Number.isInteger(valor) || valor < 0 || valor > PUNTOS_MAXIMOS) {
    return { error: `La penalización tiene que ser un número entero entre 0 y ${PUNTOS_MAXIMOS}` };
  }
  return { valor };
}

export function validarPista(datos) {
  const resultados = {
    texto: validarTexto(datos.texto),
    penalizacion: validarPenalizacion(datos.penalizacion),
  };

  const valores = {};
  const errores = {};
  for (const [campo, resultado] of Object.entries(resultados)) {
    if (resultado.error) errores[campo] = resultado.error;
    else valores[campo] = resultado.valor;
  }
  return { valores, errores };
}

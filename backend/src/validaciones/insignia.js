// Reglas de los datos de una insignia (ADM19). Estan en un modulo propio para
// que crear y editar apliquen exactamente las mismas.
//
// La condicion de obtencion no se valida aca: no se carga desde este
// formulario. Una insignia nace con la condicion vacia, o sea que nadie la
// puede ganar, y se le pone una regla en ADM20.

import { validarImagen } from './imagen.js';

const LARGO_MAXIMO_NOMBRE = 120; // igual que la columna VARCHAR(120)

// PostgreSQL cuenta caracteres, pero .length de JavaScript cuenta unidades
// UTF-16: un emoji mide 2. El iterador de strings cuenta como la base.
const largo = (texto) => [...texto].length;

function validarNombre(valor) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    return { error: 'El nombre es obligatorio' };
  }
  const nombre = valor.trim();
  if (largo(nombre) > LARGO_MAXIMO_NOMBRE) {
    return { error: `El nombre no puede superar los ${LARGO_MAXIMO_NOMBRE} caracteres` };
  }
  return { valor: nombre };
}

// Es lo que lee el visitante cuando la gana, asi que tiene que decir por que
// se la dieron. Por eso es obligatoria y no un campo suelto.
function validarDescripcion(valor) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    return { error: 'La descripción es obligatoria' };
  }
  return { valor: valor.trim() };
}

export function validarInsignia(datos) {
  const resultados = {
    nombre: validarNombre(datos.nombre),
    descripcion: validarDescripcion(datos.descripcion),
    icono_url: validarImagen(datos.icono_url),
  };

  const valores = {};
  const errores = {};
  for (const [campo, resultado] of Object.entries(resultados)) {
    if (resultado.error) errores[campo] = resultado.error;
    else valores[campo] = resultado.valor;
  }
  return { valores, errores };
}

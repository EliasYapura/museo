// Reglas de los datos de un objeto del museo (ADM15, ADM16, ADM17). Crear y
// editar usan este mismo modulo, igual que las misiones.
//
// Devuelve { valores, errores }, con el mismo formato que validarMision.
// La existencia de la sala no se revisa aca: la controla la base con la
// clave foranea, y la ruta traduce ese error a un mensaje en el campo sala.

import { validarImagen } from './imagen.js';

const LARGO_MAXIMO_NOMBRE = 200; // igual que la columna VARCHAR(200)

// Cuenta caracteres igual que PostgreSQL: un emoji vale 1, no 2.
const largo = (texto) => [...texto].length;

function validarTextoObligatorio(valor, mensajeObligatorio) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    return { error: mensajeObligatorio };
  }
  return { valor: valor.trim() };
}

// Texto opcional (ADM16): ausente, vacio o de solo espacios se guarda como
// NULL, asi "sin descripcion" se representa siempre igual en la base.
function validarTextoOpcional(valor, mensajeTipo) {
  if (valor === undefined || valor === null) return { valor: null };
  if (typeof valor !== 'string') return { error: mensajeTipo };
  const texto = valor.trim();
  return { valor: texto === '' ? null : texto };
}

// La sala llega como el id elegido en el selector. Tiene que ser un numero
// entero positivo; "3" (texto) o 3.5 se rechazan, como la duracion de una mision.
// El tope es el maximo de la columna INTEGER: con mas, la base fallaria.
function validarSala(valor) {
  if (valor === undefined || valor === null || valor === '') {
    return { error: 'La sala es obligatoria' };
  }
  if (typeof valor !== 'number' || !Number.isInteger(valor) || valor < 1 || valor > 2147483647) {
    return { error: 'La sala elegida no existe' };
  }
  return { valor };
}

// Tipo de identificador que lleva la pieza (ADM17). Son los dos valores del
// enum tipo_identificador de la base. Si no viene, queda en qr, el valor por
// defecto de la columna.
export const TIPOS_IDENTIFICADOR = ['qr', 'nfc'];

function validarTipoIdentificador(valor) {
  if (valor === undefined || valor === null || valor === '') return { valor: 'qr' };
  if (!TIPOS_IDENTIFICADOR.includes(valor)) {
    return { error: 'El identificador debe ser QR o NFC' };
  }
  return { valor };
}

export function validarObjeto(datos) {
  const resultados = {
    nombre: validarTextoObligatorio(datos.nombre, 'El nombre es obligatorio'),
    sala_id: validarSala(datos.sala_id),
    dato_clave: validarTextoObligatorio(datos.dato_clave, 'El dato clave es obligatorio'),
    descripcion: validarTextoOpcional(datos.descripcion, 'La descripción debe ser un texto'),
    imagen_url: validarImagen(datos.imagen_url),
    tipo_identificador: validarTipoIdentificador(datos.tipo_identificador),
  };

  if (resultados.nombre.valor !== undefined && largo(resultados.nombre.valor) > LARGO_MAXIMO_NOMBRE) {
    resultados.nombre = { error: `El nombre no puede superar los ${LARGO_MAXIMO_NOMBRE} caracteres` };
  }

  const valores = {};
  const errores = {};
  for (const [campo, resultado] of Object.entries(resultados)) {
    if (resultado.error) errores[campo] = resultado.error;
    else valores[campo] = resultado.valor;
  }
  return { valores, errores };
}

// Reglas de los datos de un objeto del museo (ADM15). Crear y editar usan
// este mismo modulo, igual que las misiones.
//
// Devuelve { valores, errores }, con el mismo formato que validarMision.
// La existencia de la sala no se revisa aca: la controla la base con la
// clave foranea, y la ruta traduce ese error a un mensaje en el campo sala.

const LARGO_MAXIMO_NOMBRE = 200; // igual que la columna VARCHAR(200)

// Cuenta caracteres igual que PostgreSQL: un emoji vale 1, no 2.
const largo = (texto) => [...texto].length;

function validarTextoObligatorio(valor, mensajeObligatorio) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    return { error: mensajeObligatorio };
  }
  return { valor: valor.trim() };
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

export function validarObjeto(datos) {
  const resultados = {
    nombre: validarTextoObligatorio(datos.nombre, 'El nombre es obligatorio'),
    sala_id: validarSala(datos.sala_id),
    dato_clave: validarTextoObligatorio(datos.dato_clave, 'El dato clave es obligatorio'),
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

// Reglas de los datos de una categoria. En un modulo propio para que crear y
// editar apliquen exactamente las mismas, igual que en el resto.
//
// Devuelve { valores, errores }, con el mismo criterio que las demas
// validaciones: todos los errores juntos, para no corregirlos de a uno.

// Igual que la columna VARCHAR(80).
const LARGO_MAXIMO_NOMBRE = 80;

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

export function validarCategoria(datos) {
  const resultado = validarNombre(datos.nombre);
  if (resultado.error) return { valores: {}, errores: { nombre: resultado.error } };
  return { valores: { nombre: resultado.valor }, errores: {} };
}

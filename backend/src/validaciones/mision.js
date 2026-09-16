// Reglas de los datos de una mision (ADM02). Estan en un modulo propio para
// que crear (ADM01) y editar (ADM05) apliquen exactamente las mismas.
//
// Devuelve { valores, errores }:
// - valores: los datos listos para guardar (textos sin espacios alrededor).
// - errores: un objeto campo -> mensaje. Vacio si todo esta bien.
// Se informan todos los errores juntos, para no obligar a corregirlos de a uno.

export const DURACION_MINIMA = 1;
export const DURACION_MAXIMA = 240;
const LARGO_MAXIMO_NOMBRE = 200; // igual que la columna VARCHAR(200)

// PostgreSQL cuenta caracteres, pero .length de JavaScript cuenta unidades
// UTF-16: un emoji mide 2. Contar con el iterador de strings da el mismo
// resultado que la base.
const largo = (texto) => [...texto].length;

function validarTextoObligatorio(valor, mensajeObligatorio) {
  if (typeof valor !== 'string' || valor.trim() === '') {
    return { error: mensajeObligatorio };
  }
  return { valor: valor.trim() };
}

function validarDuracion(valor) {
  if (valor === undefined || valor === null || valor === '') {
    return { error: 'La duración es obligatoria' };
  }
  // Solo numeros JSON enteros: "30" (texto) o 30.5 no son minutos validos.
  if (typeof valor !== 'number' || !Number.isInteger(valor)) {
    return { error: 'La duración debe ser un número entero de minutos' };
  }
  if (valor < DURACION_MINIMA || valor > DURACION_MAXIMA) {
    return { error: `La duración debe estar entre ${DURACION_MINIMA} y ${DURACION_MAXIMA} minutos` };
  }
  return { valor };
}

// La imagen es opcional: ausente o vacia se guarda como NULL. Si viene, solo
// se aceptan direcciones http o https. Un esquema como "javascript:" guardado
// en la base podria ejecutar codigo en el navegador de quien abra la mision,
// si algun dia se usa la direccion como enlace.
function validarImagen(valor) {
  if (valor === undefined || valor === null) return { valor: null };
  if (typeof valor !== 'string') return { error: 'La imagen debe ser una dirección http o https' };

  const texto = valor.trim();
  if (texto === '') return { valor: null };

  try {
    const url = new URL(texto);
    if (url.protocol === 'http:' || url.protocol === 'https:') return { valor: texto };
  } catch {
    // No es una URL: cae al error de abajo.
  }
  return { error: 'La imagen debe ser una dirección http o https' };
}

export function validarMision(datos) {
  const resultados = {
    nombre: validarTextoObligatorio(datos.nombre, 'El nombre es obligatorio'),
    descripcion: validarTextoObligatorio(datos.descripcion, 'La descripción es obligatoria'),
    duracion_estimada: validarDuracion(datos.duracion_estimada),
    imagen_url: validarImagen(datos.imagen_url),
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

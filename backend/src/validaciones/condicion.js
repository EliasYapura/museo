import { pool } from '../db.js';

// Reglas de la condicion con la que se gana una insignia (ADM20).
//
// La columna es JSONB, asi que la base aceptaria cualquier forma. El limite lo
// pone esto: el administrador elige uno de los tipos que el evaluador sabe
// calcular (VIS10) y completa lo que ese tipo pide. Nunca escribe JSON.
//
// Dejar que invente reglas nuevas serviria para cargar insignias que despues
// no se otorgan nunca, sin que nadie entienda por que.

export const TIPOS_CONDICION = [
  // Completar todas las misiones de una lista.
  'misiones_completadas',
  // Completar una mision sin haber pedido ninguna pista.
  'mision_sin_pistas',
  // Resolver una cantidad de desafios de escaneo sin errar ninguno.
  'escaneos_sin_error',
];

const MAXIMO_MISIONES = 50;
const MAXIMO_ESCANEOS = 1000;

const esIdPosible = (valor) =>
  typeof valor === 'number' && Number.isInteger(valor) && valor >= 1 && valor <= 999999999999999;

// Cuales de esos ids no existen como mision. Una condicion que apunta a una
// mision que no esta es una insignia que nadie va a poder ganar, y el
// administrador no tendria como darse cuenta.
async function misionesQueNoExisten(ids) {
  const { rows } = await pool.query('SELECT id FROM misiones WHERE id = ANY($1::bigint[])', [ids]);
  const existentes = new Set(rows.map((fila) => Number(fila.id)));
  return ids.filter((id) => !existentes.has(id));
}

async function validarMisionesCompletadas(datos) {
  const misiones = datos.misiones;
  if (!Array.isArray(misiones) || misiones.length === 0) {
    return { errores: { misiones: 'Elegí al menos una misión' } };
  }
  if (misiones.length > MAXIMO_MISIONES) {
    return { errores: { misiones: `No se pueden elegir más de ${MAXIMO_MISIONES} misiones` } };
  }
  if (!misiones.every(esIdPosible)) {
    return { errores: { misiones: 'Alguna de las misiones elegidas no es válida' } };
  }
  if (new Set(misiones).size !== misiones.length) {
    return { errores: { misiones: 'Hay una misión repetida' } };
  }

  const faltan = await misionesQueNoExisten(misiones);
  if (faltan.length > 0) {
    return { errores: { misiones: 'Alguna de las misiones elegidas ya no existe' } };
  }

  return { valor: { tipo: 'misiones_completadas', misiones } };
}

async function validarMisionSinPistas(datos) {
  const mision = datos.mision;
  if (!esIdPosible(mision)) return { errores: { mision: 'Elegí una misión' } };

  const faltan = await misionesQueNoExisten([mision]);
  if (faltan.length > 0) return { errores: { mision: 'Esa misión ya no existe' } };

  return { valor: { tipo: 'mision_sin_pistas', mision } };
}

function validarEscaneosSinError(datos) {
  const cantidad = datos.cantidad;
  if (
    typeof cantidad !== 'number' ||
    !Number.isInteger(cantidad) ||
    cantidad < 1 ||
    cantidad > MAXIMO_ESCANEOS
  ) {
    return { errores: { cantidad: `La cantidad tiene que ser un número entero entre 1 y ${MAXIMO_ESCANEOS}` } };
  }
  return { valor: { tipo: 'escaneos_sin_error', cantidad } };
}

// Devuelve { valor, errores }. El valor es la condicion lista para guardar.
//
// Sin tipo, la condicion queda vacia: la insignia existe pero todavia no se
// puede ganar. Es distinto de desactivarla. Sin condicion es "todavia no
// decidi como se gana"; desactivada es "ya lo decidi, pero no la quiero dar".
export async function validarCondicion(datos) {
  const tipo = datos.tipo;
  if (tipo === undefined || tipo === null || tipo === '') {
    return { valor: {}, errores: {} };
  }
  if (!TIPOS_CONDICION.includes(tipo)) {
    return { valor: {}, errores: { tipo: 'El tipo de condición no es válido' } };
  }

  const resultado =
    tipo === 'misiones_completadas'
      ? await validarMisionesCompletadas(datos)
      : tipo === 'mision_sin_pistas'
        ? await validarMisionSinPistas(datos)
        : validarEscaneosSinError(datos);

  return { valor: resultado.valor ?? {}, errores: resultado.errores ?? {} };
}

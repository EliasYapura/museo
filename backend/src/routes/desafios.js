import { Router } from 'express';
import { pool } from '../db.js';
import { responderSiEsErrorDeDatos } from '../erroresDeDatos.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { validarDesafio } from '../validaciones/desafio.js';
import { esIdValido } from '../validaciones/id.js';

// Desafios de una misión (ADM08).
//
// Son dos routers porque un desafio se mira de dos maneras:
// - desafiosDeMisionRouter, montado en /misiones/:misionId/desafios, para
//   listar los de una mision y agregarle uno. Un desafio no existe fuera de
//   una mision, asi que ahi la mision es parte de la direccion.
// - desafiosRouter, montado en /desafios, para ver, modificar o borrar uno
//   puntual, donde alcanza con su id.
export const desafiosRouter = Router();
// mergeParams: sin esto, :misionId de la direccion del montaje no llegaria.
export const desafiosDeMisionRouter = Router({ mergeParams: true });

for (const router of [desafiosRouter, desafiosDeMisionRouter]) {
  router.use(verificarToken, requerirRol('administrador'));
}

// Columnas de un desafio. Incluye el nombre del objeto asociado, que puede no
// tener: por eso LEFT JOIN y no JOIN, que dejaria afuera esos desafios.
// puntos los define el administrador en cada desafio (ADM11).
const COLUMNAS = `d.id, d.mision_id, d.orden, d.tipo, d.enunciado, d.configuracion,
                  d.respuesta_correcta, d.puntos, d.objeto_id, o.nombre AS objeto`;
const DESDE = 'FROM desafios d LEFT JOIN objetos o ON o.id = d.objeto_id';

const NO_ENCONTRADO = { error: 'El desafío no existe' };
const MISION_NO_ENCONTRADA = { error: 'La misión no existe' };
const OBJETO_INEXISTENTE = {
  error: 'Datos inválidos',
  errores: { objeto_id: 'El objeto elegido no existe' },
};

const esObjetoInexistente = (err) => err.code === '23503' && err.constraint === 'desafios_objeto_id_fkey';

// GET /misiones/:misionId/desafios — los desafios de una mision, en orden.
desafiosDeMisionRouter.get('/', async (req, res) => {
  const { misionId } = req.params;
  if (!esIdValido(misionId)) return res.status(404).json(MISION_NO_ENCONTRADA);

  const mision = await pool.query(
    'SELECT id, nombre FROM misiones WHERE id = $1 AND archivada = FALSE',
    [misionId]
  );
  if (!mision.rows[0]) return res.status(404).json(MISION_NO_ENCONTRADA);

  const { rows } = await pool.query(
    `SELECT ${COLUMNAS} ${DESDE} WHERE d.mision_id = $1 ORDER BY d.orden, d.id`,
    [misionId]
  );
  return res.json({ mision: mision.rows[0], desafios: rows });
});

// POST /misiones/:misionId/desafios — agrega un desafio a la mision (ADM08).
desafiosDeMisionRouter.post('/', async (req, res) => {
  const { misionId } = req.params;
  if (!esIdValido(misionId)) return res.status(404).json(MISION_NO_ENCONTRADA);

  const { valores, errores } = validarDesafio(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  const mision = await pool.query(
    'SELECT 1 FROM misiones WHERE id = $1 AND archivada = FALSE',
    [misionId]
  );
  if (!mision.rows[0]) return res.status(404).json(MISION_NO_ENCONTRADA);

  try {
    // El orden se calcula dentro del mismo INSERT: el desafio nuevo va al
    // final de la mision. Hacerlo en una sola consulta evita que dos altas a
    // la vez lean el mismo maximo y elijan el mismo orden, que la restriccion
    // uq_desafio_orden rechazaria. El orden se cambia despues con PUT /misiones/:misionId/desafios/orden.
    const { rows } = await pool.query(
      `WITH nuevo AS (
         INSERT INTO desafios (mision_id, objeto_id, tipo, enunciado, configuracion,
                               respuesta_correcta, puntos, orden)
         SELECT $1, $2, $3, $4, $5::jsonb, $6, $7, COALESCE(MAX(orden), 0) + 1
         FROM desafios WHERE mision_id = $1
         RETURNING *
       )
       SELECT ${COLUMNAS} FROM nuevo d LEFT JOIN objetos o ON o.id = d.objeto_id`,
      [
        misionId,
        valores.objeto_id,
        valores.tipo,
        valores.enunciado,
        JSON.stringify(valores.configuracion),
        valores.respuesta_correcta,
        valores.puntos,
      ]
    );
    return res.status(201).json({ desafio: rows[0] });
  } catch (err) {
    if (esObjetoInexistente(err)) return res.status(400).json(OBJETO_INEXISTENTE);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PUT /misiones/:misionId/desafios/orden — reordena los desafios (ADM10).
//
// Recibe la lista completa de ids en el orden deseado y los renumera 1, 2, 3...
// Se manda la lista entera y no "subi este desafio" porque asi el servidor
// tiene una sola verdad: el orden que llega es el orden final. Ademas, de paso
// se arreglan los huecos que deja un borrado.
desafiosDeMisionRouter.put('/orden', async (req, res) => {
  const { misionId } = req.params;
  if (!esIdValido(misionId)) return res.status(404).json(MISION_NO_ENCONTRADA);

  const { ids } = req.body ?? {};
  const esIdDeLista = (id) =>
    typeof id === 'number' && Number.isInteger(id) && id >= 1 && id <= 999999999999999;
  if (
    !Array.isArray(ids) ||
    ids.length === 0 ||
    !ids.every(esIdDeLista) ||
    new Set(ids).size !== ids.length
  ) {
    return res.status(400).json({ error: 'La lista de desafíos no es válida' });
  }

  // Varias consultas que tienen que valer como una sola operacion, asi que
  // van por un cliente propio del pool y no por pool.query, que puede tomar
  // una conexion distinta en cada llamada.
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');

    const mision = await cliente.query(
      'SELECT id, nombre FROM misiones WHERE id = $1 AND archivada = FALSE',
      [misionId]
    );
    if (!mision.rows[0]) {
      await cliente.query('ROLLBACK');
      return res.status(404).json(MISION_NO_ENCONTRADA);
    }

    // FOR UPDATE reserva las filas hasta cerrar la transaccion: nadie puede
    // agregar ni mover desafios de esta mision entre la lectura y el UPDATE.
    const actuales = await cliente.query(
      'SELECT id FROM desafios WHERE mision_id = $1 FOR UPDATE',
      [misionId]
    );
    const idsActuales = new Set(actuales.rows.map((fila) => Number(fila.id)));
    const estanTodos = idsActuales.size === ids.length && ids.every((id) => idsActuales.has(id));
    if (!estanTodos) {
      await cliente.query('ROLLBACK');
      // Se rechaza en vez de reordenar lo que coincida: si la lista no es la
      // de la mision, el panel esta mostrando algo viejo y conviene avisarlo.
      return res.status(400).json({
        error: 'La lista tiene que incluir exactamente los desafíos de la misión. Recargá la página.',
      });
    }

    // WITH ORDINALITY numera los elementos del arreglo segun su posicion: el
    // primer id queda con orden 1, el segundo con 2, y asi.
    // Durante el renumerado dos desafios pasan por el mismo orden, lo que
    // choca con uq_desafio_orden; la restriccion es DEFERRABLE INITIALLY
    // DEFERRED, o sea que se verifica al cerrar la transaccion, cuando ya no
    // hay repetidos.
    await cliente.query(
      `UPDATE desafios d
          SET orden = nuevo.orden::smallint
         FROM unnest($2::bigint[]) WITH ORDINALITY AS nuevo(id, orden)
        WHERE d.id = nuevo.id AND d.mision_id = $1`,
      [misionId, ids]
    );

    const { rows } = await cliente.query(
      `SELECT ${COLUMNAS} ${DESDE} WHERE d.mision_id = $1 ORDER BY d.orden, d.id`,
      [misionId]
    );
    await cliente.query('COMMIT');
    return res.json({ mision: mision.rows[0], desafios: rows });
  } catch (err) {
    await cliente.query('ROLLBACK');
    throw err;
  } finally {
    // Devuelve la conexion al pool, pase lo que pase.
    cliente.release();
  }
});

// GET /desafios/:id — datos de un desafio, para precargar el formulario.
desafiosRouter.get('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const { rows } = await pool.query(`SELECT ${COLUMNAS} ${DESDE} WHERE d.id = $1`, [req.params.id]);
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADO);
  return res.json({ desafio: rows[0] });
});

// PUT /desafios/:id — modifica el enunciado, el tipo, el objeto asociado, la
// configuracion propia del tipo y la respuesta correcta.
// La mision y el orden no se tocan: mover un desafio de mision no esta en el
// backlog y el orden se cambia por su propio endpoint (ADM10).
desafiosRouter.put('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const { valores, errores } = validarDesafio(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    const { rows } = await pool.query(
      `WITH cambiado AS (
         UPDATE desafios
         SET enunciado = $2, tipo = $3, objeto_id = $4, configuracion = $5::jsonb,
             respuesta_correcta = $6, puntos = $7
         WHERE id = $1
           AND (enunciado IS DISTINCT FROM $2
                OR tipo IS DISTINCT FROM $3
                OR objeto_id IS DISTINCT FROM $4
                -- jsonb compara el contenido, no el texto: el mismo dato con
                -- las claves en otro orden no cuenta como un cambio.
                OR configuracion IS DISTINCT FROM $5::jsonb
                OR respuesta_correcta IS DISTINCT FROM $6
                OR puntos IS DISTINCT FROM $7)
         RETURNING *
       )
       SELECT ${COLUMNAS} FROM cambiado d LEFT JOIN objetos o ON o.id = d.objeto_id`,
      [
        req.params.id,
        valores.enunciado,
        valores.tipo,
        valores.objeto_id,
        JSON.stringify(valores.configuracion),
        valores.respuesta_correcta,
        valores.puntos,
      ]
    );
    if (rows[0]) return res.json({ desafio: rows[0], modificado: true });

    const existente = await pool.query(`SELECT ${COLUMNAS} ${DESDE} WHERE d.id = $1`, [req.params.id]);
    if (!existente.rows[0]) return res.status(404).json(NO_ENCONTRADO);
    return res.json({ desafio: existente.rows[0], modificado: false });
  } catch (err) {
    if (esObjetoInexistente(err)) return res.status(400).json(OBJETO_INEXISTENTE);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// DELETE /desafios/:id — borra un desafio cargado por error.
//
// Es un borrado real y no una baja logica: la tabla no tiene una marca de
// archivado y un desafio suelto no sirve para nada. La base borra con el las
// pistas y el avance que los visitantes tuvieran en ese desafio (ON DELETE
// CASCADE), por eso el panel pide confirmacion.
// Si era el ultimo desafio de la mision, la mision se despublica sola: una
// mision publicada y vacia se le ofrece al visitante y no tiene nada para
// resolver (ADM04).
//
// Ojo con el NOT EXISTS: dentro de un WITH, todas las partes ven la misma
// foto de la base, la de antes del DELETE. Preguntar si quedan desafios
// devolveria que si, porque el que se esta borrando todavia figura. Por eso
// la condicion excluye explicitamente al que se borra.
desafiosRouter.delete('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const { rows } = await pool.query(
    `WITH borrado AS (
       DELETE FROM desafios WHERE id = $1
       RETURNING mision_id
     ), despublicada AS (
       UPDATE misiones m
       SET activa = FALSE
       FROM borrado b
       WHERE m.id = b.mision_id
         AND m.activa
         AND NOT EXISTS (
           SELECT 1 FROM desafios d WHERE d.mision_id = b.mision_id AND d.id <> $1
         )
       RETURNING m.id
     )
     SELECT (SELECT count(*) FROM borrado) AS borrados,
            (SELECT count(*) FROM despublicada) AS despublicadas`,
    [req.params.id]
  );
  if (Number(rows[0].borrados) === 0) return res.status(404).json(NO_ENCONTRADO);
  // Devuelve si la mision quedo en borrador, para que el panel pueda avisarlo:
  // es un cambio que el administrador no pidio y que no se ve en esa pantalla.
  return res.json({ despublicada: Number(rows[0].despublicadas) > 0 });
});

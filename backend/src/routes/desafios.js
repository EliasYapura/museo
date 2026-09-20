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
// puntos se devuelve pero no se edita todavia (ADM11).
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
    // uq_desafio_orden rechazaria. Reordenarlos es ADM10.
    const { rows } = await pool.query(
      `WITH nuevo AS (
         INSERT INTO desafios (mision_id, objeto_id, tipo, enunciado, configuracion,
                               respuesta_correcta, orden)
         SELECT $1, $2, $3, $4, $5::jsonb, $6, COALESCE(MAX(orden), 0) + 1
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
      ]
    );
    return res.status(201).json({ desafio: rows[0] });
  } catch (err) {
    if (esObjetoInexistente(err)) return res.status(400).json(OBJETO_INEXISTENTE);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
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
// backlog y reordenarlos es ADM10.
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
             respuesta_correcta = $6
         WHERE id = $1
           AND (enunciado IS DISTINCT FROM $2
                OR tipo IS DISTINCT FROM $3
                OR objeto_id IS DISTINCT FROM $4
                -- jsonb compara el contenido, no el texto: el mismo dato con
                -- las claves en otro orden no cuenta como un cambio.
                OR configuracion IS DISTINCT FROM $5::jsonb
                OR respuesta_correcta IS DISTINCT FROM $6)
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
desafiosRouter.delete('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const { rowCount } = await pool.query('DELETE FROM desafios WHERE id = $1', [req.params.id]);
  if (rowCount === 0) return res.status(404).json(NO_ENCONTRADO);
  return res.status(204).end();
});

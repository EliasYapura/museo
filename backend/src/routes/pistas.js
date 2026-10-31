import { Router } from 'express';
import { pool } from '../db.js';
import { responderSiEsErrorDeDatos } from '../erroresDeDatos.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { esIdValido } from '../validaciones/id.js';
import { validarPista } from '../validaciones/pista.js';

// Pistas de un desafio (ADM13).
//
// Son dos routers por el mismo motivo que los desafios: una pista no existe
// fuera de su desafio, asi que para listarlas y agregarlas el desafio es parte
// de la direccion; para editar o borrar una puntual alcanza con su id.
//
// Todo esto es solo de administracion. El texto de las pistas NO sale por
// /publico: al visitante se le entregan de a una, cuando las pide, en VIS07.
// Mandarselas todas de entrada seria regalar las respuestas, igual que pasaria
// con respuesta_correcta.
export const pistasRouter = Router();
// mergeParams: sin esto, :desafioId de la direccion del montaje no llegaria.
export const pistasDeDesafioRouter = Router({ mergeParams: true });

for (const router of [pistasRouter, pistasDeDesafioRouter]) {
  router.use(verificarToken, requerirRol('administrador'));
}

const COLUMNAS = 'id, desafio_id, orden, texto, penalizacion';

const NO_ENCONTRADA = { error: 'La pista no existe' };
const DESAFIO_NO_ENCONTRADO = { error: 'El desafío no existe' };

// GET /desafios/:desafioId/pistas — las pistas del desafio, en orden.
//
// Devuelve tambien los puntos del desafio: la pantalla los necesita para
// avisar si la suma de las penalizaciones se los come.
pistasDeDesafioRouter.get('/', async (req, res) => {
  const { desafioId } = req.params;
  if (!esIdValido(desafioId)) return res.status(404).json(DESAFIO_NO_ENCONTRADO);

  const desafio = await pool.query(
    'SELECT id, enunciado, puntos FROM desafios WHERE id = $1',
    [desafioId]
  );
  if (!desafio.rows[0]) return res.status(404).json(DESAFIO_NO_ENCONTRADO);

  const { rows } = await pool.query(
    `SELECT ${COLUMNAS} FROM pistas WHERE desafio_id = $1 ORDER BY orden, id`,
    [desafioId]
  );
  return res.json({ desafio: desafio.rows[0], pistas: rows });
});

// POST /desafios/:desafioId/pistas — agrega una pista al final del desafio.
pistasDeDesafioRouter.post('/', async (req, res) => {
  const { desafioId } = req.params;
  if (!esIdValido(desafioId)) return res.status(404).json(DESAFIO_NO_ENCONTRADO);

  const { valores, errores } = validarPista(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  const desafio = await pool.query('SELECT 1 FROM desafios WHERE id = $1', [desafioId]);
  if (!desafio.rows[0]) return res.status(404).json(DESAFIO_NO_ENCONTRADO);

  try {
    // El orden se calcula dentro del mismo INSERT, igual que en los desafios:
    // la pista nueva va al final. En una sola consulta, para que dos altas a
    // la vez no lean el mismo maximo y elijan el mismo orden, que la
    // restriccion uq_pista_orden rechazaria.
    //
    // A diferencia de los desafios, esa restriccion no es DEFERRABLE, asi que
    // el orden no se puede renumerar: un UPDATE que corra las pistas pasaria
    // por valores repetidos y la base lo cortaria a mitad de camino. Por eso
    // no hay reordenar ni rellenar huecos; borrar la pista 2 de 3 deja 1 y 3,
    // y el recorrido las entrega en ese orden igual.
    const { rows } = await pool.query(
      `INSERT INTO pistas (desafio_id, texto, penalizacion, orden)
       SELECT $1, $2, $3, COALESCE(MAX(orden), 0) + 1
       FROM pistas WHERE desafio_id = $1
       RETURNING ${COLUMNAS}`,
      [desafioId, valores.texto, valores.penalizacion]
    );
    return res.status(201).json({ pista: rows[0] });
  } catch (err) {
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PUT /pistas/:id — cambia el texto y la penalizacion.
// El desafio y el orden no se tocan: mover una pista de desafio no tiene
// sentido y el orden no es editable.
pistasRouter.put('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { valores, errores } = validarPista(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    const { rows } = await pool.query(
      `UPDATE pistas SET texto = $2, penalizacion = $3
       WHERE id = $1
       RETURNING ${COLUMNAS}`,
      [req.params.id, valores.texto, valores.penalizacion]
    );
    if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
    return res.json({ pista: rows[0] });
  } catch (err) {
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// DELETE /pistas/:id — borra una pista cargada por error.
//
// Es un borrado real: la tabla no tiene marca de archivado y una pista suelta
// no sirve para nada. El hueco que deja en el orden no se rellena.
pistasRouter.delete('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { rowCount } = await pool.query('DELETE FROM pistas WHERE id = $1', [req.params.id]);
  if (rowCount === 0) return res.status(404).json(NO_ENCONTRADA);
  return res.status(204).end();
});

import { Router } from 'express';
import { pool } from '../db.js';
import { responderSiEsErrorDeDatos } from '../erroresDeDatos.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { validarCategoria } from '../validaciones/categoria.js';
import { esIdValido } from '../validaciones/id.js';

export const categoriasRouter = Router();

categoriasRouter.use(verificarToken, requerirRol('administrador'));

// GET /categorias — las categorias con las que se clasifican los objetos
// (ADM23), con cuantas piezas tiene cada una.
//
// A diferencia de las salas, SI se administran desde la app: un museo tiene que
// poder sumar una disciplina sin que alguien le toque la base. Las salas son
// el edificio y cambian cada muchos anios; las categorias son como el museo
// decide ordenar su acervo, y eso se revisa seguido.
//
// La cuenta de objetos sirve para dos cosas: mostrar de un vistazo como esta
// repartido el acervo, y avisar cuantas piezas quedarian sueltas antes de
// borrar una categoria.
categoriasRouter.get('/', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT c.id, c.nombre,
            (SELECT count(*) FROM objetos o WHERE o.categoria_id = c.id)::int AS objetos
     FROM categorias c
     ORDER BY c.nombre`
  );

  // Cuantas piezas quedaron sin clasificar. Con un acervo grande es lo que hay
  // que poder encontrar, y sin este numero el panel no tiene como ofrecerlo.
  const { rows: sinCategoria } = await pool.query(
    'SELECT count(*)::int AS objetos FROM objetos WHERE categoria_id IS NULL'
  );

  return res.json({ categorias: rows, sin_categoria: sinCategoria[0].objetos });
});

const COLUMNAS = `c.id, c.nombre,
                  (SELECT count(*) FROM objetos o WHERE o.categoria_id = c.id)::int AS objetos`;

const NO_ENCONTRADA = { error: 'La categoría no existe' };
const NOMBRE_REPETIDO = {
  error: 'Datos inválidos',
  errores: { nombre: 'Ya hay una categoría con ese nombre' },
};

// La base avisa asi cuando se repite el nombre. Se detecta con la restriccion
// y no con un SELECT previo: entre la consulta y el INSERT, otra alta podria
// tomar el mismo nombre.
const esNombreRepetido = (err) => err.code === '23505' && err.constraint === 'categorias_nombre_key';

// POST /categorias — crea una categoria.
categoriasRouter.post('/', async (req, res) => {
  const { valores, errores } = validarCategoria(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    const { rows } = await pool.query(
      `WITH nueva AS (
         INSERT INTO categorias (nombre) VALUES ($1) RETURNING *
       )
       SELECT ${COLUMNAS} FROM nueva c`,
      [valores.nombre]
    );
    return res.status(201).json({ categoria: rows[0] });
  } catch (err) {
    if (esNombreRepetido(err)) return res.status(409).json(NOMBRE_REPETIDO);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PUT /categorias/:id — le cambia el nombre.
//
// Las piezas clasificadas no se tocan: siguen apuntando a la misma fila, asi
// que corregir un nombre mal escrito no desclasifica nada.
categoriasRouter.put('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { valores, errores } = validarCategoria(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    const { rows } = await pool.query(
      `WITH cambiada AS (
         UPDATE categorias SET nombre = $2 WHERE id = $1 RETURNING *
       )
       SELECT ${COLUMNAS} FROM cambiada c`,
      [req.params.id, valores.nombre]
    );
    if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
    return res.json({ categoria: rows[0] });
  } catch (err) {
    if (esNombreRepetido(err)) return res.status(409).json(NOMBRE_REPETIDO);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// DELETE /categorias/:id — borra una categoria.
//
// NO borra ninguna pieza: objetos.categoria_id tiene ON DELETE SET NULL, asi
// que las piezas que la tenian quedan sin clasificar y siguen ahi. Es lo
// correcto —una categoria es una forma de ordenar, no el acervo— pero es justo
// lo que sorprende, por eso se devuelve cuantas quedaron sueltas y la app lo
// avisa antes de confirmar.
//
// La cuenta se toma ANTES de borrar y en la misma sentencia: despues del
// DELETE la relacion ya no existe y seria imposible saber cuantas eran.
categoriasRouter.delete('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { rows } = await pool.query(
    `WITH antes AS (
       SELECT count(*)::int AS piezas FROM objetos WHERE categoria_id = $1
     ), borrada AS (
       DELETE FROM categorias WHERE id = $1 RETURNING id
     )
     SELECT (SELECT count(*) FROM borrada)::int AS borradas,
            (SELECT piezas FROM antes) AS sin_clasificar`,
    [req.params.id]
  );
  if (rows[0].borradas === 0) return res.status(404).json(NO_ENCONTRADA);
  return res.json({ sin_clasificar: rows[0].sin_clasificar });
});

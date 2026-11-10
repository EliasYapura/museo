import { Router } from 'express';
import { pool } from '../db.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';

export const categoriasRouter = Router();

categoriasRouter.use(verificarToken, requerirRol('administrador'));

// GET /categorias — las categorias con las que se clasifican los objetos
// (ADM23), con cuantas piezas tiene cada una.
//
// Es solo de lectura, igual que las salas: las categorias se cargan en la base
// y el backlog pide clasificar y filtrar, no administrarlas. La consecuencia
// es que sumar una disciplina nueva pasa por la base; si eso llega a molestar,
// es una historia aparte.
//
// La cuenta sirve para dos cosas en el panel: no ofrecer en el filtro
// categorias que no tienen ninguna pieza, y mostrar de un vistazo como esta
// repartido el acervo.
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

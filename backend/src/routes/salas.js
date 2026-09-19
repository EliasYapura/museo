import { Router } from 'express';
import { pool } from '../db.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';

export const salasRouter = Router();

salasRouter.use(verificarToken, requerirRol('administrador'));

// GET /salas — lista las salas en el orden del recorrido, para elegir en que
// sala esta un objeto (ADM15). Es solo de lectura: las salas se cargan en la
// base y el backlog no incluye administrarlas desde el panel.
salasRouter.get('/', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT id, nombre, nivel FROM salas ORDER BY orden_recorrido, id`
  );
  return res.json({ salas: rows });
});

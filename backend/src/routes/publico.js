import { Router } from 'express';
import { pool } from '../db.js';

// Rutas que consume la app del visitante (VIS01). No piden token: el catalogo
// de misiones del museo es publico, como un cartel en la entrada.
//
// Van en un router propio y no dentro de /misiones porque aquel exige
// administrador en todas sus rutas: colgar aca una ruta sin token evita que
// un cambio futuro en ese router se lleve puesta la seguridad, o al reves,
// que alguien agregue una ruta de administracion y quede abierta.
export const publicoRouter = Router();

// GET /publico/misiones — las misiones que el visitante puede jugar.
//
// Solo las publicadas (activa) y no archivadas. No devuelve nada de
// administracion: ni las respuestas correctas, ni quien la creo, ni los
// desafios en si.
//
// Los datos calculados salen de subconsultas en vez de JOIN con GROUP BY:
// con un JOIN habria que agrupar por todas las columnas de la mision y el
// conteo se mezclaria con la suma de puntos.
publicoRouter.get('/misiones', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT m.id, m.nombre, m.descripcion, m.imagen_url, m.dificultad,
            m.duracion_estimada,
            (SELECT count(*) FROM desafios d WHERE d.mision_id = m.id)::int AS desafios,
            (SELECT COALESCE(sum(d.puntos), 0) FROM desafios d WHERE d.mision_id = m.id)::int AS puntos,
            -- Donde empieza el recorrido: la sala del objeto del primer
            -- desafio que tenga uno. Puede no haber ninguno, y entonces
            -- queda en null.
            (SELECT s.nombre
             FROM desafios d
             JOIN objetos o ON o.id = d.objeto_id
             JOIN salas s ON s.id = o.sala_id
             WHERE d.mision_id = m.id
             ORDER BY d.orden, d.id
             LIMIT 1) AS sala
     FROM misiones m
     WHERE m.activa = TRUE AND m.archivada = FALSE
     ORDER BY m.id`
  );
  return res.json({ misiones: rows });
});

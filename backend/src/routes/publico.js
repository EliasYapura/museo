import { Router } from 'express';
import { pool } from '../db.js';
import { esIdValido } from '../validaciones/id.js';

// Rutas que consume la app del visitante (VIS01, VIS03). No piden token: el
// catalogo de misiones del museo es publico, como un cartel en la entrada.
//
// Van en un router propio y no dentro de /misiones porque aquel exige
// administrador en todas sus rutas: colgar aca una ruta sin token evita que
// un cambio futuro en ese router se lleve puesta la seguridad, o al reves,
// que alguien agregue una ruta de administracion y quede abierta.
export const publicoRouter = Router();

// Lo que la app necesita de una mision. Nada de administracion: ni las
// respuestas correctas, ni quien la creo, ni los desafios en si.
//
// Los datos calculados salen de subconsultas en vez de JOIN con GROUP BY:
// con un JOIN habria que agrupar por todas las columnas de la mision y el
// conteo se mezclaria con la suma de puntos.
const COLUMNAS = `m.id, m.nombre, m.descripcion, m.imagen_url, m.dificultad,
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
                   LIMIT 1) AS sala`;

// Salas por las que pasa la mision, sin repetir y en el orden del recorrido
// del museo. Va solo en el detalle: en el listado no se usa y seria una
// consulta por cada mision.
const SALAS = `(SELECT COALESCE(json_agg(nombre ORDER BY orden), '[]'::json)
                FROM (SELECT DISTINCT s.nombre, s.orden_recorrido AS orden
                      FROM desafios d
                      JOIN objetos o ON o.id = d.objeto_id
                      JOIN salas s ON s.id = o.sala_id
                      WHERE d.mision_id = m.id) AS recorrido) AS salas`;

// Una mision despublicada o archivada no esta "rota": simplemente dejo de
// ofrecerse. El mensaje lo dice asi porque lo lee el visitante.
const NO_DISPONIBLE = { error: 'Esta misión ya no está disponible' };

// GET /publico/misiones — las misiones que el visitante puede jugar (VIS01).
publicoRouter.get('/misiones', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT ${COLUMNAS}
     FROM misiones m
     WHERE m.activa = TRUE AND m.archivada = FALSE
     ORDER BY m.id`
  );
  return res.json({ misiones: rows });
});

// GET /publico/misiones/:id — el detalle, para decidir si empezarla (VIS03).
//
// Mismo filtro que el listado: si el administrador la bajo, no se abre ni con
// el enlace directo. No incluye los desafios; eso es VIS04, y mandarlos aca
// seria adelantarle los enunciados al visitante antes de llegar a la pieza.
publicoRouter.get('/misiones/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_DISPONIBLE);

  const { rows } = await pool.query(
    `SELECT ${COLUMNAS}, ${SALAS}
     FROM misiones m
     WHERE m.id = $1 AND m.activa = TRUE AND m.archivada = FALSE`,
    [req.params.id]
  );
  if (!rows[0]) return res.status(404).json(NO_DISPONIBLE);
  return res.json({ mision: rows[0] });
});

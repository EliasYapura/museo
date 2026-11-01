import { Router } from 'express';
import { pool } from '../db.js';
import { responderSiEsErrorDeDatos } from '../erroresDeDatos.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { esIdValido } from '../validaciones/id.js';
import { validarInsignia } from '../validaciones/insignia.js';

// Insignias del museo (ADM19).
//
// Un solo router, a diferencia de los desafios o las pistas: una insignia no
// cuelga de ninguna mision ni de ningun desafio, existe por si misma.
export const insigniasRouter = Router();

// Todas las rutas de insignias son solo para administradores. El visitante ve
// las que gano por otra ruta, en VIS10.
insigniasRouter.use(verificarToken, requerirRol('administrador'));

// obtenida_por es a cuantos visitantes ya se les otorgo. Importa antes de
// borrar: la base borra en cascada, asi que borrar una insignia se la saca a
// todos los que la ganaron, y eso hay que poder decirlo con un numero.
// count() da bigint, que node-pg entrega como texto; el ::int lo vuelve numero.
const COLUMNAS = `i.id, i.nombre, i.descripcion, i.icono_url, i.condicion, i.activa,
                  (SELECT count(*) FROM usuarios_insignias ui
                    WHERE ui.insignia_id = i.id)::int AS obtenida_por`;

const NO_ENCONTRADA = { error: 'La insignia no existe' };
const NOMBRE_REPETIDO = {
  error: 'Datos inválidos',
  errores: { nombre: 'Ya existe una insignia con ese nombre' },
};

// La base avisa con este error cuando el nombre ya esta tomado.
const esNombreRepetido = (err) => err.code === '23505' && err.constraint === 'insignias_nombre_key';

// GET /insignias — todas, activas y desactivadas, en orden alfabetico.
insigniasRouter.get('/', async (req, res) => {
  const { rows } = await pool.query(`SELECT ${COLUMNAS} FROM insignias i ORDER BY i.nombre, i.id`);
  return res.json({ insignias: rows });
});

// GET /insignias/:id — una insignia, para precargar el formulario.
insigniasRouter.get('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { rows } = await pool.query(`SELECT ${COLUMNAS} FROM insignias i WHERE i.id = $1`, [
    req.params.id,
  ]);
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
  return res.json({ insignia: rows[0] });
});

// POST /insignias — crea una insignia (ADM19).
//
// Nace con la condicion vacia: una insignia que nadie puede ganar todavia.
// Es a proposito, y es mas seguro que inventarle una regla por defecto que
// despues empiece a otorgar insignias que el museo no queria dar. La regla se
// carga aparte, en ADM20.
insigniasRouter.post('/', async (req, res) => {
  const { valores, errores } = validarInsignia(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    const { rows } = await pool.query(
      `WITH nueva AS (
         INSERT INTO insignias (nombre, descripcion, icono_url, condicion)
         VALUES ($1, $2, $3, '{}'::jsonb)
         RETURNING *
       )
       SELECT ${COLUMNAS} FROM nueva i`,
      [valores.nombre, valores.descripcion, valores.icono_url]
    );
    return res.status(201).json({ insignia: rows[0] });
  } catch (err) {
    if (esNombreRepetido(err)) return res.status(400).json(NOMBRE_REPETIDO);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PUT /insignias/:id — cambia nombre, descripcion e icono.
//
// No toca ni la condicion ni si esta activa: las dos tienen su propia ruta,
// para que guardar el formulario no cambie sin querer quien puede ganarla.
insigniasRouter.put('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { valores, errores } = validarInsignia(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    const { rows } = await pool.query(
      `WITH cambiada AS (
         UPDATE insignias
         SET nombre = $2, descripcion = $3, icono_url = $4
         WHERE id = $1
         RETURNING *
       )
       SELECT ${COLUMNAS} FROM cambiada i`,
      [req.params.id, valores.nombre, valores.descripcion, valores.icono_url]
    );
    if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
    return res.json({ insignia: rows[0] });
  } catch (err) {
    if (esNombreRepetido(err)) return res.status(400).json(NOMBRE_REPETIDO);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PATCH /insignias/:id/activa — habilita o deshabilita la insignia.
//
// Desactivarla deja de otorgarla sin tocar a nadie que ya la tenga. Es lo que
// se quiere casi siempre: frenar una insignia mal pensada no deberia castigar
// al visitante que la gano cuando valia.
insigniasRouter.patch('/:id/activa', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const activa = req.body?.activa;
  if (typeof activa !== 'boolean') {
    return res.status(400).json({ error: 'Hay que indicar si la insignia queda activa (true) o no (false)' });
  }

  const { rows } = await pool.query(
    `WITH cambiada AS (
       UPDATE insignias SET activa = $2 WHERE id = $1 RETURNING *
     )
     SELECT ${COLUMNAS} FROM cambiada i`,
    [req.params.id, activa]
  );
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
  return res.json({ insignia: rows[0] });
});

// DELETE /insignias/:id — la borra de verdad.
//
// Ojo con esto: usuarios_insignias referencia a insignias ON DELETE CASCADE,
// asi que borrarla SE LA QUITA a todos los visitantes que la hayan ganado. No
// se puede evitar desde aca sin cambiar el esquema, asi que la respuesta
// devuelve a cuantos se la sacó, y el panel avisa con ese numero antes.
//
// Para dejar de otorgar una insignia sin quitarsela a nadie esta PATCH
// /:id/activa, que es lo que conviene en casi todos los casos.
insigniasRouter.delete('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { rows } = await pool.query(
    `WITH tenian AS (
       SELECT count(*)::int AS cantidad FROM usuarios_insignias WHERE insignia_id = $1
     ), borrada AS (
       DELETE FROM insignias WHERE id = $1 RETURNING id
     )
     SELECT (SELECT cantidad FROM tenian) AS la_tenian,
            (SELECT count(*) FROM borrada) AS borradas`,
    [req.params.id]
  );
  if (Number(rows[0].borradas) === 0) return res.status(404).json(NO_ENCONTRADA);
  return res.json({ la_tenian: rows[0].la_tenian });
});

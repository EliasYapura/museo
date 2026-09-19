import { Router } from 'express';
import { pool } from '../db.js';
import { responderSiEsErrorDeDatos } from '../erroresDeDatos.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { esIdValido } from '../validaciones/id.js';
import { validarMision } from '../validaciones/mision.js';

export const misionesRouter = Router();

// Todas las rutas de misiones son solo para administradores.
misionesRouter.use(verificarToken, requerirRol('administrador'));

// Columnas que se devuelven al consultar, crear o editar una mision.
const COLUMNAS = `id, nombre, descripcion, duracion_estimada, imagen_url, dificultad,
                  activa, creada_por, creada_en, actualizada_en`;

const NO_ENCONTRADA = { error: 'La misión no existe' };

// GET /misiones — lista las misiones para el panel.
// Las archivadas no se muestran (baja logica, ADM07). Primero las modificadas
// mas recientemente, que suelen ser en las que se esta trabajando.
misionesRouter.get('/', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT id, nombre, duracion_estimada, dificultad, activa, creada_en, actualizada_en
     FROM misiones
     WHERE archivada = FALSE
     ORDER BY actualizada_en DESC, id DESC`
  );
  return res.json({ misiones: rows });
});

// GET /misiones/:id — datos de una mision, para precargar la edicion (ADM05).
misionesRouter.get('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { rows } = await pool.query(
    `SELECT ${COLUMNAS} FROM misiones WHERE id = $1 AND archivada = FALSE`,
    [req.params.id]
  );
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
  return res.json({ mision: rows[0] });
});

// POST /misiones — crea una mision (ADM01, ADM02).
misionesRouter.post('/', async (req, res) => {
  const { valores, errores } = validarMision(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    // Se guardan solo los campos validados. Todo lo demas que venga en el
    // cuerpo se ignora:
    // - activa no se inserta, asi la base aplica su valor por defecto (FALSE)
    //   y ninguna mision nace publicada, aunque el cuerpo diga lo contrario.
    // - creada_por sale del token y no del cuerpo, para que nadie pueda
    //   atribuirle la creacion de una mision a otra persona.
    const { rows } = await pool.query(
      `INSERT INTO misiones (nombre, descripcion, duracion_estimada, imagen_url, creada_por)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING ${COLUMNAS}`,
      [valores.nombre, valores.descripcion, valores.duracion_estimada, valores.imagen_url, req.usuario.id]
    );
    return res.status(201).json({ mision: rows[0] });
  } catch (err) {
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PUT /misiones/:id — modifica una mision existente (ADM05).
misionesRouter.put('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  // Mismas reglas que al crear: vienen del mismo modulo.
  const { valores, errores } = validarMision(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    // Solo se modifican los datos de la mision. activa, creada_por y los
    // desafios asociados no se tocan: el UPDATE es sobre esta fila de la tabla
    // misiones y nada mas, asi que los desafios quedan exactamente como estaban.
    //
    // La condicion IS DISTINCT FROM hace que la fila solo se actualice si algun
    // dato cambio de verdad. Sin ella, guardar sin cambios dispararia el
    // trigger y la "ultima modificacion" mostraria una fecha en la que no se
    // modifico nada. Se usa IS DISTINCT FROM y no <> porque compara bien los
    // NULL: NULL <> NULL da NULL, no FALSE.
    const { rows } = await pool.query(
      `UPDATE misiones
       SET nombre = $2, descripcion = $3, duracion_estimada = $4, imagen_url = $5
       WHERE id = $1 AND archivada = FALSE
         AND (nombre IS DISTINCT FROM $2
              OR descripcion IS DISTINCT FROM $3
              OR duracion_estimada IS DISTINCT FROM $4
              OR imagen_url IS DISTINCT FROM $5)
       RETURNING ${COLUMNAS}`,
      [req.params.id, valores.nombre, valores.descripcion, valores.duracion_estimada, valores.imagen_url]
    );
    if (rows[0]) return res.json({ mision: rows[0], modificada: true });

    // Ninguna fila actualizada: o la mision no existe, o no habia cambios.
    const existente = await pool.query(
      `SELECT ${COLUMNAS} FROM misiones WHERE id = $1 AND archivada = FALSE`,
      [req.params.id]
    );
    if (!existente.rows[0]) return res.status(404).json(NO_ENCONTRADA);
    return res.json({ mision: existente.rows[0], modificada: false });
  } catch (err) {
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

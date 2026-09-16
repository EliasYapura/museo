import { Router } from 'express';
import { pool } from '../db.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { validarMision } from '../validaciones/mision.js';

export const misionesRouter = Router();

// Codigos de error de PostgreSQL que indican datos invalidos. La validacion de
// arriba deberia atajarlos antes; esto es la ultima red por si una regla de la
// base y una de la API llegaran a diferir. Sin esta traduccion llegarian al
// manejador general como error 500, que significa "fallo el servidor".
const ERRORES_DE_DATOS = {
  '23502': 'Falta un dato obligatorio', // not_null_violation
  '23514': 'Algún dato está fuera del rango permitido', // check_violation
  '22P02': 'Algún dato tiene un formato inválido', // invalid_text_representation
  '22003': 'Algún número es demasiado grande', // numeric_value_out_of_range
  '22001': 'Algún texto es demasiado largo', // string_data_right_truncation
};

// GET /misiones — lista las misiones para el panel. Solo administradores.
// Las archivadas no se muestran (baja logica, ADM07). Primero las modificadas
// mas recientemente, que suelen ser en las que se esta trabajando.
misionesRouter.get('/', verificarToken, requerirRol('administrador'), async (req, res) => {
  const { rows } = await pool.query(
    `SELECT id, nombre, duracion_estimada, dificultad, activa, creada_en, actualizada_en
     FROM misiones
     WHERE archivada = FALSE
     ORDER BY actualizada_en DESC, id DESC`
  );
  return res.json({ misiones: rows });
});

// POST /misiones — crea una mision. Solo administradores.
misionesRouter.post('/', verificarToken, requerirRol('administrador'), async (req, res) => {
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
       RETURNING id, nombre, descripcion, duracion_estimada, imagen_url,
                 dificultad, activa, creada_por, creada_en, actualizada_en`,
      [valores.nombre, valores.descripcion, valores.duracion_estimada, valores.imagen_url, req.usuario.id]
    );
    return res.status(201).json({ mision: rows[0] });
  } catch (err) {
    if (ERRORES_DE_DATOS[err.code]) {
      return res.status(400).json({ error: ERRORES_DE_DATOS[err.code] });
    }
    throw err;
  }
});

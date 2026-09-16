import { Router } from 'express';
import { pool } from '../db.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';

export const misionesRouter = Router();

// Codigos de error de PostgreSQL que indican datos invalidos enviados por el
// cliente. Sin esta traduccion llegarian al manejador general como error 500,
// que significa "fallo el servidor", cuando en realidad fallo la peticion.
const ERRORES_DE_DATOS = {
  '23502': 'Falta un dato obligatorio', // not_null_violation
  '23514': 'Algún dato está fuera del rango permitido', // check_violation
  '22P02': 'Algún dato tiene un formato inválido', // invalid_text_representation
  '22003': 'Algún número es demasiado grande', // numeric_value_out_of_range
  '22001': 'Algún texto es demasiado largo', // string_data_right_truncation
};

// La imagen es opcional: un campo ausente o vacio se guarda como NULL.
// Si viene, solo se aceptan direcciones http o https. Un esquema como
// "javascript:" guardado en la base podria ejecutar codigo en el navegador
// de quien abra la mision, si algun dia se usa la direccion como enlace.
function normalizarImagen(valor) {
  if (valor === undefined || valor === null) return { url: null };
  if (typeof valor !== 'string') return { error: true };

  const texto = valor.trim();
  if (texto === '') return { url: null };

  try {
    const url = new URL(texto);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return { error: true };
    return { url: texto };
  } catch {
    return { error: true };
  }
}

// POST /misiones — crea una mision. Solo administradores.
misionesRouter.post('/', verificarToken, requerirRol('administrador'), async (req, res) => {
  const { nombre, descripcion, duracion_estimada, imagen_url } = req.body ?? {};

  const imagen = normalizarImagen(imagen_url);
  if (imagen.error) {
    return res.status(400).json({ error: 'La imagen de portada debe ser una dirección http o https' });
  }

  try {
    // Se eligen campo por campo los datos que se guardan. Todo lo demas que
    // venga en el cuerpo se ignora:
    // - activa no se inserta, asi la base aplica su valor por defecto (FALSE)
    //   y ninguna mision nace publicada, aunque el cuerpo diga lo contrario.
    // - creada_por sale del token y no del cuerpo, para que nadie pueda
    //   atribuirle la creacion de una mision a otra persona.
    const { rows } = await pool.query(
      `INSERT INTO misiones (nombre, descripcion, duracion_estimada, imagen_url, creada_por)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, nombre, descripcion, duracion_estimada, imagen_url,
                 dificultad, activa, creada_por, creada_en, actualizada_en`,
      [nombre, descripcion, duracion_estimada, imagen.url, req.usuario.id]
    );
    return res.status(201).json({ mision: rows[0] });
  } catch (err) {
    if (ERRORES_DE_DATOS[err.code]) {
      return res.status(400).json({ error: ERRORES_DE_DATOS[err.code] });
    }
    throw err;
  }
});

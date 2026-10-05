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
// desafios es cuantos tiene: una mision sin desafios no se puede publicar
// (ADM04), asi que el panel necesita el dato en cada respuesta para saber si
// el boton va habilitado. count() da bigint, que node-pg entrega como texto.
const CUENTA_DESAFIOS =
  '(SELECT count(*) FROM desafios d WHERE d.mision_id = misiones.id)::int AS desafios';
const COLUMNAS = `id, nombre, descripcion, duracion_estimada, imagen_url, dificultad,
                  activa, creada_por, creada_en, actualizada_en, ${CUENTA_DESAFIOS}`;

const NO_ENCONTRADA = { error: 'La misión no existe' };

// GET /misiones — lista las misiones para el panel.
// Las archivadas no se muestran (baja logica, ADM07). Primero las modificadas
// mas recientemente, que suelen ser en las que se esta trabajando.
misionesRouter.get('/', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT id, nombre, duracion_estimada, dificultad, activa, creada_en, actualizada_en,
            ${CUENTA_DESAFIOS}
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
      `INSERT INTO misiones (nombre, descripcion, duracion_estimada, imagen_url, dificultad, creada_por)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING ${COLUMNAS}`,
      [
        valores.nombre,
        valores.descripcion,
        valores.duracion_estimada,
        valores.imagen_url,
        valores.dificultad,
        req.usuario.id,
      ]
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
       SET nombre = $2, descripcion = $3, duracion_estimada = $4, imagen_url = $5,
           dificultad = $6
       WHERE id = $1 AND archivada = FALSE
         AND (nombre IS DISTINCT FROM $2
              OR descripcion IS DISTINCT FROM $3
              OR duracion_estimada IS DISTINCT FROM $4
              OR imagen_url IS DISTINCT FROM $5
              OR dificultad IS DISTINCT FROM $6)
       RETURNING ${COLUMNAS}`,
      [
        req.params.id,
        valores.nombre,
        valores.descripcion,
        valores.duracion_estimada,
        valores.imagen_url,
        valores.dificultad,
      ]
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

// PATCH /misiones/:id/archivada — archiva una mision o la devuelve al
// listado (ADM07).
//
// PATCH /misiones/:id/activa — publica o despublica la mision (ADM04).
//
// Publicada quiere decir que los visitantes la ven en la app. Va en su propia
// ruta, igual que archivada, para que guardar el formulario de la mision no
// la publique sin querer.
misionesRouter.patch('/:id/activa', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const activa = req.body?.activa;
  if (typeof activa !== 'boolean') {
    return res.status(400).json({ error: 'Hay que indicar si la misión se publica (true) o no (false)' });
  }

  // Una mision sin desafios se puede empezar pero no tiene nada para resolver.
  // La condicion va en el propio UPDATE y no en una consulta aparte: entre el
  // SELECT y el UPDATE alguien podria borrar el ultimo desafio.
  // Despublicar nunca se condiciona: si algo sale mal durante una visita,
  // bajarla tiene que funcionar siempre.
  const { rows } = await pool.query(
    `UPDATE misiones
     SET activa = $2
     WHERE id = $1 AND archivada = FALSE
       AND (NOT $2 OR EXISTS (SELECT 1 FROM desafios d WHERE d.mision_id = misiones.id))
     RETURNING ${COLUMNAS}`,
    [req.params.id, activa]
  );
  if (rows[0]) return res.json({ mision: rows[0] });

  // No se actualizo nada: o la mision no esta, o se quiso publicar una vacia.
  const existente = await pool.query(
    `SELECT ${COLUMNAS} FROM misiones WHERE id = $1 AND archivada = FALSE`,
    [req.params.id]
  );
  if (!existente.rows[0]) return res.status(404).json(NO_ENCONTRADA);
  return res.status(409).json({
    error: 'Una misión sin desafíos no se puede publicar. Agregale al menos uno.',
    mision: existente.rows[0],
  });
});

// Es una baja logica: la mision deja de verse en el panel, pero sus desafios,
// sus recompensas y el avance de los visitantes siguen en la base. Borrarla
// de verdad se los llevaria a todos por delante.
//
// Va en una ruta aparte y no en el PUT para que no se archive sin querer al
// guardar el formulario. Archivar tambien desactiva: una mision archivada no
// puede quedar publicada para los visitantes.
misionesRouter.patch('/:id/archivada', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const archivada = req.body?.archivada;
  if (typeof archivada !== 'boolean') {
    return res.status(400).json({ error: 'Hay que indicar si la misión se archiva (true) o no (false)' });
  }

  // Sin el filtro de archivada en el WHERE: es la unica ruta que tambien
  // tiene que poder tocar una mision ya archivada, para devolverla al listado.
  const { rows } = await pool.query(
    `UPDATE misiones
     SET archivada = $2,
         activa = CASE WHEN $2 THEN FALSE ELSE activa END
     WHERE id = $1
     RETURNING ${COLUMNAS}, archivada`,
    [req.params.id, archivada]
  );
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
  return res.json({ mision: rows[0] });
});

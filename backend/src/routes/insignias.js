import { Router } from 'express';
import { borrarImagen, BUCKET_INSIGNIAS, ErrorDeImagen, subirImagen } from '../almacenamiento.js';
import { pool } from '../db.js';
import { responderSiEsErrorDeDatos } from '../erroresDeDatos.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { esIdValido } from '../validaciones/id.js';
import { validarCondicion } from '../validaciones/condicion.js';
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
         INSERT INTO insignias (nombre, descripcion, condicion)
         VALUES ($1, $2, '{}'::jsonb)
         RETURNING *
       )
       SELECT ${COLUMNAS} FROM nueva i`,
      [valores.nombre, valores.descripcion]
    );
    return res.status(201).json({ insignia: rows[0] });
  } catch (err) {
    if (esNombreRepetido(err)) return res.status(400).json(NOMBRE_REPETIDO);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PUT /insignias/:id — cambia el nombre y la descripcion.
//
// No toca la condicion, ni si esta activa, ni el icono: los tres tienen su
// propia ruta, para que guardar el formulario no cambie sin querer quien puede
// ganarla ni le borre la imagen.
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
         SET nombre = $2, descripcion = $3
         WHERE id = $1
         RETURNING *
       )
       SELECT ${COLUMNAS} FROM cambiada i`,
      [req.params.id, valores.nombre, valores.descripcion]
    );
    if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
    return res.json({ insignia: rows[0] });
  } catch (err) {
    if (esNombreRepetido(err)) return res.status(400).json(NOMBRE_REPETIDO);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PUT /insignias/:id/condicion — define como se gana la insignia (ADM20).
//
// En su propia ruta por lo mismo que "activa": guardar un cambio de nombre no
// tiene que alterar quien puede ganarla.
//
// Sin tipo la condicion queda vacia y la insignia vuelve a no poder ganarse.
// Eso no es lo mismo que desactivarla: sin condicion es "todavia no decidi
// como se gana", desactivada es "ya lo decidi, pero no la quiero otorgar".
insigniasRouter.put('/:id/condicion', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { valor, errores } = await validarCondicion(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  const { rows } = await pool.query(
    `WITH cambiada AS (
       UPDATE insignias SET condicion = $2::jsonb WHERE id = $1 RETURNING *
     )
     SELECT ${COLUMNAS} FROM cambiada i`,
    [req.params.id, JSON.stringify(valor)]
  );
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);
  return res.json({ insignia: rows[0] });
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

// --- Icono de la insignia (ADM25) -----------------------------------------
//
// El archivo llega crudo en el cuerpo, con su Content-Type, y no como
// multipart. Es una sola imagen y nada mas: armar un multipart para eso
// obligaria a sumar una dependencia que parsee algo que no necesitamos.
//
// Importante: el Content-Type que manda el cliente NO decide nada. Sirve para
// que express.raw acepte el cuerpo; el tipo real lo reconoce almacenamiento.js
// mirando los primeros bytes.

// POST /insignias/:id/icono — reemplaza la imagen de la insignia.
insigniasRouter.post('/:id/icono', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    return res.status(400).json({
      error: 'Datos inválidos',
      errores: { icono: 'No llegó ninguna imagen' },
    });
  }

  // Se busca antes de subir para no dejar un archivo huérfano en Storage si
  // la insignia no existe, y para quedarse con el ícono viejo y poder
  // borrarlo después.
  const previa = await pool.query('SELECT icono_url FROM insignias WHERE id = $1', [req.params.id]);
  if (!previa.rows[0]) return res.status(404).json(NO_ENCONTRADA);

  let url;
  try {
    url = await subirImagen(req.body, BUCKET_INSIGNIAS);
  } catch (err) {
    if (err instanceof ErrorDeImagen) {
      return res.status(400).json({ error: 'Datos inválidos', errores: { icono: err.message } });
    }
    throw err;
  }

  const { rows } = await pool.query(
    `WITH cambiada AS (
       UPDATE insignias SET icono_url = $2 WHERE id = $1 RETURNING *
     )
     SELECT ${COLUMNAS} FROM cambiada i`,
    [req.params.id, url]
  );

  // Recién cuando la nueva quedó guardada se borra la anterior. Al revés, un
  // fallo entre medio dejaría la insignia apuntando a un archivo que ya no
  // está. borrarImagen no lanza: es limpieza, no parte de la operación.
  await borrarImagen(previa.rows[0].icono_url, BUCKET_INSIGNIAS);

  return res.json({ insignia: rows[0] });
});

// DELETE /insignias/:id/icono — le saca la imagen y vuelve al ícono genérico.
insigniasRouter.delete('/:id/icono', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  // La consulta devuelve la insignia ya sin ícono, y aparte la dirección que
  // tenía: sin guardarla, el archivo quedaría para siempre en el bucket sin
  // que nada lo apunte.
  const { rows } = await pool.query(
    `WITH previa AS (
       SELECT icono_url FROM insignias WHERE id = $1
     ), cambiada AS (
       UPDATE insignias SET icono_url = NULL WHERE id = $1 RETURNING *
     )
     SELECT ${COLUMNAS}, (SELECT icono_url FROM previa) AS icono_anterior
     FROM cambiada i`,
    [req.params.id]
  );
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADA);

  const { icono_anterior: anterior, ...insignia } = rows[0];
  await borrarImagen(anterior, BUCKET_INSIGNIAS);

  return res.json({ insignia });
});

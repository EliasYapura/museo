import { Router } from 'express';
import { borrarImagen, BUCKET_MISIONES, ErrorDeImagen, subirImagen } from '../almacenamiento.js';
import { pool } from '../db.js';
import { recalcularDificultad } from '../dificultad.js';
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

// Lo que opinaron los visitantes (ADM26). Van por subconsulta como la cuenta
// de desafios, y no con un JOIN: con JOIN habria que agrupar por todas las
// columnas de la mision, y el promedio se mezclaria con el conteo de desafios.
//
// avg() devuelve numeric, que node-pg entrega como texto para no perder
// precision; el ::float8 lo vuelve un numero en el JSON. Sin valoraciones da
// NULL, que es lo correcto: cero seria "la calificaron mal", y no es lo mismo
// que "todavia no la califico nadie".
const VALORACIONES = `(SELECT count(*) FROM valoraciones v WHERE v.mision_id = misiones.id)::int
                        AS valoraciones,
                      (SELECT round(avg(v.puntuacion), 2) FROM valoraciones v
                        WHERE v.mision_id = misiones.id)::float8 AS valoracion_promedio`;

const COLUMNAS = `id, nombre, descripcion, duracion_estimada, imagen_url, dificultad,
                  activa, creada_por, creada_en, actualizada_en, ${CUENTA_DESAFIOS},
                  ${VALORACIONES}`;

const NO_ENCONTRADA = { error: 'La misión no existe' };

// GET /misiones — lista las misiones para el panel.
// Las archivadas no se muestran (baja logica, ADM07). Primero las modificadas
// mas recientemente, que suelen ser en las que se esta trabajando.
misionesRouter.get('/', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT id, nombre, duracion_estimada, dificultad, activa, creada_en, actualizada_en,
            ${CUENTA_DESAFIOS}, ${VALORACIONES}
     FROM misiones
     WHERE archivada = FALSE
     ORDER BY actualizada_en DESC, id DESC`
  );
  return res.json({ misiones: rows });
});

// Como se reparten las estrellas (ADM26): cuantos pusieron 1, cuantos 2, y asi
// hasta 5. Solo va en el detalle; en el listado alcanza con el promedio.
//
// Un promedio de 3 no significa lo mismo si todos pusieron 3 que si la mitad
// puso 5 y la otra mitad 1, y esa diferencia es la que dice si hay que revisar
// la mision.
//
// Sale de generate_series y no de un GROUP BY para que siempre vengan los
// cinco numeros en orden: con GROUP BY faltarian las estrellas que nadie
// eligio y la app tendria que completar los huecos.
const REPARTO = `(SELECT jsonb_agg(c.cuantas ORDER BY c.estrella)
                    FROM (SELECT e.estrella,
                                 (SELECT count(*)::int FROM valoraciones v
                                   WHERE v.mision_id = misiones.id
                                     AND v.puntuacion = e.estrella) AS cuantas
                            FROM generate_series(1, 5) AS e(estrella)) c)
                  AS reparto_valoraciones`;

// GET /misiones/:id — datos de una mision, para precargar la edicion (ADM05).
misionesRouter.get('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  const { rows } = await pool.query(
    `SELECT ${COLUMNAS}, ${REPARTO} FROM misiones WHERE id = $1 AND archivada = FALSE`,
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
    // - imagen_url tampoco se inserta: la portada se sube aparte, en
    //   POST /misiones/:id/imagen (ADM25), que necesita la mision ya creada.
    const { rows } = await pool.query(
      `INSERT INTO misiones (nombre, descripcion, duracion_estimada, creada_por)
       VALUES ($1, $2, $3, $4)
       RETURNING ${COLUMNAS}`,
      [valores.nombre, valores.descripcion, valores.duracion_estimada, req.usuario.id]
    );
    // La dificultad la calcula el servidor (ADM03). Al insertar queda el valor
    // por defecto de la columna, asi que se recalcula enseguida y se corrige en
    // la respuesta: devolver el valor por defecto seria mentirle al formulario.
    rows[0].dificultad = await recalcularDificultad(rows[0].id, pool);
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
    // imagen_url tampoco se toca, y eso es a proposito (ADM25): la portada
    // tiene su propia ruta, y si se escribiera aca, guardar un cambio de
    // nombre la borraria —el formulario ya no manda la direccion—.
    //
    // La condicion IS DISTINCT FROM hace que la fila solo se actualice si algun
    // dato cambio de verdad. Sin ella, guardar sin cambios dispararia el
    // trigger y la "ultima modificacion" mostraria una fecha en la que no se
    // modifico nada. Se usa IS DISTINCT FROM y no <> porque compara bien los
    // NULL: NULL <> NULL da NULL, no FALSE.
    const { rows } = await pool.query(
      `UPDATE misiones
       SET nombre = $2, descripcion = $3, duracion_estimada = $4
       WHERE id = $1 AND archivada = FALSE
         AND (nombre IS DISTINCT FROM $2
              OR descripcion IS DISTINCT FROM $3
              OR duracion_estimada IS DISTINCT FROM $4)
       RETURNING ${COLUMNAS}`,
      [req.params.id, valores.nombre, valores.descripcion, valores.duracion_estimada]
    );
    // Cambiar la duracion cambia la dificultad (ADM03), asi que se recalcula.
    // Tambien cuando el editar no modifico nada: las misiones viejas traen una
    // dificultad puesta a mano, y esta es la ocasion de corregirla. El
    // recalculo solo escribe si el nivel cambia, asi que no mueve la fecha de
    // ultima modificacion por las suyas.
    if (rows[0]) {
      rows[0].dificultad = await recalcularDificultad(rows[0].id, pool);
      return res.json({ mision: rows[0], modificada: true });
    }

    // Ninguna fila actualizada: o la mision no existe, o no habia cambios.
    const existente = await pool.query(
      `SELECT ${COLUMNAS} FROM misiones WHERE id = $1 AND archivada = FALSE`,
      [req.params.id]
    );
    if (!existente.rows[0]) return res.status(404).json(NO_ENCONTRADA);
    existente.rows[0].dificultad = await recalcularDificultad(req.params.id, pool);
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

// --- Imagen de portada (ADM25) ---------------------------------------------
//
// Mismo mecanismo que el icono de una insignia (ADM25): el archivo llega crudo
// en el cuerpo con su Content-Type, y ese tipo no decide nada —sirve para que
// express.raw acepte el cuerpo, y el tipo real lo reconoce almacenamiento.js
// mirando los primeros bytes—.
//
// Va en su propia ruta y no en el PUT por lo mismo que activa o archivada:
// guardar el formulario no tiene que cambiar la portada, y subir una portada
// no tiene que poder tocar el nombre ni la duracion.

// POST /misiones/:id/imagen — reemplaza la portada de la mision.
misionesRouter.post('/:id/imagen', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    return res.status(400).json({
      error: 'Datos inválidos',
      errores: { imagen: 'No llegó ninguna imagen' },
    });
  }

  // Se consulta antes de subir para no dejar un archivo huerfano en Storage si
  // la mision no existe, y para quedarse con la portada vieja y poder borrarla.
  const previa = await pool.query(
    'SELECT imagen_url FROM misiones WHERE id = $1 AND archivada = FALSE',
    [req.params.id]
  );
  if (!previa.rows[0]) return res.status(404).json(NO_ENCONTRADA);

  let url;
  try {
    url = await subirImagen(req.body, BUCKET_MISIONES);
  } catch (err) {
    if (err instanceof ErrorDeImagen) {
      return res.status(400).json({ error: 'Datos inválidos', errores: { imagen: err.message } });
    }
    throw err;
  }

  // Sin IS DISTINCT FROM, a proposito: cada subida genera un nombre nuevo, asi
  // que la direccion siempre cambia. Y cambiar la portada ES modificar la
  // mision, por lo que mover la fecha del trigger es lo correcto.
  const { rows } = await pool.query(
    `UPDATE misiones SET imagen_url = $2
     WHERE id = $1 AND archivada = FALSE
     RETURNING ${COLUMNAS}`,
    [req.params.id, url]
  );

  // Recien cuando la nueva quedo guardada se borra la anterior. Al reves, un
  // fallo entre medio dejaria la mision apuntando a un archivo que ya no esta.
  // borrarImagen no lanza: es limpieza, no parte de la operacion.
  await borrarImagen(previa.rows[0].imagen_url, BUCKET_MISIONES);

  return res.json({ mision: rows[0] });
});

// DELETE /misiones/:id/imagen — le saca la portada y vuelve al icono tematico.
misionesRouter.delete('/:id/imagen', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADA);

  // Se lee la mision completa de entrada: hace falta la direccion anterior
  // para borrar el archivo, y si no habia ninguna esta misma fila es la
  // respuesta, sin tocar la base.
  const previa = await pool.query(
    `SELECT ${COLUMNAS} FROM misiones WHERE id = $1 AND archivada = FALSE`,
    [req.params.id]
  );
  if (!previa.rows[0]) return res.status(404).json(NO_ENCONTRADA);

  const anterior = previa.rows[0].imagen_url;
  // Ya no tiene portada: no se escribe nada. Sin esto, el UPDATE dispararia el
  // trigger y la "ultima modificacion" mostraria una fecha en la que no se
  // modifico nada.
  if (anterior === null) return res.json({ mision: previa.rows[0] });

  const { rows } = await pool.query(
    `UPDATE misiones SET imagen_url = NULL
     WHERE id = $1 AND archivada = FALSE
     RETURNING ${COLUMNAS}`,
    [req.params.id]
  );
  await borrarImagen(anterior, BUCKET_MISIONES);

  return res.json({ mision: rows[0] ?? previa.rows[0] });
});

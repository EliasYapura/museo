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

// Lo que la app necesita de cada desafio para jugarlo (VIS04).
//
// Lo que NO esta aca es la parte importante: ni respuesta_correcta ni la
// tolerancia con la que se compara. Comprobar una respuesta es trabajo del
// servidor; si esos datos viajaran al telefono, cualquiera podria abrir el
// APK y leer todas las respuestas de todas las misiones.
const COLUMNAS_DESAFIO = `d.id, d.orden, d.tipo, d.enunciado, d.puntos,
                  -- De la configuracion sale solo esto: las opciones se le
                  -- muestran al visitante igual, asi que no son un secreto.
                  COALESCE(d.configuracion -> 'opciones', '[]'::jsonb) AS opciones,
                  -- Hay pieza que buscar y escanear, sin decir cual es.
                  (d.objeto_id IS NOT NULL) AS requiere_escaneo,
                  -- En la busqueda guiada el nombre de la pieza no se manda:
                  -- el desafio consiste justamente en deducir cual es a partir
                  -- del enunciado, y nombrarla lo resolveria solo.
                  CASE WHEN d.tipo = 'busqueda_guiada' THEN NULL ELSE o.nombre END AS pieza,
                  -- La sala si, en todos los casos: es a donde hay que ir.
                  s.nombre AS sala`;

// GET /publico/misiones/:id/desafios — los desafios a jugar, en orden (VIS04).
//
// Mismo filtro que el detalle: una mision despublicada o archivada no se
// empieza ni con el enlace directo.
publicoRouter.get('/misiones/:id/desafios', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_DISPONIBLE);

  const mision = await pool.query(
    'SELECT 1 FROM misiones WHERE id = $1 AND activa = TRUE AND archivada = FALSE',
    [req.params.id]
  );
  if (!mision.rows[0]) return res.status(404).json(NO_DISPONIBLE);

  const { rows } = await pool.query(
    `SELECT ${COLUMNAS_DESAFIO}
     FROM desafios d
     LEFT JOIN objetos o ON o.id = d.objeto_id
     LEFT JOIN salas s ON s.id = o.sala_id
     WHERE d.mision_id = $1
     ORDER BY d.orden, d.id`,
    [req.params.id]
  );
  // Una mision publicada no puede estar vacia: la API no deja publicarla sin
  // desafios y la despublica sola si se borra el ultimo (ADM04). Si igual
  // llega vacia es que quedo asi entre dos pedidos, y abrir un recorrido sin
  // nada que resolver es peor que decir que no esta disponible.
  if (rows.length === 0) return res.status(404).json(NO_DISPONIBLE);

  return res.json({ desafios: rows });
});

// Tipos que se resuelven llegando a la pieza: no tienen nada que contestar,
// asi que un escaneo correcto los da por terminados. Los otros dos siguen con
// la pregunta (VIS06).
const TIPOS_SIN_PREGUNTA = ['escaneo_objeto', 'busqueda_guiada'];

const DESAFIO_NO_DISPONIBLE = { error: 'Este desafío ya no está disponible' };

// POST /publico/desafios/:id/escaneo — valida el codigo escaneado contra la
// pieza que el desafio espera (VIS05, SIS01).
//
// La comparacion se hace aca y no en la app por la misma razon que las
// respuestas: el codigo correcto no puede viajar al telefono, o alcanzaria
// con leerlo del APK para resolver la mision sin moverse del lugar.
publicoRouter.post('/desafios/:id/escaneo', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(DESAFIO_NO_DISPONIBLE);

  const { codigo } = req.body ?? {};
  if (typeof codigo !== 'string' || codigo.trim() === '') {
    return res.status(400).json({ error: 'El código escaneado no se entendió' });
  }

  // El JOIN con misiones no es decorativo: sin el, el id de un desafio suelto
  // dejaria jugar una mision que el museo despublico o archivo.
  const { rows } = await pool.query(
    `SELECT d.tipo, d.puntos, d.objeto_id, o.codigo, o.nombre AS pieza, o.dato_clave
       FROM desafios d
       JOIN misiones m ON m.id = d.mision_id
       LEFT JOIN objetos o ON o.id = d.objeto_id
      WHERE d.id = $1 AND m.activa = TRUE AND m.archivada = FALSE`,
    [req.params.id]
  );
  const desafio = rows[0];
  if (!desafio) return res.status(404).json(DESAFIO_NO_DISPONIBLE);
  if (desafio.objeto_id === null) {
    return res.status(409).json({ error: 'Este desafío no se resuelve escaneando' });
  }

  // Los codigos estan enteramente en mayusculas, tanto los que genera la API
  // (OBJ- mas ocho simbolos de un alfabeto en mayusculas) como los cargados a
  // mano en la base (MLP-OBJ-005). Por eso subir a mayusculas no puede hacer
  // que dos codigos distintos se confundan: no hay dos que difieran solo en
  // eso. Lo que si arregla es un lector que devuelva el texto en minusculas.
  const escaneado = codigo.trim().toUpperCase();
  if (escaneado !== desafio.codigo.toUpperCase()) {
    // No se dice que pieza escaneo. En la busqueda guiada, nombrarla seria
    // darle la respuesta que justamente tenia que deducir.
    return res.json({ correcto: false });
  }

  const sinPregunta = TIPOS_SIN_PREGUNTA.includes(desafio.tipo);
  return res.json({
    correcto: true,
    pieza: desafio.pieza,
    // Lo que el visitante se gana por llegar hasta la vitrina, y con lo que
    // despues responde la pregunta si el desafio tiene una.
    dato_clave: desafio.dato_clave,
    resuelto: sinPregunta,
    puntos: sinPregunta ? desafio.puntos : 0,
  });
});

// Tipos que ademas de la pieza tienen algo que contestar (VIS06).
const TIPOS_CON_PREGUNTA = ['pregunta_opcion_multiple', 'respuesta_corta'];

// Deja un texto listo para compararlo: sin espacios al principio ni al final,
// y sin espacios repetidos en el medio. Esto vale para las dos tolerancias:
// que alguien haya tecleado dos espacios seguidos no es un error de contenido,
// y la promesa de la comparacion exacta es sobre tildes y mayusculas.
const limpiar = (texto) => texto.trim().replace(/\s+/g, ' ');

// Saca las tildes. normalize('NFD') separa cada letra acentuada en la letra
// base mas la tilde como caracter aparte, y el reemplazo descarta esas tildes.
// Se hace aca y no en la base para no obligar al museo a instalar la extension
// unaccent de PostgreSQL solo por esto.
const sinTildes = (texto) => texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

// Como se compara lo que escribio el visitante. Las dos tolerancias hacen
// exactamente lo que el formulario del administrador promete:
//   exacta   -> "Tiene que escribirse igual, con tildes y mayusculas."
//   flexible -> "No distingue tildes ni mayusculas."
function coincide(escrita, correcta, tolerancia) {
  if (tolerancia === 'exacta') return limpiar(escrita) === limpiar(correcta);
  return sinTildes(limpiar(escrita).toLowerCase()) === sinTildes(limpiar(correcta).toLowerCase());
}

// POST /publico/desafios/:id/respuesta — comprueba la respuesta (VIS06).
//
// La respuesta correcta no sale de aca ni cuando el visitante se equivoca:
// solo se le dice si estuvo bien o mal.
publicoRouter.post('/desafios/:id/respuesta', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(DESAFIO_NO_DISPONIBLE);

  const { respuesta } = req.body ?? {};
  if (typeof respuesta !== 'string' || respuesta.trim() === '') {
    return res.status(400).json({ error: 'Escribí una respuesta' });
  }

  const { rows } = await pool.query(
    `SELECT d.tipo, d.puntos, d.respuesta_correcta, d.configuracion
       FROM desafios d
       JOIN misiones m ON m.id = d.mision_id
      WHERE d.id = $1 AND m.activa = TRUE AND m.archivada = FALSE`,
    [req.params.id]
  );
  const desafio = rows[0];
  if (!desafio) return res.status(404).json(DESAFIO_NO_DISPONIBLE);
  if (!TIPOS_CON_PREGUNTA.includes(desafio.tipo)) {
    return res.status(409).json({ error: 'Este desafío no se resuelve respondiendo' });
  }
  // Un desafio con pregunta siempre deberia tener respuesta cargada, pero si
  // alguna fila vieja no la tiene, es mejor decirlo que reprobar al visitante
  // por algo que no es culpa suya.
  if (desafio.respuesta_correcta === null) {
    return res.status(409).json({ error: 'Este desafío todavía no se puede responder' });
  }

  // En la opcion multiple la app devuelve el texto exacto de la opcion que
  // eligio, asi que no hay tolerancia que aplicar.
  const acerto =
    desafio.tipo === 'pregunta_opcion_multiple'
      ? limpiar(respuesta) === limpiar(desafio.respuesta_correcta)
      : coincide(respuesta, desafio.respuesta_correcta, desafio.configuracion?.tolerancia);

  return res.json({ correcto: acerto, puntos: acerto ? desafio.puntos : 0 });
});

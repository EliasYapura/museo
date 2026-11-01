import { Router } from 'express';
import { pool } from '../db.js';
import { EVENTOS, registrar } from '../eventos.js';
import { tokenOpcional } from '../middleware/auth.js';
import {
  abrirProgreso,
  completarProgreso,
  estadoDelProgreso,
  guardarIntento,
  guardarPistaUsada,
  pistasYaPagadas,
  progresoDelDesafio,
} from '../progreso.js';
import { esIdValido } from '../validaciones/id.js';

// Rutas que consume la app del visitante (VIS01, VIS03). No piden token: el
// catalogo de misiones del museo es publico, como un cartel en la entrada.
//
// Van en un router propio y no dentro de /misiones porque aquel exige
// administrador en todas sus rutas: colgar aca una ruta sin token evita que
// un cambio futuro en ese router se lleve puesta la seguridad, o al reves,
// que alguien agregue una ruta de administracion y quede abierta.
export const publicoRouter = Router();

// Ninguna ruta de aca exige token, pero si viene uno valido se aprovecha: es
// lo que distingue al visitante con cuenta, al que se le guarda el progreso
// (SIS03), del que recorre sin cuenta, que juega igual sin que se guarde nada.
publicoRouter.use(tokenOpcional);

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
                  s.nombre AS sala,
                  -- Lo que cuesta cada pista, en el orden en que se entregan
                  -- (VIS07). Viajan los numeros y no los textos: el precio hay
                  -- que mostrarlo antes de cobrarlo, pero la pista en si se
                  -- pide de a una. Ojo que en la administracion el campo
                  -- "pistas" es cuantas hay; aca es cuanto cuesta cada una.
                  COALESCE((SELECT json_agg(p.penalizacion ORDER BY p.orden, p.id)
                            FROM pistas p WHERE p.desafio_id = d.id), '[]'::json) AS pistas`;

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

  // Sin cuenta no hay donde guardar nada: se juega como siempre y la
  // respuesta no lleva progreso.
  if (!req.usuario) {
    // El id de la misión va en datos porque la tabla de eventos no tiene
    // columna propia para ella: tiene la del progreso, que estas sesiones
    // anónimas no crean.
    //
    // Si la app reintenta tras un error de red, la misión queda iniciada dos
    // veces. Es ruido tolerable en una bitácora, y al visitante con cuenta no
    // le pasa: ahí el reintento retoma el progreso que ya estaba.
    registrar({
      tipo: EVENTOS.MISION_INICIADA,
      datos: { mision_id: Number(req.params.id), desafios: rows.length },
    });
    return res.json({ desafios: rows, progreso: null });
  }

  // Con cuenta: se abre el progreso, o se retoma el que habia quedado.
  const { id: progresoId, nuevo } = await abrirProgreso(req.usuario.id, req.params.id);
  const estado = await estadoDelProgreso(progresoId);

  // Donde retoma: el primer desafio que todavia no resolvio. Se busca por id y
  // no por posicion, porque el administrador pudo haber agregado o borrado
  // desafios desde la ultima vez y una posicion apuntaria a otra cosa.
  const resueltos = new Set(estado.resueltos);
  const actual = rows.find((desafio) => !resueltos.has(Number(desafio.id)));

  // Retomar no es empezar: solo se registra como mision iniciada la primera vez.
  if (nuevo) {
    registrar({
      tipo: EVENTOS.MISION_INICIADA,
      usuarioId: req.usuario.id,
      progresoMisionId: progresoId,
      datos: { mision_id: Number(req.params.id), desafios: rows.length },
    });
  }

  return res.json({
    desafios: rows,
    progreso: {
      resueltos: estado.resueltos,
      puntos: estado.puntos,
      // Las pistas que ya pago en el desafio donde retoma: son suyas, y
      // cobrarselas otra vez por haber cerrado la app seria cobrar dos veces.
      pistas: actual ? await pistasYaPagadas(progresoId, actual.id) : [],
    },
  });
});

// Tipos que se resuelven llegando a la pieza: no tienen nada que contestar,
// asi que un escaneo correcto los da por terminados. Los otros dos siguen con
// la pregunta (VIS06).
const TIPOS_SIN_PREGUNTA = ['escaneo_objeto', 'busqueda_guiada'];

const DESAFIO_NO_DISPONIBLE = { error: 'Este desafío ya no está disponible' };

// Tope de pistas que se admite haber usado. No es una regla del juego: es para
// no aceptar un numero cualquiera en una consulta por venir de afuera.
const MAXIMO_PISTAS_USADAS = 100;

// Cuantas pistas dice la app haber pedido. Si no viene el dato, o viene algo
// que no es un entero positivo, se cuenta como ninguna: una version de la app
// anterior a VIS07 no manda nada y tiene que seguir jugando igual.
function pistasUsadasDe(cuerpo) {
  const valor = cuerpo?.pistas_usadas;
  if (typeof valor !== 'number' || !Number.isInteger(valor) || valor <= 0) return 0;
  return Math.min(valor, MAXIMO_PISTAS_USADAS);
}

// Cuanto descuentan las primeras `usadas` pistas del desafio (VIS07).
//
// La cuenta se hace aca y no en la app para que el puntaje tenga un solo
// dueño, el mismo que decide si la respuesta estuvo bien.
//
// El limite de esto, dicho claro: hoy la app es la que informa cuantas pistas
// pidio, porque el servidor no lleva el progreso del recorrido. Un APK
// modificado podria decir cero y quedarse con todos los puntos. Se arregla
// cuando el progreso se guarde (SIS03) y el dato salga de la base en vez del
// cuerpo del pedido.
async function descuentoPorPistas(desafioId, usadas) {
  if (usadas <= 0) return 0;
  const { rows } = await pool.query(
    `SELECT COALESCE(sum(penalizacion), 0)::int AS descuento
       FROM (SELECT penalizacion FROM pistas
              WHERE desafio_id = $1
              ORDER BY orden, id
              LIMIT $2) AS usadas`,
    [desafioId, usadas]
  );
  return rows[0].descuento;
}

// Los puntos que quedan despues del descuento. Nunca menos de cero: pedir
// muchas pistas puede dejar un desafio sin premio, pero no puede hacer que
// resolverlo reste puntos.
const conDescuento = (puntos, descuento) => Math.max(0, puntos - descuento);

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

  // Con cuenta, las pistas usadas salen del progreso guardado y no de lo que
  // diga la app (SIS03). Sin cuenta no hay progreso y sigue valiendo el dato
  // del pedido, con la salvedad que ya estaba en VIS07.
  const progreso = req.usuario ? await progresoDelDesafio(req.usuario.id, req.params.id) : null;
  const usadas = progreso ? progreso.pistasUsadas : pistasUsadasDe(req.body);

  // Los codigos estan enteramente en mayusculas, tanto los que genera la API
  // (OBJ- mas ocho simbolos de un alfabeto en mayusculas) como los cargados a
  // mano en la base (MLP-OBJ-005). Por eso subir a mayusculas no puede hacer
  // que dos codigos distintos se confundan: no hay dos que difieran solo en
  // eso. Lo que si arregla es un lector que devuelva el texto en minusculas.
  const escaneado = codigo.trim().toUpperCase();
  if (escaneado !== desafio.codigo.toUpperCase()) {
    // Escanear la pieza equivocada es un intento fallido de dar con ella.
    if (progreso) {
      await guardarIntento({
        progresoId: progreso.id,
        desafioId: Number(req.params.id),
        acerto: false,
        puntos: 0,
      });
    }
    // Escanear la pieza equivocada tambien es una interaccion, y saber cuales
    // se confunden le sirve al museo tanto como saber cuales se aciertan.
    registrar({
      tipo: EVENTOS.OBJETO_ESCANEADO,
      desafioId: Number(req.params.id),
      usuarioId: req.usuario?.id ?? null,
      progresoMisionId: progreso?.id ?? null,
      datos: { correcto: false },
    });
    // No se dice que pieza escaneo. En la busqueda guiada, nombrarla seria
    // darle la respuesta que justamente tenia que deducir.
    return res.json({ correcto: false });
  }

  const sinPregunta = TIPOS_SIN_PREGUNTA.includes(desafio.tipo);
  // El descuento por pistas solo hace falta si este escaneo ya resuelve el
  // desafio. Si sigue con una pregunta, los puntos se otorgan al contestarla
  // y el descuento se aplica alla.
  const descuento = sinPregunta ? await descuentoPorPistas(req.params.id, usadas) : 0;
  const puntos = sinPregunta ? conDescuento(desafio.puntos, descuento) : 0;

  // Solo cuenta como intento si este escaneo era la forma de resolverlo. En un
  // desafio que ademas pregunta algo, dar con la pieza es avanzar, no
  // intentar resolverlo: eso se intenta al contestar.
  if (progreso && sinPregunta) {
    await guardarIntento({
      progresoId: progreso.id,
      desafioId: Number(req.params.id),
      acerto: true,
      puntos,
    });
  }

  registrar({
    tipo: EVENTOS.OBJETO_ESCANEADO,
    desafioId: Number(req.params.id),
    usuarioId: req.usuario?.id ?? null,
    progresoMisionId: progreso?.id ?? null,
    datos: { correcto: true, resuelto: sinPregunta, puntos },
  });

  return res.json({
    correcto: true,
    pieza: desafio.pieza,
    // Lo que el visitante se gana por llegar hasta la vitrina, y con lo que
    // despues responde la pregunta si el desafio tiene una.
    dato_clave: desafio.dato_clave,
    resuelto: sinPregunta,
    puntos,
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

  // Equivocarse no descuenta nada, asi que el descuento solo se consulta
  // cuando hay puntos que dar.
  // Con cuenta, las pistas usadas las pone el servidor (SIS03).
  const progreso = req.usuario ? await progresoDelDesafio(req.usuario.id, req.params.id) : null;
  const usadas = progreso ? progreso.pistasUsadas : pistasUsadasDe(req.body);

  const descuento = acerto ? await descuentoPorPistas(req.params.id, usadas) : 0;
  const puntos = acerto ? conDescuento(desafio.puntos, descuento) : 0;

  // Contestar siempre es un intento, se acierte o no.
  if (progreso) {
    await guardarIntento({
      progresoId: progreso.id,
      desafioId: Number(req.params.id),
      acerto,
      puntos,
    });
  }

  // Que desafio se falla y cuanto se falla es lo que despues deja ver si un
  // enunciado esta mal redactado. El texto de lo que escribio el visitante no
  // se guarda: para eso alcanza con contar los fallos de cada desafio.
  registrar({
    tipo: acerto ? EVENTOS.RESPUESTA_CORRECTA : EVENTOS.RESPUESTA_INCORRECTA,
    desafioId: Number(req.params.id),
    usuarioId: req.usuario?.id ?? null,
    progresoMisionId: progreso?.id ?? null,
    datos: acerto ? { puntos, descuento } : {},
  });

  return res.json({ correcto: acerto, puntos });
});

// GET /publico/desafios/:id/pista?usadas=N — la pista que sigue (VIS07).
//
// Se entrega de a una y a pedido. Mandarlas junto con los desafios seria
// regalar la ayuda: el visitante las tendria sin haberlas pedido y sin que le
// costaran nada. `usadas` es cuantas ya recibio, asi que lo que se devuelve es
// la siguiente.
publicoRouter.get('/desafios/:id/pista', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(DESAFIO_NO_DISPONIBLE);

  // Number('') y Number(undefined) no son lo mismo: sin el ?? 0, no mandar el
  // parametro daria NaN y se rechazaria un pedido que vale.
  const usadas = Number(req.query.usadas ?? 0);
  if (!Number.isInteger(usadas) || usadas < 0 || usadas > MAXIMO_PISTAS_USADAS) {
    return res.status(400).json({ error: 'No se entendió qué pista pedir' });
  }

  // Con cuenta, cual toca lo decide el servidor y no el parametro: lleva la
  // cuenta de las que ya entrego (SIS03). Las que el visitante ya pago las
  // recupera al retomar la mision, no volviendo a pedirlas por aca.
  const progreso = req.usuario ? await progresoDelDesafio(req.usuario.id, req.params.id) : null;
  const desde = progreso ? progreso.pistasUsadas : usadas;

  // El JOIN con misiones, igual que en el escaneo: el id de un desafio suelto
  // no tiene que dejar jugar una mision que el museo despublico o archivo.
  const { rows } = await pool.query(
    `SELECT p.texto, p.penalizacion
       FROM desafios d
       JOIN misiones m ON m.id = d.mision_id
       JOIN pistas p ON p.desafio_id = d.id
      WHERE d.id = $1 AND m.activa = TRUE AND m.archivada = FALSE
      ORDER BY p.orden, p.id
      OFFSET $2 LIMIT 1`,
    [req.params.id, desde]
  );
  // Sin fila puede ser que el desafio no este disponible, que no tenga pistas
  // o que ya se hayan dado todas. Para el visitante son lo mismo: no hay mas
  // ayuda de la que ya tiene.
  if (!rows[0]) return res.status(404).json({ error: 'No hay más pistas para este desafío' });

  if (progreso) {
    await guardarPistaUsada(progreso.id, Number(req.params.id), desde + 1);
  }

  registrar({
    tipo: EVENTOS.PISTA_USADA,
    desafioId: Number(req.params.id),
    usuarioId: req.usuario?.id ?? null,
    progresoMisionId: progreso?.id ?? null,
    datos: { orden: desde + 1, penalizacion: rows[0].penalizacion },
  });

  return res.json({ pista: rows[0] });
});

// Tope de puntos que se acepta como resultado informado. No es una regla del
// juego: es para que un numero disparatado no entre en la bitacora.
const PUNTOS_MAXIMOS_MISION = 999999;

// POST /publico/misiones/:id/completada — deja constancia de que el visitante
// termino la mision (SIS02).
//
// Existe solo para la bitacora: la app ya sabe que termino y muestra el
// resultado sin preguntarle nada al servidor. Por eso responde 204, sin
// cuerpo, y por eso el puntaje que llega es el que informa la app, con la
// misma salvedad que pistas_usadas: hasta SIS03, el servidor no lleva el
// progreso y no tiene con que contrastarlo.
publicoRouter.post('/misiones/:id/completada', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_DISPONIBLE);

  const { puntos } = req.body ?? {};
  const puntosValidos =
    puntos === undefined ||
    puntos === null ||
    (typeof puntos === 'number' &&
      Number.isInteger(puntos) &&
      puntos >= 0 &&
      puntos <= PUNTOS_MAXIMOS_MISION);
  if (!puntosValidos) {
    return res.status(400).json({ error: 'El puntaje informado no es válido' });
  }

  // Misma comprobacion que el resto: no se registra el final de una mision que
  // el museo bajo, igual que no se habria podido empezar.
  const mision = await pool.query(
    'SELECT 1 FROM misiones WHERE id = $1 AND activa = TRUE AND archivada = FALSE',
    [req.params.id]
  );
  if (!mision.rows[0]) return res.status(404).json(NO_DISPONIBLE);

  // Con cuenta queda cerrada de verdad: el progreso pasa a completada y deja
  // de estar en curso, asi que volver a jugarla empieza una vuelta nueva.
  const progresoId = req.usuario
    ? await completarProgreso(req.usuario.id, req.params.id)
    : null;

  registrar({
    tipo: EVENTOS.MISION_COMPLETADA,
    usuarioId: req.usuario?.id ?? null,
    progresoMisionId: progresoId,
    datos: { mision_id: Number(req.params.id), puntos: puntos ?? null },
  });

  return res.status(204).end();
});

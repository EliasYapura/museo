// Comprueba la valoracion de una mision (VIS14).
//
// Lo que importa: que califique solo quien tiene cuenta y termino la mision
// —las dos cosas las decide el servidor, no la app—, que una persona no pueda
// dejar dos valoraciones de la misma mision, y que volver a calificar corrija
// la anterior en lugar de sumar otra.
//
// Crea su propia mision y su propio visitante, y los borra al terminar.
//
// Se corre desde backend/ con --env-file=.env

import { API, administrador, bd, comprobar, pedir, terminar, tokenDe } from './ayuda.mjs';

import { config } from '../src/config.js';

const marca = Date.now();
let misionId = null;
let misionBajaId = null;
let visitanteId = null;
let otroId = null;

try {
  // --- datos de la prueba --------------------------------------------------
  const admin = await bd.query(
    "SELECT id FROM usuarios WHERE rol = 'administrador' AND activo = TRUE ORDER BY id LIMIT 1"
  );
  const adminId = admin.rows[0].id;

  // El hash no es de ninguna contrasenia real: estos visitantes existen solo
  // para esta prueba, nunca se usa el login con ellos y se borran al final.
  const sinLogin = 'no-es-un-hash-valido-solo-para-la-prueba';

  const v = await bd.query(
    `INSERT INTO usuarios (email, password_hash, nombre, rol)
     VALUES ($1, $2, 'Visitante de prueba VIS14', 'visitante') RETURNING id`,
    [`vis14-${marca}@prueba.test`, sinLogin]
  );
  visitanteId = v.rows[0].id;

  const o = await bd.query(
    `INSERT INTO usuarios (email, password_hash, nombre, rol)
     VALUES ($1, $2, 'Otro visitante VIS14', 'visitante') RETURNING id`,
    [`vis14-otro-${marca}@prueba.test`, sinLogin]
  );
  otroId = o.rows[0].id;

  const m = await bd.query(
    `INSERT INTO misiones (nombre, descripcion, duracion_estimada, activa, creada_por)
     VALUES ($1, 'Mision de la prueba de VIS14', 20, TRUE, $2) RETURNING id`,
    [`Mision VIS14 ${marca}`, adminId]
  );
  misionId = m.rows[0].id;

  const baja = await bd.query(
    `INSERT INTO misiones (nombre, descripcion, duracion_estimada, activa, creada_por)
     VALUES ($1, 'Mision despublicada de la prueba', 20, FALSE, $2) RETURNING id`,
    [`Mision VIS14 sin publicar ${marca}`, adminId]
  );
  misionBajaId = baja.rows[0].id;

  const token = tokenDe(visitanteId, 'visitante');
  const tokenOtro = tokenDe(otroId, 'visitante');

  // --- sin cuenta ----------------------------------------------------------
  const anonimo = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, null, {
    puntuacion: 5,
  });
  comprobar('sin cuenta -> 401', anonimo.estado === 401, `estado ${anonimo.estado}`);

  // --- sin haberla terminado ----------------------------------------------
  const sinJugar = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: 5,
  });
  comprobar('sin terminarla -> 409', sinJugar.estado === 409, `estado ${sinJugar.estado}`);

  // Empezada pero no terminada: tampoco.
  const progreso = await bd.query(
    `INSERT INTO progreso_misiones (usuario_id, mision_id, estado)
     VALUES ($1, $2, 'en_curso') RETURNING id`,
    [visitanteId, misionId]
  );
  const enCurso = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: 4,
  });
  comprobar('empezada pero sin terminar -> 409', enCurso.estado === 409, `estado ${enCurso.estado}`);

  // --- terminada: ahora si --------------------------------------------------
  await bd.query(
    "UPDATE progreso_misiones SET estado = 'completada', finalizada_en = NOW() WHERE id = $1",
    [progreso.rows[0].id]
  );

  const mala = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: 6,
  });
  comprobar('6 estrellas -> 400', mala.estado === 400, `estado ${mala.estado}`);

  const cero = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: 0,
  });
  comprobar('0 estrellas -> 400', cero.estado === 400, `estado ${cero.estado}`);

  const media = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: 4.5,
  });
  comprobar('4.5 estrellas -> 400', media.estado === 400, `estado ${media.estado}`);

  const texto = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: '4',
  });
  comprobar('"4" como texto -> 400', texto.estado === 400, `estado ${texto.estado}`);

  const buena = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: 4,
  });
  comprobar('calificar con 4 -> 200', buena.estado === 200, `estado ${buena.estado}`);
  comprobar(
    'devuelve la puntuacion guardada',
    buena.cuerpo?.valoracion?.puntuacion === 4,
    JSON.stringify(buena.cuerpo)
  );

  const guardada = await bd.query(
    'SELECT puntuacion, creada_en FROM valoraciones WHERE mision_id = $1 AND usuario_id = $2',
    [misionId, visitanteId]
  );
  comprobar('quedo en la base', guardada.rows[0]?.puntuacion === 4, String(guardada.rows[0]?.puntuacion));

  // --- volver a calificar corrige, no suma ---------------------------------
  const otraVez = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, token, {
    puntuacion: 2,
  });
  comprobar('volver a calificar -> 200', otraVez.estado === 200, `estado ${otraVez.estado}`);

  const cuantas = await bd.query(
    'SELECT count(*)::int AS n, min(puntuacion) AS p, min(creada_en) AS fecha FROM valoraciones WHERE mision_id = $1 AND usuario_id = $2',
    [misionId, visitanteId]
  );
  comprobar('sigue habiendo una sola valoracion', cuantas.rows[0].n === 1, `${cuantas.rows[0].n} filas`);
  comprobar('quedo la nueva puntuacion', cuantas.rows[0].p === 2, String(cuantas.rows[0].p));
  comprobar(
    'creada_en no se movio',
    cuantas.rows[0].fecha.getTime() === guardada.rows[0].creada_en.getTime(),
    `${cuantas.rows[0].fecha.toISOString()} vs ${guardada.rows[0].creada_en.toISOString()}`
  );

  // --- otro visitante, su propia valoracion --------------------------------
  await bd.query(
    `INSERT INTO progreso_misiones (usuario_id, mision_id, estado, finalizada_en)
     VALUES ($1, $2, 'completada', NOW())`,
    [otroId, misionId]
  );
  const delOtro = await pedir('POST', `/publico/misiones/${misionId}/valoracion`, tokenOtro, {
    puntuacion: 5,
  });
  comprobar('otro visitante califica la misma mision', delOtro.estado === 200, `estado ${delOtro.estado}`);

  const promedio = await bd.query(
    'SELECT count(*)::int AS n, round(avg(puntuacion), 2)::float8 AS promedio FROM valoraciones WHERE mision_id = $1',
    [misionId]
  );
  comprobar(
    'la mision tiene dos valoraciones y promedio 3.5',
    promedio.rows[0].n === 2 && promedio.rows[0].promedio === 3.5,
    JSON.stringify(promedio.rows[0])
  );

  // --- misiones que no se pueden calificar ---------------------------------
  const despublicada = await pedir('POST', `/publico/misiones/${misionBajaId}/valoracion`, token, {
    puntuacion: 5,
  });
  comprobar('mision despublicada -> 404', despublicada.estado === 404, `estado ${despublicada.estado}`);

  const inexistente = await pedir('POST', '/publico/misiones/999999/valoracion', token, {
    puntuacion: 5,
  });
  comprobar('mision inexistente -> 404', inexistente.estado === 404, `estado ${inexistente.estado}`);
} finally {
  // --- limpieza ------------------------------------------------------------
  // Las valoraciones y el progreso se van en cascada con la mision y con el
  // usuario, asi que alcanza con borrar esos cuatro.
  if (misionId) await bd.query('DELETE FROM misiones WHERE id = $1', [misionId]);
  if (misionBajaId) await bd.query('DELETE FROM misiones WHERE id = $1', [misionBajaId]);
  if (visitanteId) await bd.query('DELETE FROM usuarios WHERE id = $1', [visitanteId]);
  if (otroId) await bd.query('DELETE FROM usuarios WHERE id = $1', [otroId]);
  const quedan = await bd.query(
    "SELECT count(*)::int AS n FROM usuarios WHERE email LIKE 'vis14-%@prueba.test'"
  );
  console.log(`limpieza: quedan ${quedan.rows[0].n} usuarios de esta prueba`);
  }

await terminar();

// Comprueba el recorrido del visitante de punta a punta (VIS05 a VIS10).
//
// Es el corazon del sistema: encontrar la pieza, contestar, pedir ayuda,
// sumar puntos y cerrar la mision. Lo que mas importa comprobar no es que
// conteste bien cuando todo sale bien, sino que el servidor sea el que decide:
//
// - que la respuesta correcta y el codigo de la pieza NO viajen al telefono,
//   porque si viajan alcanza con abrir el APK para resolver la mision sin
//   moverse del lugar;
// - que los puntos los ponga el servidor y no lo que diga la app;
// - que las pistas se cobren;
// - que repetir un acierto no pague dos veces;
// - que una mision despublicada deje de jugarse, aunque alguien tenga a mano
//   el id de un desafio.
//
// Arma su propia mision, su propia pieza y su propia insignia, y las borra al
// terminar.
//
// Se corre desde backend/ con --env-file=.env

import {
  administrador,
  bd,
  borrarUsuarios,
  comprobar,
  pedir,
  terminar,
  visitanteNuevo,
} from './ayuda.mjs';

const marca = Date.now();
let misionId = null;
let objetoId = null;
let insigniaId = null;
let visitanteId = null;

// Lo que tiene que valer cada desafio, descuentos aparte.
const PUNTOS = { escaneo: 20, flexible: 15, exacta: 10, opcion: 10 };
const PENALIZACION = 5;

try {
  const adminId = await administrador();

  // --- la pieza, con un codigo que no existe en ninguna otra ---------------
  const sala = await bd.query('SELECT id FROM salas ORDER BY id LIMIT 1');
  const codigo = `PRUEBA-REC-${marca}`;
  const o = await bd.query(
    `INSERT INTO objetos (sala_id, nombre, descripcion, dato_clave, codigo)
     VALUES ($1, $2, 'Pieza de la prueba del recorrido', 'Mide 27 metros', $3)
     RETURNING id`,
    [sala.rows[0].id, `Pieza de prueba ${marca}`, codigo]
  );
  objetoId = Number(o.rows[0].id);

  // --- la mision, publicada ------------------------------------------------
  const m = await bd.query(
    `INSERT INTO misiones (nombre, descripcion, duracion_estimada, activa, creada_por)
     VALUES ($1, 'Mision de la prueba del recorrido', 10, TRUE, $2)
     RETURNING id`,
    [`Prueba recorrido ${marca}`, adminId]
  );
  misionId = Number(m.rows[0].id);

  const nuevoDesafio = async (orden, tipo, enunciado, extra = {}) => {
    const { rows } = await bd.query(
      `INSERT INTO desafios (mision_id, objeto_id, orden, tipo, enunciado,
                             configuracion, respuesta_correcta, puntos)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id`,
      [
        misionId,
        extra.objetoId ?? null,
        orden,
        tipo,
        enunciado,
        extra.configuracion ?? {},
        extra.respuesta ?? null,
        extra.puntos,
      ]
    );
    return Number(rows[0].id);
  };

  const dEscaneo = await nuevoDesafio(1, 'escaneo_objeto', 'Encontrá la pieza y escaneala.', {
    objetoId,
    puntos: PUNTOS.escaneo,
  });
  // Una sola pista, que cuesta. Es lo que hace comprobable el descuento.
  await bd.query(
    `INSERT INTO pistas (desafio_id, orden, texto, penalizacion)
     VALUES ($1, 1, 'Está al fondo de la sala, a la derecha.', $2)`,
    [dEscaneo, PENALIZACION]
  );

  const dFlexible = await nuevoDesafio(2, 'respuesta_corta', '¿Cómo se llama el dinosaurio?', {
    respuesta: 'Diplodocus',
    configuracion: { tolerancia: 'flexible' },
    puntos: PUNTOS.flexible,
  });

  const dExacta = await nuevoDesafio(3, 'respuesta_corta', '¿Quién lo donó? Escribilo igual.', {
    respuesta: 'Carnegie',
    configuracion: { tolerancia: 'exacta' },
    puntos: PUNTOS.exacta,
  });

  const dOpcion = await nuevoDesafio(4, 'pregunta_opcion_multiple', '¿Cuánto mide?', {
    respuesta: 'Veintisiete metros',
    configuracion: {
      opciones: ['Diez metros', 'Veintisiete metros', 'Cuarenta metros'],
    },
    puntos: PUNTOS.opcion,
  });

  // Una insignia que se gana justamente completando esta mision, para
  // comprobar que el cierre la otorga (VIS10).
  const ins = await bd.query(
    `INSERT INTO insignias (nombre, descripcion, condicion)
     VALUES ($1, 'Insignia de la prueba del recorrido', $2)
     RETURNING id`,
    [`Prueba recorrido ${marca}`, { tipo: 'misiones_completadas', misiones: [misionId] }]
  );
  insigniaId = Number(ins.rows[0].id);

  const v = await visitanteNuevo('Visitante del recorrido');
  visitanteId = v.id;

  // --- lo que recibe el telefono -------------------------------------------
  const lista = await pedir('GET', `/publico/misiones/${misionId}/desafios`, v.token);
  comprobar('la misión publicada se puede jugar', lista.estado === 200, `estado ${lista.estado}`);
  comprobar('trae los cuatro desafíos', lista.cuerpo?.desafios?.length === 4,
    `${lista.cuerpo?.desafios?.length}`);

  // Esto es lo mas importante de toda la prueba.
  const crudo = JSON.stringify(lista.cuerpo);
  const filtradas = ['Diplodocus', 'Carnegie'].filter((texto) => crudo.includes(texto));
  comprobar('el teléfono NO recibe las respuestas correctas', filtradas.length === 0,
    `respuestas encontradas en el JSON: ${filtradas.join(', ') || 'ninguna'}`);
  comprobar('el teléfono NO recibe el código de la pieza', !crudo.includes(codigo),
    crudo.includes(codigo) ? 'está en el JSON' : 'no está en el JSON');
  comprobar('ni el campo respuesta_correcta', !crudo.includes('respuesta_correcta'),
    crudo.includes('respuesta_correcta') ? 'está el campo' : 'no está el campo');
  // Las opciones si tienen que viajar: son lo que el visitante elige.
  comprobar('pero sí recibe las opciones para elegir', crudo.includes('Veintisiete metros'),
    crudo.includes('Veintisiete metros') ? 'llegaron' : 'no llegaron');

  // --- encontrar la pieza, con una pista de por medio ----------------------
  const malEscaneo = await pedir('POST', `/publico/desafios/${dEscaneo}/escaneo`, v.token, {
    codigo: 'OBJ-OTRACOSA',
  });
  comprobar('escanear la pieza equivocada no resuelve', malEscaneo.cuerpo?.correcto === false,
    JSON.stringify(malEscaneo.cuerpo));
  comprobar('y no dice cuál era la pieza', !JSON.stringify(malEscaneo.cuerpo).includes(codigo),
    JSON.stringify(malEscaneo.cuerpo));

  const pista = await pedir('GET', `/publico/desafios/${dEscaneo}/pista`, v.token);
  comprobar('se puede pedir una pista', pista.estado === 200, `estado ${pista.estado}`);
  comprobar('la pista avisa lo que cuesta', pista.cuerpo?.pista?.penalizacion === PENALIZACION,
    JSON.stringify(pista.cuerpo));

  const sinMasPistas = await pedir('GET', `/publico/desafios/${dEscaneo}/pista`, v.token);
  comprobar('no hay una segunda pista que no existe', sinMasPistas.estado === 404,
    `estado ${sinMasPistas.estado}`);

  // El codigo se compara sin mirar mayusculas: un lector que lo devuelva en
  // minuscula tiene que servir igual.
  const bienEscaneo = await pedir('POST', `/publico/desafios/${dEscaneo}/escaneo`, v.token, {
    codigo: codigo.toLowerCase(),
  });
  comprobar('la pieza correcta resuelve el desafío', bienEscaneo.cuerpo?.correcto === true,
    JSON.stringify(bienEscaneo.cuerpo));
  comprobar('y la pista se cobra de los puntos',
    bienEscaneo.cuerpo?.puntos === PUNTOS.escaneo - PENALIZACION,
    `dio ${bienEscaneo.cuerpo?.puntos}, esperaba ${PUNTOS.escaneo - PENALIZACION}`);

  // --- contestar -----------------------------------------------------------
  const flexMal = await pedir('POST', `/publico/desafios/${dFlexible}/respuesta`, v.token, {
    respuesta: 'Tiranosaurio',
  });
  comprobar('una respuesta equivocada no suma', flexMal.cuerpo?.correcto === false,
    JSON.stringify(flexMal.cuerpo));

  // Tolerancia flexible: con tilde de mas, en minuscula y con espacios
  // sobrantes tiene que darla por buena.
  const flexBien = await pedir('POST', `/publico/desafios/${dFlexible}/respuesta`, v.token, {
    respuesta: '  diplódocus ',
  });
  comprobar('la tolerancia flexible perdona tildes y mayúsculas',
    flexBien.cuerpo?.correcto === true, JSON.stringify(flexBien.cuerpo));
  comprobar('y paga los puntos del desafío', flexBien.cuerpo?.puntos === PUNTOS.flexible,
    `dio ${flexBien.cuerpo?.puntos}`);

  // Tolerancia exacta: la misma palabra en minuscula ya no vale.
  const exactaMal = await pedir('POST', `/publico/desafios/${dExacta}/respuesta`, v.token, {
    respuesta: 'carnegie',
  });
  comprobar('la tolerancia exacta no perdona la mayúscula',
    exactaMal.cuerpo?.correcto === false, JSON.stringify(exactaMal.cuerpo));

  const exactaBien = await pedir('POST', `/publico/desafios/${dExacta}/respuesta`, v.token, {
    respuesta: 'Carnegie',
  });
  comprobar('escrita igual, la da por buena', exactaBien.cuerpo?.correcto === true,
    JSON.stringify(exactaBien.cuerpo));

  const opcion = await pedir('POST', `/publico/desafios/${dOpcion}/respuesta`, v.token, {
    respuesta: 'Veintisiete metros',
  });
  comprobar('la opción correcta resuelve', opcion.cuerpo?.correcto === true,
    JSON.stringify(opcion.cuerpo));

  // --- repetir un acierto no puede volver a pagar --------------------------
  const esperados =
    PUNTOS.escaneo - PENALIZACION + PUNTOS.flexible + PUNTOS.exacta + PUNTOS.opcion;

  await pedir('POST', `/publico/desafios/${dOpcion}/respuesta`, v.token, {
    respuesta: 'Veintisiete metros',
  });
  await pedir('POST', `/publico/desafios/${dEscaneo}/escaneo`, v.token, { codigo });

  const progreso = await bd.query(
    `SELECT puntos_obtenidos, estado FROM progreso_misiones
      WHERE usuario_id = $1 AND mision_id = $2`,
    [visitanteId, misionId]
  );
  comprobar('el puntaje lo lleva el servidor, sin duplicar',
    Number(progreso.rows[0]?.puntos_obtenidos) === esperados,
    `guardó ${progreso.rows[0]?.puntos_obtenidos}, esperaba ${esperados}`);

  // --- cerrar la mision ----------------------------------------------------
  const fin = await pedir('POST', `/publico/misiones/${misionId}/completada`, v.token, {});
  comprobar('la misión se cierra', fin.estado === 200, `estado ${fin.estado}`);
  comprobar('y otorga la insignia que se ganó',
    fin.cuerpo?.insignias?.some((i) => Number(i.id) === insigniaId),
    JSON.stringify(fin.cuerpo?.insignias));

  const cerrada = await bd.query(
    `SELECT estado, finalizada_en FROM progreso_misiones
      WHERE usuario_id = $1 AND mision_id = $2`,
    [visitanteId, misionId]
  );
  comprobar('queda completada en la base', cerrada.rows[0]?.estado === 'completada',
    JSON.stringify(cerrada.rows[0]));
  comprobar('con la fecha de cierre', cerrada.rows[0]?.finalizada_en !== null,
    JSON.stringify(cerrada.rows[0]));

  const tiene = await bd.query(
    'SELECT 1 FROM usuarios_insignias WHERE usuario_id = $1 AND insignia_id = $2',
    [visitanteId, insigniaId]
  );
  comprobar('la insignia quedó guardada', tiene.rowCount === 1, `filas ${tiene.rowCount}`);

  // Cerrar dos veces no puede duplicar la insignia ni mover la fecha.
  await pedir('POST', `/publico/misiones/${misionId}/completada`, v.token, {});
  const otraVez = await bd.query(
    'SELECT count(*)::int AS n FROM usuarios_insignias WHERE usuario_id = $1 AND insignia_id = $2',
    [visitanteId, insigniaId]
  );
  comprobar('cerrar dos veces no duplica la insignia', otraVez.rows[0].n === 1,
    `${otraVez.rows[0].n}`);

  // --- sin cuenta tambien se puede jugar -----------------------------------
  const anonimo = await pedir('POST', `/publico/desafios/${dEscaneo}/escaneo`, null, { codigo });
  comprobar('sin cuenta también se puede jugar', anonimo.cuerpo?.correcto === true,
    JSON.stringify(anonimo.cuerpo));

  // --- una mision despublicada deja de jugarse -----------------------------
  await bd.query('UPDATE misiones SET activa = FALSE WHERE id = $1', [misionId]);

  const despublicada = await pedir('POST', `/publico/desafios/${dEscaneo}/escaneo`, v.token, {
    codigo,
  });
  comprobar('despublicada, el escaneo ya no entra', despublicada.estado === 404,
    `estado ${despublicada.estado}`);

  const respuestaCerrada = await pedir('POST', `/publico/desafios/${dFlexible}/respuesta`, v.token, {
    respuesta: 'Diplodocus',
  });
  comprobar('ni la respuesta', respuestaCerrada.estado === 404, `estado ${respuestaCerrada.estado}`);

  const pistaCerrada = await pedir('GET', `/publico/desafios/${dEscaneo}/pista`, v.token);
  comprobar('ni la pista', pistaCerrada.estado === 404, `estado ${pistaCerrada.estado}`);
} finally {
  if (visitanteId) await borrarUsuarios([visitanteId]);
  if (misionId) await bd.query('DELETE FROM misiones WHERE id = $1', [misionId]);
  if (insigniaId) await bd.query('DELETE FROM insignias WHERE id = $1', [insigniaId]);
  if (objetoId) await bd.query('DELETE FROM objetos WHERE id = $1', [objetoId]);
  await terminar();
}

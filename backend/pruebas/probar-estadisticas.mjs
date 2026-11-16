// Comprueba el tablero de estadisticas de uso (ADM22).
//
// Arma una mision con datos controlados: participaciones con cuenta y sin
// cuenta, tiempos conocidos y uno absurdo, y fallos de los dos tipos (una
// respuesta incorrecta y un escaneo de la pieza equivocada). Despues comprueba
// que el tablero devuelva exactamente lo que se espera de esos datos.
//
// Lo que mas importa:
// - que las participaciones incluyan a los visitantes sin cuenta;
// - que el tiempo sea la mediana y descarte las participaciones de mas de un
//   dia, contandolas aparte;
// - que un escaneo equivocado cuente como fallo;
// - que /estadisticas sea solo para administradores.
//
// Se corre desde backend/ con --env-file=.env

import { API, administrador, bd, comprobar, pedir, terminar, tokenDe } from './ayuda.mjs';

const marca = Date.now();
// El token lo firma tokenDe, que esta en ayuda.mjs.
const token = tokenDe;

let misionId = null;
let objetoId = null;
const visitantes = [];

// Los eventos que inserta esta prueba, para borrar al final exactamente estos.
//
// Borrarlos por fecha seria peligroso: los eventos de un desafio borrado
// quedan con desafio_id en NULL (la clave es ON DELETE SET NULL), asi que un
// "borrar los anonimos recientes" se llevaria los eventos de verdad de
// cualquiera que haya estado usando la app en ese momento.
const eventosCreados = [];

async function evento(sql, params) {
  const r = await bd.query(`${sql} RETURNING id`, params);
  eventosCreados.push(r.rows[0].id);
}

try {
  const admin = await bd.query(
    "SELECT id FROM usuarios WHERE rol = 'administrador' AND activo = TRUE ORDER BY id LIMIT 1"
  );
  const tokenAdmin = token(admin.rows[0].id, 'administrador');

  // --- la mision de la prueba, con dos desafios ----------------------------
  const sala = await bd.query('SELECT id FROM salas ORDER BY id LIMIT 1');
  const m = await bd.query(
    `INSERT INTO misiones (nombre, descripcion, duracion_estimada, activa, creada_por)
     VALUES ($1, 'Mision de la prueba de ADM22', 25, TRUE, $2) RETURNING id`,
    [`ADM22 ${marca}`, admin.rows[0].id]
  );
  misionId = Number(m.rows[0].id);

  const o = await bd.query(
    `INSERT INTO objetos (sala_id, nombre, dato_clave, codigo)
     VALUES ($1, $2, 'Dato de la prueba ADM22', $3) RETURNING id`,
    [sala.rows[0].id, `Pieza ADM22 ${marca}`, `OBJ-A22${String(marca).slice(-5)}`]
  );
  objetoId = Number(o.rows[0].id);

  const d1 = await bd.query(
    `INSERT INTO desafios (mision_id, tipo, enunciado, puntos, orden)
     VALUES ($1, 'respuesta_corta', 'Pregunta de la prueba', 10, 1) RETURNING id`,
    [misionId]
  );
  const d2 = await bd.query(
    `INSERT INTO desafios (mision_id, objeto_id, tipo, enunciado, puntos, orden)
     VALUES ($1, $2, 'escaneo_objeto', 'Encontra la pieza', 10, 2) RETURNING id`,
    [misionId, objetoId]
  );
  const desafio1 = Number(d1.rows[0].id);
  const desafio2 = Number(d2.rows[0].id);

  // --- tres visitantes con cuenta y tiempos conocidos ----------------------
  // 10, 20 y 30 minutos -> mediana 20. Y uno de dos dias, que no se cuenta.
  const minutos = [10, 20, 30, 60 * 48];
  for (let i = 0; i < minutos.length; i++) {
    const u = await bd.query(
      `INSERT INTO usuarios (email, password_hash, nombre, rol)
       VALUES ($1, 'no-es-un-hash-valido-solo-para-la-prueba', $2, 'visitante') RETURNING id`,
      [`adm22-${i}-${marca}@prueba.test`, `Visitante ${i} ADM22`]
    );
    visitantes.push(Number(u.rows[0].id));

    await bd.query(
      `INSERT INTO progreso_misiones (usuario_id, mision_id, estado, iniciada_en, finalizada_en)
       VALUES ($1, $2, 'completada', NOW() - ($3 || ' minutes')::interval, NOW())`,
      [u.rows[0].id, misionId, minutos[i]]
    );
  }

  // --- la bitacora ---------------------------------------------------------
  // 6 inicios: 4 de los visitantes con cuenta y 2 sin cuenta. Asi las
  // participaciones (6) no coinciden con los progresos (4), que es justamente
  // lo que el tablero tiene que saber distinguir.
  for (const id of visitantes) {
    await evento(
      `INSERT INTO eventos (usuario_id, tipo, datos)
       VALUES ($1, 'mision_iniciada', jsonb_build_object('mision_id', $2::int))`,
      [id, misionId]
    );
  }
  for (let i = 0; i < 2; i++) {
    await evento(
      `INSERT INTO eventos (usuario_id, tipo, datos)
       VALUES (NULL, 'mision_iniciada', jsonb_build_object('mision_id', $1::int))`,
      [misionId]
    );
  }
  // 3 terminadas -> 50% de 6.
  for (let i = 0; i < 3; i++) {
    await evento(
      `INSERT INTO eventos (usuario_id, tipo, datos)
       VALUES (NULL, 'mision_completada', jsonb_build_object('mision_id', $1::int))`,
      [misionId]
    );
  }

  // Desafio 1: 4 aciertos y 1 fallo, 2 pistas.
  for (let i = 0; i < 4; i++) {
    await evento(
      "INSERT INTO eventos (desafio_id, tipo, datos) VALUES ($1, 'respuesta_correcta', '{}'::jsonb)",
      [desafio1]
    );
  }
  await evento(
    "INSERT INTO eventos (desafio_id, tipo, datos) VALUES ($1, 'respuesta_incorrecta', '{}'::jsonb)",
    [desafio1]
  );
  for (let i = 0; i < 2; i++) {
    await evento(
      "INSERT INTO eventos (desafio_id, tipo, datos) VALUES ($1, 'pista_usada', '{}'::jsonb)",
      [desafio1]
    );
  }

  // Desafio 2: 2 escaneos correctos y 3 equivocados. Los equivocados tienen
  // que contar como fallos.
  for (let i = 0; i < 2; i++) {
    await evento(
      `INSERT INTO eventos (desafio_id, tipo, datos)
       VALUES ($1, 'objeto_escaneado', '{"correcto": true}'::jsonb)`,
      [desafio2]
    );
  }
  for (let i = 0; i < 3; i++) {
    await evento(
      `INSERT INTO eventos (desafio_id, tipo, datos)
       VALUES ($1, 'objeto_escaneado', '{"correcto": false}'::jsonb)`,
      [desafio2]
    );
  }

  // --- permisos ------------------------------------------------------------
  const sinToken = await pedir('GET', '/estadisticas', null);
  comprobar('sin token -> 401', sinToken.estado === 401, `estado ${sinToken.estado}`);

  const comoVisitante = await pedir('GET', '/estadisticas', token(visitantes[0], 'visitante'));
  comprobar('como visitante -> 403', comoVisitante.estado === 403, `estado ${comoVisitante.estado}`);

  // --- el tablero ----------------------------------------------------------
  const tablero = await pedir('GET', '/estadisticas', tokenAdmin);
  comprobar('el tablero responde', tablero.estado === 200, `estado ${tablero.estado}`);

  const fila = tablero.cuerpo?.misiones?.find((x) => x.id === misionId);
  comprobar('la mision aparece en el tablero', fila !== undefined);
  comprobar(
    'cuenta las 6 participaciones, con cuenta y sin cuenta',
    fila?.participaciones === 6,
    String(fila?.participaciones)
  );
  comprobar('cuenta las 3 terminadas', fila?.completadas === 3, String(fila?.completadas));
  comprobar(
    'los fallos suman la respuesta incorrecta y los 3 escaneos equivocados',
    fila?.fallos === 4,
    String(fila?.fallos)
  );
  comprobar('cuenta las 2 pistas', fila?.pistas === 2, String(fila?.pistas));
  comprobar(
    'el tiempo es la mediana de 10, 20 y 30 minutos',
    fila?.minutos_mediana === 20,
    String(fila?.minutos_mediana)
  );
  comprobar(
    'midio 3 recorridos y descarto el de dos dias',
    fila?.participaciones_medidas === 3 && fila?.participaciones_sin_medir === 1,
    `medidas ${fila?.participaciones_medidas}, sin medir ${fila?.participaciones_sin_medir}`
  );

  // El resumen cuenta toda la bitacora, asi que tiene que ser por lo menos lo
  // que acabamos de insertar.
  comprobar(
    'el resumen incluye lo nuestro',
    tablero.cuerpo?.resumen?.participaciones >= 6 &&
      tablero.cuerpo?.resumen?.participaciones_sin_cuenta >= 2,
    JSON.stringify(tablero.cuerpo?.resumen)
  );

  // --- el detalle ----------------------------------------------------------
  const detalle = await pedir('GET', `/estadisticas/misiones/${misionId}`, tokenAdmin);
  comprobar('el detalle responde', detalle.estado === 200, `estado ${detalle.estado}`);
  comprobar(
    'el detalle trae la duracion estimada',
    detalle.cuerpo?.mision?.duracion_estimada === 25,
    String(detalle.cuerpo?.mision?.duracion_estimada)
  );
  comprobar('trae los dos desafios', detalle.cuerpo?.desafios?.length === 2, String(detalle.cuerpo?.desafios?.length));

  const uno = detalle.cuerpo?.desafios?.[0];
  comprobar(
    'desafio 1: 4 aciertos, 1 fallo, 2 pistas',
    uno?.aciertos === 4 && uno?.fallos === 1 && uno?.pistas === 2,
    JSON.stringify(uno)
  );

  const dos = detalle.cuerpo?.desafios?.[1];
  comprobar(
    'desafio 2: los escaneos cuentan como aciertos y fallos',
    dos?.aciertos === 2 && dos?.fallos === 3,
    JSON.stringify(dos)
  );
  comprobar('los desafios vienen en orden', uno?.orden === 1 && dos?.orden === 2, `${uno?.orden}, ${dos?.orden}`);

  // --- misiones que no corresponden ---------------------------------------
  const inexistente = await pedir('GET', '/estadisticas/misiones/999999', tokenAdmin);
  comprobar('mision inexistente -> 404', inexistente.estado === 404, `estado ${inexistente.estado}`);

  const basura = await pedir('GET', '/estadisticas/misiones/abc', tokenAdmin);
  comprobar('id que no es numero -> 404', basura.estado === 404, `estado ${basura.estado}`);

  await bd.query('UPDATE misiones SET archivada = TRUE WHERE id = $1', [misionId]);
  const archivada = await pedir('GET', `/estadisticas/misiones/${misionId}`, tokenAdmin);
  comprobar('mision archivada -> 404', archivada.estado === 404, `estado ${archivada.estado}`);
  const sinArchivadas = await pedir('GET', '/estadisticas', tokenAdmin);
  comprobar(
    'el tablero no lista las archivadas',
    sinArchivadas.cuerpo?.misiones?.find((x) => x.id === misionId) === undefined
  );
  await bd.query('UPDATE misiones SET archivada = FALSE WHERE id = $1', [misionId]);

  // --- que no se pise con GET /misiones/:id --------------------------------
  const porId = await pedir('GET', `/misiones/${misionId}`, tokenAdmin);
  comprobar(
    'GET /misiones/:id sigue andando',
    porId.estado === 200 && porId.cuerpo?.mision?.id === misionId,
    `estado ${porId.estado}`
  );
} finally {
  if (misionId) await bd.query('DELETE FROM misiones WHERE id = $1', [misionId]);
  if (objetoId) await bd.query('DELETE FROM objetos WHERE id = $1', [objetoId]);
  for (const id of visitantes) await bd.query('DELETE FROM usuarios WHERE id = $1', [id]);
  // Por id y nada mas: son los que inserto esta prueba y ningun otro.
  if (eventosCreados.length > 0) {
    const e = await bd.query('DELETE FROM eventos WHERE id = ANY($1) RETURNING id', [
      eventosCreados,
    ]);
    console.log(`limpieza: ${e.rowCount} de ${eventosCreados.length} eventos borrados`);
  }
  const quedan = await bd.query(
    "SELECT count(*)::int AS n FROM usuarios WHERE email LIKE 'adm22-%@prueba.test'"
  );
  console.log(`limpieza: quedan ${quedan.rows[0].n} usuarios de esta prueba`);
  }

await terminar();

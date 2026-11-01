import { pool } from './db.js';

// Progreso de una mision en curso (SIS03).
//
// Todo esto solo corre cuando el visitante tiene cuenta: progreso_misiones
// exige usuario_id y no admite nulos, asi que sin cuenta no hay fila donde
// anotar nada. Quien recorre sin cuenta juega igual, pero no se le guarda.

// 23505 es el codigo de PostgreSQL para violacion de UNIQUE.
const ES_REPETIDO = '23505';

// Abre el progreso de la mision, o devuelve el que ya estaba en curso.
//
// Devuelve { id, nuevo }. `nuevo` distingue empezar de retomar, que no son lo
// mismo: solo lo primero es una mision iniciada para la bitacora.
//
// La base tiene un indice unico parcial sobre (usuario_id, mision_id) que solo
// mira las filas en curso: nadie puede tener la misma mision empezada dos
// veces en paralelo. Eso tambien permite volver a jugar una mision ya
// completada, porque aquellas filas quedan fuera del indice.
//
// Primero se busca y despues se inserta, que con dos pedidos a la vez podria
// chocar; por eso el INSERT va en un try. Si choca es justamente porque otro
// pedido acaba de crear el que se buscaba, asi que se lee de nuevo. La
// correccion la garantiza el indice, no el orden de las consultas.
export async function abrirProgreso(usuarioId, misionId) {
  const enCurso = await pool.query(
    `SELECT id FROM progreso_misiones
      WHERE usuario_id = $1 AND mision_id = $2 AND estado = 'en_curso'`,
    [usuarioId, misionId]
  );
  if (enCurso.rows[0]) return { id: Number(enCurso.rows[0].id), nuevo: false };

  try {
    const { rows } = await pool.query(
      `INSERT INTO progreso_misiones (usuario_id, mision_id)
       VALUES ($1, $2)
       RETURNING id`,
      [usuarioId, misionId]
    );
    return { id: Number(rows[0].id), nuevo: true };
  } catch (err) {
    if (err.code !== ES_REPETIDO) throw err;
    const { rows } = await pool.query(
      `SELECT id FROM progreso_misiones
        WHERE usuario_id = $1 AND mision_id = $2 AND estado = 'en_curso'`,
      [usuarioId, misionId]
    );
    return { id: Number(rows[0].id), nuevo: false };
  }
}

// El progreso en curso al que pertenece un desafio, y cuantas pistas lleva
// pedidas en el. Va en una sola consulta para no sumar idas y vueltas a la
// base en medio del recorrido.
export async function progresoDelDesafio(usuarioId, desafioId) {
  const { rows } = await pool.query(
    `SELECT pm.id AS progreso_id, COALESCE(pd.pistas_usadas, 0) AS pistas_usadas
       FROM desafios d
       JOIN progreso_misiones pm
         ON pm.mision_id = d.mision_id
        AND pm.usuario_id = $1
        AND pm.estado = 'en_curso'
       LEFT JOIN progreso_desafios pd
         ON pd.progreso_mision_id = pm.id AND pd.desafio_id = d.id
      WHERE d.id = $2`,
    [usuarioId, desafioId]
  );
  if (!rows[0]) return null;
  return { id: Number(rows[0].progreso_id), pistasUsadas: rows[0].pistas_usadas };
}

// Donde habia quedado: que desafios resolvio y cuantos puntos lleva.
//
// Los resueltos van como lista de ids y no como un numero de posicion: si el
// administrador agrego o borro un desafio mientras tanto, una posicion
// apuntaria a otra cosa, y un id no.
export async function estadoDelProgreso(progresoId) {
  const { rows } = await pool.query(
    `SELECT desafio_id, puntos_obtenidos
       FROM progreso_desafios
      WHERE progreso_mision_id = $1 AND completado = TRUE`,
    [progresoId]
  );
  return {
    resueltos: rows.map((fila) => Number(fila.desafio_id)),
    puntos: rows.reduce((suma, fila) => suma + fila.puntos_obtenidos, 0),
  };
}

// Las pistas que el visitante ya pago en un desafio.
//
// Se le devuelven al retomar: ya las compro, y hacerselas pagar de nuevo por
// haber cerrado la app seria cobrarle dos veces lo mismo.
// Ojo con el COALESCE del LIMIT, que no es decorativo: si el visitante nunca
// toco ese desafio no hay fila de progreso, la subconsulta devuelve NULL, y en
// PostgreSQL LIMIT NULL significa "sin limite". Sin el cero, pedir el progreso
// de un desafio sin empezar devolveria TODAS sus pistas de una, gratis.
export async function pistasYaPagadas(progresoId, desafioId) {
  const { rows } = await pool.query(
    `SELECT p.texto
       FROM pistas p
      WHERE p.desafio_id = $2
      ORDER BY p.orden, p.id
      LIMIT COALESCE((SELECT pistas_usadas FROM progreso_desafios
                       WHERE progreso_mision_id = $1 AND desafio_id = $2), 0)`,
    [progresoId, desafioId]
  );
  return rows.map((fila) => fila.texto);
}

// Anota que el visitante pidio otra pista.
//
// Se guarda el maximo y no una suma: asi, volver a pedir una pista que ya
// habia pagado (al retomar, por ejemplo) no la cobra de nuevo.
export async function guardarPistaUsada(progresoId, desafioId, cuantas) {
  await pool.query(
    `INSERT INTO progreso_desafios (progreso_mision_id, desafio_id, pistas_usadas)
     VALUES ($1, $2, $3)
     ON CONFLICT (progreso_mision_id, desafio_id) DO UPDATE
        SET pistas_usadas = GREATEST(progreso_desafios.pistas_usadas, EXCLUDED.pistas_usadas)`,
    [progresoId, desafioId, cuantas]
  );
}

// Anota un intento en un desafio y actualiza el puntaje de la mision.
//
// Un desafio ya completado no vuelve a sumar: `completado` no se apaga nunca y
// los puntos se quedan en los que se habian ganado. Sin eso, repetir el pedido
// de una respuesta correcta sumaria dos veces.
//
// Son dos consultas y no una porque dentro de un mismo statement las partes no
// ven lo que escribieron las otras: la suma del total leeria los puntos de
// antes del INSERT. Recalcular el total desde la suma, en vez de irlo
// acumulando, hace que no pueda quedar desfasado.
export async function guardarIntento({ progresoId, desafioId, acerto, puntos }) {
  await pool.query(
    `INSERT INTO progreso_desafios
       (progreso_mision_id, desafio_id, intentos, completado, puntos_obtenidos, respondido_en)
     VALUES ($1, $2, 1, $3, $4, CASE WHEN $3 THEN NOW() END)
     ON CONFLICT (progreso_mision_id, desafio_id) DO UPDATE
        SET intentos = progreso_desafios.intentos + 1,
            completado = progreso_desafios.completado OR EXCLUDED.completado,
            puntos_obtenidos = CASE
              WHEN progreso_desafios.completado THEN progreso_desafios.puntos_obtenidos
              ELSE EXCLUDED.puntos_obtenidos
            END,
            respondido_en = COALESCE(progreso_desafios.respondido_en, EXCLUDED.respondido_en)`,
    [progresoId, desafioId, acerto, puntos]
  );

  await pool.query(
    `UPDATE progreso_misiones
        SET puntos_obtenidos = (SELECT COALESCE(sum(puntos_obtenidos), 0)
                                  FROM progreso_desafios
                                 WHERE progreso_mision_id = $1)
      WHERE id = $1`,
    [progresoId]
  );
}

// Cierra la mision en curso del visitante. Devuelve el id del progreso que
// cerro, o null si no tenia ninguna en curso.
//
// El filtro por estado tambien hace que avisar dos veces no mueva la fecha de
// finalizacion: la segunda no encuentra nada que actualizar.
export async function completarProgreso(usuarioId, misionId) {
  const { rows } = await pool.query(
    `UPDATE progreso_misiones
        SET estado = 'completada', finalizada_en = NOW()
      WHERE usuario_id = $1 AND mision_id = $2 AND estado = 'en_curso'
      RETURNING id`,
    [usuarioId, misionId]
  );
  return rows[0] ? Number(rows[0].id) : null;
}

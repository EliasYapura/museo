import { pool } from './db.js';
import { EVENTOS, registrar } from './eventos.js';

// Evaluador de insignias (VIS10).
//
// Corre al cerrar una mision: mira las insignias activas que el visitante
// todavia no tiene, calcula cuales cumple y se las otorga.
//
// Solo se evalua al terminar una mision, como pide el sprint. La consecuencia
// es que una condicion que se cumple a mitad del recorrido se paga al final,
// y que quien nunca termina una mision no gana ninguna insignia.

// Todas las misiones de la lista, completadas por este visitante.
//
// count(DISTINCT ...) y no count(*): volver a jugar una mision deja varias
// filas completadas de la misma, y sin el DISTINCT dos vueltas a una sola
// mision contarian como dos misiones distintas.
async function completoLasMisiones(usuarioId, misiones) {
  if (!Array.isArray(misiones) || misiones.length === 0) return false;

  const { rows } = await pool.query(
    `SELECT count(DISTINCT mision_id)::int AS cuantas
       FROM progreso_misiones
      WHERE usuario_id = $1 AND estado = 'completada' AND mision_id = ANY($2::bigint[])`,
    [usuarioId, misiones]
  );
  return rows[0].cuantas === new Set(misiones).size;
}

// Alguna vuelta completa a esa mision sin haber pedido una sola pista.
//
// Se mira vuelta por vuelta y no sumando todo: si la jugo una vez con pistas
// y otra sin ninguna, la segunda vale. La insignia habla de haberla resuelto
// limpia, no de no haber pedido pistas nunca.
async function completoSinPistas(usuarioId, misionId) {
  const { rows } = await pool.query(
    `SELECT 1
       FROM progreso_misiones pm
      WHERE pm.usuario_id = $1
        AND pm.mision_id = $2
        AND pm.estado = 'completada'
        AND COALESCE((SELECT sum(pd.pistas_usadas)
                        FROM progreso_desafios pd
                       WHERE pd.progreso_mision_id = pm.id), 0) = 0
      LIMIT 1`,
    [usuarioId, misionId]
  );
  return rows.length > 0;
}

// Cuantos desafios de encontrar la pieza resolvio a la primera.
//
// Se cuentan solo los tipos que se resuelven encontrando la pieza. En los que
// ademas preguntan algo, `intentos` mezcla escaneos errados con respuestas
// erradas (SIS03), asi que ahi un intento no significa "la encontro a la
// primera". En estos dos tipos si: el unico intento posible es el escaneo.
async function escaneosSinError(usuarioId) {
  const { rows } = await pool.query(
    `SELECT count(*)::int AS cuantos
       FROM progreso_desafios pd
       JOIN progreso_misiones pm ON pm.id = pd.progreso_mision_id
       JOIN desafios d ON d.id = pd.desafio_id
      WHERE pm.usuario_id = $1
        AND pd.completado = TRUE
        AND pd.intentos = 1
        AND d.tipo IN ('escaneo_objeto', 'busqueda_guiada')`,
    [usuarioId]
  );
  return rows[0].cuantos;
}

async function cumple(usuarioId, condicion) {
  switch (condicion?.tipo) {
    case 'misiones_completadas':
      return completoLasMisiones(usuarioId, condicion.misiones);
    case 'mision_sin_pistas':
      return completoSinPistas(usuarioId, condicion.mision);
    case 'escaneos_sin_error':
      return (await escaneosSinError(usuarioId)) >= condicion.cantidad;
    // Un tipo que este evaluador no conoce no se otorga. No deberia pasar: la
    // API solo deja guardar los tipos de arriba (ADM20).
    default:
      return false;
  }
}

// Otorga las insignias que el visitante acaba de ganar y las devuelve.
//
// Nunca falla hacia afuera: si algo sale mal evaluando, el visitante igual
// tiene que poder terminar su mision. Queda en el log del servidor y la
// insignia se le va a otorgar la proxima vez que cierre una, porque la
// condicion se vuelve a evaluar entera cada vez.
export async function otorgarInsignias(usuarioId, progresoMisionId) {
  try {
    // Solo las activas, con condicion cargada y que todavia no tenga. Las que
    // no tienen condicion no se pueden ganar y no vale la pena evaluarlas.
    const { rows: candidatas } = await pool.query(
      `SELECT id, nombre, descripcion, icono_url, condicion
         FROM insignias
        WHERE activa = TRUE
          AND condicion->>'tipo' IS NOT NULL
          AND id NOT IN (SELECT insignia_id FROM usuarios_insignias WHERE usuario_id = $1)
        ORDER BY nombre, id`,
      [usuarioId]
    );

    const ganadas = [];
    for (const insignia of candidatas) {
      if (!(await cumple(usuarioId, insignia.condicion))) continue;

      // ON CONFLICT DO NOTHING: la clave primaria es el par visitante-insignia,
      // asi que otorgarla dos veces no duplica nada. Con el RETURNING se sabe
      // si de verdad es nueva, que es lo que la app muestra como recien ganada.
      const { rows } = await pool.query(
        `INSERT INTO usuarios_insignias (usuario_id, insignia_id)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING
         RETURNING obtenida_en`,
        [usuarioId, insignia.id]
      );
      if (!rows[0]) continue;

      registrar({
        tipo: EVENTOS.INSIGNIA_OBTENIDA,
        usuarioId,
        progresoMisionId,
        datos: { insignia_id: insignia.id, nombre: insignia.nombre },
      });

      ganadas.push({
        id: insignia.id,
        nombre: insignia.nombre,
        descripcion: insignia.descripcion,
        icono_url: insignia.icono_url,
        obtenida_en: rows[0].obtenida_en,
      });
    }
    return ganadas;
  } catch (err) {
    console.error('No se pudieron evaluar las insignias:', err.message);
    return [];
  }
}

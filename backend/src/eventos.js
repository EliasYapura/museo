import { pool } from './db.js';

// Bitacora de lo que hace el visitante durante el recorrido (SIS02).
//
// Queda guardado en la tabla eventos y no se muestra en ningun lado: es lo que
// despues alimenta las estadisticas de uso del panel (ADM22).

// Los valores del enum tipo_evento de la base. Van como constantes para que un
// error de tipeo falle al importar y no al insertar, que es cuando ya nadie
// esta mirando.
export const EVENTOS = {
  MISION_INICIADA: 'mision_iniciada',
  DESAFIO_INICIADO: 'desafio_iniciado',
  RESPUESTA_CORRECTA: 'respuesta_correcta',
  RESPUESTA_INCORRECTA: 'respuesta_incorrecta',
  PISTA_USADA: 'pista_usada',
  OBJETO_ESCANEADO: 'objeto_escaneado',
  MISION_COMPLETADA: 'mision_completada',
  INSIGNIA_OBTENIDA: 'insignia_obtenida',
};

// Deja constancia de una interaccion. No devuelve nada y nunca falla.
//
// Eso ultimo es a proposito y es la regla de toda la bitacora: registrar es
// secundario frente a jugar. Si la base no acepta el INSERT, el visitante
// igual tiene que recibir que su respuesta estuvo bien. Por eso el error se
// atrapa aca y queda en el log del servidor, sin llegar a la ruta.
//
// Tampoco se espera el resultado: la base esta en Supabase y cada ida y vuelta
// se paga. Esperarla sumaria ese tiempo a cada respuesta del visitante para no
// enterarse de nada util, porque el que llama no puede hacer nada con la falla.
//
// usuarioId y progresoMisionId quedan en null mientras el visitante recorra sin
// cuenta. La tabla los admite nulos justamente por eso; se empiezan a llenar
// con SIS03, cuando haya progreso guardado al que atarlos.
export function registrar({
  tipo,
  desafioId = null,
  usuarioId = null,
  progresoMisionId = null,
  datos = {},
}) {
  pool
    .query(
      `INSERT INTO eventos (usuario_id, progreso_mision_id, desafio_id, tipo, datos)
       VALUES ($1, $2, $3, $4, $5::jsonb)`,
      [usuarioId, progresoMisionId, desafioId, tipo, JSON.stringify(datos)]
    )
    .catch((err) => {
      console.error(`No se pudo registrar el evento ${tipo}:`, err.message);
    });
}

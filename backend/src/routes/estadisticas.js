import { Router } from 'express';
import { pool } from '../db.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { esIdValido } from '../validaciones/id.js';

// Estadisticas de uso de las misiones (ADM22).
//
// Router propio y no una ruta dentro de /misiones: ahi /misiones/estadisticas
// chocaria con GET /misiones/:id, que mira el id antes que nada y responderia
// 404.
export const estadisticasRouter = Router();

estadisticasRouter.use(verificarToken, requerirRol('administrador'));

// --- De donde sale cada numero ---------------------------------------------
//
// Hay dos fuentes y NO dicen lo mismo, asi que cada dato sale de la que
// corresponde y la respuesta aclara cual es:
//
// - La bitacora (eventos) registra a todo el mundo, con cuenta y sin cuenta.
//   De aca salen las participaciones, los aciertos, los fallos y las pistas.
// - El progreso guardado (progreso_misiones) existe solo para quien tiene
//   cuenta. De aca salen los tiempos, que es lo unico que no se puede sacar de
//   la bitacora.
//
// La diferencia no es un detalle: medido sobre los datos que hay, una mision
// con 13 participaciones en la bitacora tiene 3 progresos, porque 10 fueron de
// visitantes sin cuenta. Contar los tiempos y las participaciones de la misma
// fuente daria un tablero que se contradice solo.
//
// Existe la vista v_estadisticas_misiones, del diseno original, pero cuenta las
// participaciones desde el progreso: en un museo, donde casi nadie se crea una
// cuenta, se perderia la mayor parte. Por eso no se usa.

// El id de la mision en los eventos de inicio y de fin viaja en datos, porque
// esos eventos no tienen progreso cuando el visitante no tiene cuenta.
//
// Se compara como texto (m.id::text) y no casteando el JSON a bigint: si
// alguna fila vieja tuviera ahi algo que no es un numero, el cast haria fallar
// toda la consulta.
const cuentaDeEventosDeMision = (tipo) => `
  (SELECT count(*)::int FROM eventos e
    WHERE e.tipo = '${tipo}' AND e.datos->>'mision_id' = m.id::text)`;

// Estos eventos si traen desafio_id siempre, con cuenta o sin ella, asi que se
// llega a la mision por el desafio.
const cuentaPorDesafio = (condicion) => `
  (SELECT count(*)::int FROM eventos e
     JOIN desafios d ON d.id = e.desafio_id
    WHERE d.mision_id = m.id AND ${condicion})`;

// Un fallo es no dar con la respuesta o escanear la pieza equivocada. Los dos
// son el visitante intentando y no logrando, que es lo que interesa medir.
const ES_FALLO = `(e.tipo = 'respuesta_incorrecta'
                   OR (e.tipo = 'objeto_escaneado' AND e.datos->>'correcto' = 'false'))`;
const ES_ACIERTO = `(e.tipo = 'respuesta_correcta'
                     OR (e.tipo = 'objeto_escaneado' AND e.datos->>'correcto' = 'true'))`;

// Una participacion que figura terminada mas de un dia despues de empezar no
// mide cuanto tarda la gente: mide que alguien dejo la app abierta y volvio al
// otro dia. Se excluye del tiempo y se cuenta aparte, para que el tablero
// pueda decir que existen en lugar de taparlas.
const LIMITE_RAZONABLE = "INTERVAL '1 day'";

const COMPLETADAS_MEDIBLES = `pm.estado = 'completada'
                              AND pm.finalizada_en IS NOT NULL
                              AND pm.finalizada_en - pm.iniciada_en < ${LIMITE_RAZONABLE}`;

// La mediana y no el promedio: con el promedio, una sola participacion que
// quedo abierta mucho tiempo arruina el numero de la mision entera. Aun
// descartando las de mas de un dia, la mediana aguanta mejor los casos raros.
const MINUTOS = `
  (SELECT round(percentile_cont(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (pm.finalizada_en - pm.iniciada_en)) / 60.0
          )::numeric, 1)::float8
     FROM progreso_misiones pm
    WHERE pm.mision_id = m.id AND ${COMPLETADAS_MEDIBLES})`;

const CUENTA_MEDIBLES = `
  (SELECT count(*)::int FROM progreso_misiones pm
    WHERE pm.mision_id = m.id AND ${COMPLETADAS_MEDIBLES})`;

const CUENTA_ABIERTAS_DE_MAS = `
  (SELECT count(*)::int FROM progreso_misiones pm
    WHERE pm.mision_id = m.id AND pm.estado = 'completada'
      AND pm.finalizada_en IS NOT NULL
      AND pm.finalizada_en - pm.iniciada_en >= ${LIMITE_RAZONABLE})`;

// GET /estadisticas — el tablero: un resumen y una fila por mision.
estadisticasRouter.get('/', async (req, res) => {
  // El resumen se cuenta sobre toda la bitacora y no sumando las filas de
  // abajo: hay eventos de misiones que despues se archivaron, y sumar las
  // filas visibles daria un total que no coincide con lo que paso de verdad.
  const resumen = await pool.query(
    `SELECT (SELECT count(*)::int FROM eventos WHERE tipo = 'mision_iniciada') AS participaciones,
            (SELECT count(*)::int FROM eventos WHERE tipo = 'mision_completada') AS completadas,
            (SELECT count(*)::int FROM eventos WHERE tipo = 'pista_usada') AS pistas,
            (SELECT count(*)::int FROM eventos e WHERE ${ES_FALLO}) AS fallos,
            (SELECT count(*)::int FROM eventos e WHERE ${ES_ACIERTO}) AS aciertos,
            (SELECT count(*)::int FROM eventos WHERE usuario_id IS NULL
               AND tipo = 'mision_iniciada') AS participaciones_sin_cuenta,
            (SELECT min(ocurrido_en) FROM eventos) AS desde`
  );

  const { rows } = await pool.query(
    `SELECT m.id, m.nombre, m.activa,
            ${cuentaDeEventosDeMision('mision_iniciada')} AS participaciones,
            ${cuentaDeEventosDeMision('mision_completada')} AS completadas,
            ${cuentaPorDesafio(ES_FALLO)} AS fallos,
            ${cuentaPorDesafio("e.tipo = 'pista_usada'")} AS pistas,
            ${MINUTOS} AS minutos_mediana,
            ${CUENTA_MEDIBLES} AS participaciones_medidas,
            ${CUENTA_ABIERTAS_DE_MAS} AS participaciones_sin_medir
       FROM misiones m
      WHERE m.archivada = FALSE
      ORDER BY participaciones DESC, m.nombre, m.id`
  );

  return res.json({ resumen: resumen.rows[0], misiones: rows });
});

// GET /estadisticas/misiones/:id — el detalle de una mision, desafio por
// desafio.
//
// Es la parte que dice que corregir: un desafio con muchos fallos y muchas
// pistas es un desafio mal escrito. El resto del tablero describe, este
// senala.
estadisticasRouter.get('/misiones/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) {
    return res.status(404).json({ error: 'La misión no existe' });
  }

  const mision = await pool.query(
    `SELECT m.id, m.nombre, m.activa, m.duracion_estimada,
            ${cuentaDeEventosDeMision('mision_iniciada')} AS participaciones,
            ${cuentaDeEventosDeMision('mision_completada')} AS completadas,
            ${cuentaPorDesafio(ES_FALLO)} AS fallos,
            ${cuentaPorDesafio("e.tipo = 'pista_usada'")} AS pistas,
            ${MINUTOS} AS minutos_mediana,
            ${CUENTA_MEDIBLES} AS participaciones_medidas,
            ${CUENTA_ABIERTAS_DE_MAS} AS participaciones_sin_medir
       FROM misiones m
      WHERE m.id = $1 AND m.archivada = FALSE`,
    [req.params.id]
  );
  if (!mision.rows[0]) return res.status(404).json({ error: 'La misión no existe' });

  const desafios = await pool.query(
    `SELECT d.id, d.orden, d.tipo, d.enunciado,
            (SELECT count(*)::int FROM eventos e
              WHERE e.desafio_id = d.id AND ${ES_ACIERTO}) AS aciertos,
            (SELECT count(*)::int FROM eventos e
              WHERE e.desafio_id = d.id AND ${ES_FALLO}) AS fallos,
            (SELECT count(*)::int FROM eventos e
              WHERE e.desafio_id = d.id AND e.tipo = 'pista_usada') AS pistas
       FROM desafios d
      WHERE d.mision_id = $1
      ORDER BY d.orden, d.id`,
    [req.params.id]
  );

  return res.json({ mision: mision.rows[0], desafios: desafios.rows });
});

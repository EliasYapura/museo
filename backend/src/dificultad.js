// Calculo de la dificultad de una mision (ADM03).
//
// La dificultad no la elige nadie: se deduce de la mision. Antes era un
// selector en el formulario, y el resultado era que no significaba nada —
// habia misiones de dos preguntas marcadas como dificiles y misiones de cinco
// desafios marcadas como faciles. Un dato que el administrador elige a mano no
// tiene escala: cada uno pone lo que le parece.
//
// Se calcula en el servidor y nunca en la app, por el mismo motivo que los
// puntos y las pistas: es un dato que la app muestra, no uno que informa.

/// Cuanto cuesta resolver un desafio de cada tipo.
///
/// El orden sale de cuanto trabajo le da al visitante, no de cuanto costo
/// programarlo: la opcion multiple tiene la respuesta a la vista, la respuesta
/// corta hay que escribirla, el escaneo obliga a encontrar la pieza en la sala
/// y la busqueda guiada obliga a encontrarla sin que le digan cual es.
export const PESOS = {
  pregunta_opcion_multiple: 1,
  respuesta_corta: 2,
  escaneo_objeto: 2,
  busqueda_guiada: 3,
};

/// Cada cuantos minutos de recorrido se suma un punto.
export const MINUTOS_POR_PUNTO = 15;

/// Hasta donde llega cada nivel. Un puntaje mayor que UMBRAL_MEDIA es dificil.
export const UMBRAL_FACIL = 4;
export const UMBRAL_MEDIA = 8;

/// El CASE que traduce el tipo de un desafio a su peso, armado desde PESOS
/// para que los numeros vivan en un solo lugar. Los tipos y los pesos son
/// constantes de este modulo, no datos de nadie, asi que interpolarlos es
/// seguro.
const CASO_PESOS = Object.entries(PESOS)
  .map(([tipo, peso]) => `WHEN '${tipo}' THEN ${peso}`)
  .join(' ');

/// Recalcula y guarda la dificultad de una mision.
///
/// Va en una sola sentencia: lee los desafios, saca el puntaje y escribe el
/// nivel sin pasar por JavaScript en el medio, asi que no hay ventana para que
/// alguien agregue un desafio entre la lectura y la escritura y el valor
/// guardado quede viejo.
///
/// Solo escribe si el nivel cambio. La tabla misiones tiene un trigger que
/// pone actualizada_en en cada UPDATE, asi que escribir el mismo valor diria
/// que la mision se modifico cuando no paso nada. El SELECT final lee del CTE
/// y no de la tabla, por eso devuelve el nivel igual aunque no se haya
/// escrito; un CTE que modifica datos se ejecuta siempre, lo lea alguien o no.
///
/// Una mision sin desafios solo suma por duracion, asi que queda facil. No
/// importa: sin desafios no se puede publicar (ADM04), y nadie la ve.
///
/// Devuelve la dificultad que quedo, o null si la mision no existe.
export async function recalcularDificultad(misionId, cliente) {
  const { rows } = await cliente.query(
    `WITH puntajes AS (
       SELECT m.id,
              m.duracion_estimada::numeric / $4
              + COALESCE(SUM(CASE d.tipo ${CASO_PESOS} END), 0) AS puntaje
       FROM misiones m
       LEFT JOIN desafios d ON d.mision_id = m.id
       WHERE m.id = $1
       GROUP BY m.id
     ), calculo AS (
       SELECT id,
              (CASE
                 WHEN puntaje <= $2 THEN 'facil'
                 WHEN puntaje <= $3 THEN 'media'
                 ELSE 'dificil'
               END)::dificultad_mision AS nivel
       FROM puntajes
     ), escritura AS (
       UPDATE misiones
       SET dificultad = calculo.nivel
       FROM calculo
       WHERE misiones.id = calculo.id
         AND misiones.dificultad IS DISTINCT FROM calculo.nivel
       RETURNING misiones.id
     )
     SELECT nivel FROM calculo`,
    [misionId, UMBRAL_FACIL, UMBRAL_MEDIA, MINUTOS_POR_PUNTO]
  );
  return rows[0]?.nivel ?? null;
}

/// La misma cuenta, en JavaScript, para explicarla sin tocar la base.
/// La usa la prueba automatica; el camino real es recalcularDificultad.
export function calcularDificultad({ duracionEstimada, tipos }) {
  const puntaje =
    duracionEstimada / MINUTOS_POR_PUNTO +
    tipos.reduce((total, tipo) => total + (PESOS[tipo] ?? 0), 0);
  if (puntaje <= UMBRAL_FACIL) return 'facil';
  if (puntaje <= UMBRAL_MEDIA) return 'media';
  return 'dificil';
}

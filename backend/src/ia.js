// Redaccion de desafios con ayuda de IA (ADM27).
//
// La llamada vive en el servidor y no en la app a proposito: la clave de la
// API nunca sale de aca. Si la llamada la hiciera el telefono, la clave
// tendria que viajar dentro del APK, de donde se puede extraer.
//
// Lo que devuelve es un BORRADOR: se carga en el formulario y lo guarda el
// administrador si le gusta. La IA propone, la persona decide. Nada de esto
// toca la base.

import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';
import { zodOutputFormat } from '@anthropic-ai/sdk/helpers/zod';
import { config } from './config.js';
import { MAXIMO_OPCIONES, MINIMO_OPCIONES } from './validaciones/desafio.js';

// Haiku alcanza de sobra para redactar un acertijo a partir de datos que ya le
// damos nosotros: no tiene que razonar nada dificil, tiene que escribir bien.
const MODELO = 'claude-haiku-5-5';

// Los tipos que tiene sentido redactar. Escaneo y busqueda guiada no llevan
// pregunta ni respuesta —se resuelven encontrando la pieza—, asi que para esos
// la IA solo escribe la consigna.
export const TIPOS_REDACTABLES = [
  'pregunta_opcion_multiple',
  'respuesta_corta',
  'escaneo_objeto',
  'busqueda_guiada',
];

// La forma exacta que tienen que tener los campos del formulario. Se pide como
// salida estructurada y no como texto libre: asi la respuesta entra derecho en
// el formulario, sin parsear prosa ni adivinar donde empieza cada cosa.
const BorradorOpcionMultiple = z.object({
  enunciado: z.string(),
  opciones: z.array(z.string()).min(MINIMO_OPCIONES).max(MAXIMO_OPCIONES),
  respuesta_correcta: z.string(),
  pista: z.string(),
});

const BorradorRespuestaCorta = z.object({
  enunciado: z.string(),
  respuesta_correcta: z.string(),
  pista: z.string(),
});

const BorradorSoloConsigna = z.object({
  enunciado: z.string(),
  pista: z.string(),
});

function esquemaDe(tipo) {
  if (tipo === 'pregunta_opcion_multiple') return BorradorOpcionMultiple;
  if (tipo === 'respuesta_corta') return BorradorRespuestaCorta;
  return BorradorSoloConsigna;
}

// Lo que el modelo tiene que saber del oficio. Va en el system y no en el
// mensaje: es lo que no cambia entre llamadas.
const INSTRUCCIONES = `Redactás desafíos para «Exploradores del Museo», una app con la que los visitantes del Museo de La Plata recorren las salas resolviendo consignas frente a las piezas reales.

Cómo tiene que ser lo que escribís:

- En español rioplatense, de vos. Para visitantes de 8 a 14 años acompañados por adultos.
- El enunciado se lee PARADO FRENTE A LA PIEZA, así que puede pedir que la miren, que cuenten algo, que lean el cartel.
- Se responde con lo que la pieza o su cartel muestran. Nunca pidas datos que haya que buscar en el teléfono.
- Usá únicamente los datos de la pieza que te paso. Si no alcanzan para una pregunta honesta, escribí una consigna de observación en vez de inventar un dato.
- Nada de signos de pregunta de apertura olvidados ni mayúsculas sostenidas.
- La pista ayuda a pensar sin regalar la respuesta: nunca la contiene ni la nombra.
- Enunciado de 1 a 3 oraciones. Pista de una.

Para opción múltiple: las opciones incorrectas tienen que ser verosímiles —del mismo tipo y del mismo orden de magnitud que la correcta—, y la correcta tiene que figurar entre las opciones, escrita igual.

Para respuesta corta: la respuesta tiene que ser una palabra o un número, no una frase.

Para escaneo de pieza o búsqueda guiada: no hay pregunta. El enunciado dice a qué pieza hay que llegar y cómo reconocerla, sin nombrar su código.`;

// Los datos de la pieza, en texto, para el mensaje.
function describirPieza(pieza) {
  const lineas = [`Pieza: ${pieza.nombre}`];
  if (pieza.sala) lineas.push(`Sala: ${pieza.sala}`);
  if (pieza.categoria) lineas.push(`Categoría: ${pieza.categoria}`);
  if (pieza.descripcion) lineas.push(`Descripción: ${pieza.descripcion}`);
  if (pieza.dato_clave) lineas.push(`Dato clave del cartel: ${pieza.dato_clave}`);
  return lineas.join('\n');
}

const COMO_SE_LLAMA_EL_TIPO = {
  pregunta_opcion_multiple: 'una pregunta de opción múltiple',
  respuesta_corta: 'una pregunta de respuesta corta',
  escaneo_objeto: 'una consigna para llegar a la pieza y escanear su código',
  busqueda_guiada: 'una consigna de búsqueda guiada hasta la pieza',
};

// Se crea una sola vez, al primer uso, y no al importar el modulo: asi el
// servidor levanta igual sin la clave y solo falla esta ruta.
let cliente = null;

export class ErrorDeIa extends Error {
  constructor(mensaje, estado = 502) {
    super(mensaje);
    this.estado = estado;
  }
}

/// Redacta un borrador de desafio para una pieza. No guarda nada.
///
/// `pieza` son las columnas del objeto; `tipo` es uno de TIPOS_REDACTABLES;
/// `indicacion` es un pedido opcional del administrador ("que hable del
/// tamaño", "más difícil").
export async function redactarDesafio({ pieza, tipo, indicacion }) {
  if (!config.anthropicApiKey) {
    throw new ErrorDeIa(
      'Falta configurar la clave de la API de Anthropic en el servidor (ANTHROPIC_API_KEY).',
      503
    );
  }

  cliente ??= new Anthropic({ apiKey: config.anthropicApiKey });

  const pedido = [
    `Escribí ${COMO_SE_LLAMA_EL_TIPO[tipo]} sobre esta pieza del museo.`,
    '',
    describirPieza(pieza),
  ];
  if (indicacion) pedido.push('', `Indicación del administrador: ${indicacion}`);

  let respuesta;
  try {
    respuesta = await cliente.messages.parse({
      model: MODELO,
      max_tokens: 2000,
      system: INSTRUCCIONES,
      messages: [{ role: 'user', content: pedido.join('\n') }],
      output_config: { format: zodOutputFormat(esquemaDe(tipo)) },
    });
  } catch (err) {
    // 401 es clave mal pegada o revocada; 400 por saldo tambien llega aca.
    if (err?.status === 401) {
      throw new ErrorDeIa('La clave de la API de Anthropic no es válida.', 503);
    }
    if (err?.status === 429) {
      throw new ErrorDeIa('La API de Anthropic está saturada. Probá de nuevo en un momento.', 503);
    }
    throw new ErrorDeIa('No se pudo redactar el desafío. Probá de nuevo.');
  }

  // parsed_output viene en null si el modelo no respetó el formato.
  if (!respuesta.parsed_output) {
    throw new ErrorDeIa('La respuesta no vino con el formato esperado. Probá de nuevo.');
  }

  return respuesta.parsed_output;
}

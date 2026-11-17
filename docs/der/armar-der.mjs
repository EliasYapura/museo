// Dibuja el diagrama entidad-relación leyendo docs/schema.sql.
//
//   node docs/der/armar-der.mjs
//
// Escribe docs/Relaciones_Base_de_Datos.pdf. Hay que correrlo cada vez que
// cambie el esquema: el diagrama anterior era una imagen hecha aparte, y por
// eso terminó mostrando una tabla que ya no existía y sin una que sí.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { leerEsquema } from './leer-esquema.mjs';
import { Pdf, medir } from './pdf.mjs';
import { Svg } from './svg.mjs';

const AQUI = dirname(fileURLToPath(import.meta.url));
const SALIDA = process.argv[2] ?? join(AQUI, '..', 'Relaciones_Base_de_Datos.pdf');

const { tablas, relaciones } = leerEsquema();

// --- los grupos, que son los que dan el color -----------------------------
//
// Mismas familias que tenía el diagrama anterior: ayudan a leerlo más que el
// orden alfabético, porque las tablas de un mismo grupo se usan juntas.
const GRUPOS = [
  { nombre: 'Contenido del museo', color: [122, 92, 54], suave: [247, 241, 230] },
  { nombre: 'Diseño de la experiencia', color: [140, 106, 58], suave: [250, 244, 232] },
  { nombre: 'Gamificación', color: [108, 72, 108], suave: [245, 238, 245] },
  { nombre: 'Usuarios y progreso', color: [58, 86, 122], suave: [235, 241, 248] },
  { nombre: 'Analítica', color: [70, 70, 70], suave: [240, 240, 240] },
];

const DE_QUE_GRUPO = {
  salas: 0, categorias: 0, objetos: 0,
  misiones: 1, desafios: 1, pistas: 1,
  insignias: 2, usuarios_insignias: 2,
  usuarios: 3, progreso_misiones: 3, progreso_desafios: 3, valoraciones: 3,
  eventos: 4,
};

// --- la grilla ------------------------------------------------------------
//
// Las columnas están puestas para que la mayoría de las flechas vaya entre
// columnas vecinas: las que apuntan a usuarios y a misiones son casi la mitad
// de todas, así que esas dos van al medio.
const COLUMNAS = [
  ['salas', 'categorias', 'pistas'],
  ['objetos', 'desafios'],
  ['misiones', 'insignias'],
  ['usuarios', 'usuarios_insignias', 'valoraciones'],
  ['progreso_misiones', 'progreso_desafios', 'eventos'],
];

const MARGEN = 34;
const ARRIBA = 96;
const ANCHO_CAJA = 186;
const SEPARACION_X = 36;
const SEPARACION_Y = 26;
const ALTO_TITULO = 19;
const ALTO_FILA = 13.5;

// --- se calcula dónde va cada tabla ---------------------------------------
const porNombre = new Map(tablas.map((t) => [t.nombre, t]));
const cajas = new Map();

COLUMNAS.forEach((columna, i) => {
  let y = ARRIBA;
  for (const nombre of columna) {
    const tabla = porNombre.get(nombre);
    if (!tabla) throw new Error(`la columna nombra una tabla que no está en el esquema: ${nombre}`);
    const alto = ALTO_TITULO + tabla.columnas.length * ALTO_FILA + 6;
    cajas.set(nombre, {
      tabla,
      columna: i,
      x: MARGEN + i * (ANCHO_CAJA + SEPARACION_X),
      y,
      ancho: ANCHO_CAJA,
      alto,
      grupo: GRUPOS[DE_QUE_GRUPO[nombre]],
    });
    y += alto + SEPARACION_Y;
  }
});

// Ninguna tabla puede quedar sin dibujar.
for (const t of tablas) {
  if (!cajas.has(t.nombre)) throw new Error(`la tabla ${t.nombre} no está en ninguna columna`);
}

const anchoPagina = MARGEN * 2 + COLUMNAS.length * ANCHO_CAJA + (COLUMNAS.length - 1) * SEPARACION_X;
const altoPagina = Math.max(...[...cajas.values()].map((c) => c.y + c.alto)) + 58;

// Se dibuja una sola vez en los dos formatos a la vez: doc reparte cada orden
// al PDF y al SVG. Dibujarlo dos veces sería la forma segura de que un día
// uno quede distinto del otro.
const pdf = new Pdf(Math.round(anchoPagina), Math.round(altoPagina));
const svg = new Svg(Math.round(anchoPagina), Math.round(altoPagina));
const doc = {
  rectangulo: (...a) => (pdf.rectangulo(...a), svg.rectangulo(...a)),
  camino: (...a) => (pdf.camino(...a), svg.camino(...a)),
  circulo: (...a) => (pdf.circulo(...a), svg.circulo(...a)),
  texto: (...a) => (svg.texto(...a), pdf.texto(...a)),
};

// --- encabezado -----------------------------------------------------------
doc.texto('Exploradores del Museo — Modelo de datos', MARGEN, 38, { tamanio: 16, negrita: true });
doc.texto(
  `PostgreSQL · ${tablas.length} tablas · ${relaciones.length} claves foráneas · generado desde schema.sql`,
  MARGEN,
  54,
  { tamanio: 9, color: [110, 110, 110] }
);

// La referencia de colores, en una fila.
let xRef = MARGEN;
for (const grupo of GRUPOS) {
  doc.rectangulo(xRef, 68, 10, 10, { relleno: grupo.color });
  doc.texto(grupo.nombre, xRef + 15, 77, { tamanio: 8.5, color: [80, 80, 80] });
  xRef += 15 + medir(grupo.nombre, 8.5) + 22;
}
doc.texto('PK clave primaria · FK clave foránea · UQ valor único', anchoPagina - MARGEN, 77, {
  tamanio: 8.5,
  color: [110, 110, 110],
  alineacion: 'derecha',
});

// --- las relaciones -------------------------------------------------------
//
// Se dibujan antes que las cajas, así los extremos quedan prolijos contra el
// borde: la caja tapa el último tramo. Lo que no puede pasar es que tape una
// línea entera, y por eso ninguna cruza una columna por el medio.
//
// Los caminos van por los pasillos: las franjas verticales vacías que quedan
// entre columna y columna, y una banda horizontal abajo de todo. Una línea
// derecha entre dos tablas lejanas se metería por detrás de las cajas del
// medio y la relación desaparecería del dibujo.
const pasillo = (i) => MARGEN + i * (ANCHO_CAJA + SEPARACION_X) - SEPARACION_X / 2;
const bandaDeAbajo = Math.max(...[...cajas.values()].map((c) => c.y + c.alto)) + 16;

const llegadas = new Map();
let carrilesAbajo = 0;

for (const rel of relaciones) {
  const origen = cajas.get(rel.desde);
  const destino = cajas.get(rel.hasta);
  if (!origen || !destino) continue;

  // La fila exacta de la columna que apunta, para que la línea salga de ahí.
  const fila = origen.tabla.columnas.findIndex((c) => c.nombre === rel.columna);
  const yOrigen = origen.y + ALTO_TITULO + fila * ALTO_FILA + ALTO_FILA / 2 + 2;

  if (origen === destino) {
    // Una tabla que se apunta a sí misma: un lacito al costado.
    const x = origen.x + origen.ancho;
    doc.camino(
      [
        [x, yOrigen],
        [x + 13, yOrigen],
        [x + 13, origen.y + 9],
        [x - 12, origen.y + 9],
      ],
      { punteada: true, color: [150, 150, 150] }
    );
    doc.circulo(x - 12, origen.y + 9, 2.2, origen.grupo.color);
    continue;
  }

  // Las que llegan a la misma tabla entran a distinta altura, si no se
  // superponen y parece una sola.
  const cuantas = (llegadas.get(rel.hasta) ?? 0) + 1;
  llegadas.set(rel.hasta, cuantas);
  const yDestino = destino.y + 10 + cuantas * 9;

  const distancia = Math.abs(destino.columna - origen.columna);
  const haciaLaDerecha = destino.columna > origen.columna;
  let puntos;

  if (distancia === 0) {
    // Vecinas en la misma columna: se sale y se entra por la derecha, y el
    // tramo vertical va por el pasillo de al lado.
    const x = origen.x + origen.ancho;
    const canal = pasillo(origen.columna + 1);
    puntos = [
      [x, yOrigen],
      [canal, yOrigen],
      [canal, yDestino],
      [x, yDestino],
    ];
    doc.circulo(x, yDestino, 2.2, destino.grupo.color);
  } else if (distancia === 1) {
    // Columnas vecinas: el codo entra justo en el pasillo que las separa.
    const xSalida = haciaLaDerecha ? origen.x + origen.ancho : origen.x;
    const xLlegada = haciaLaDerecha ? destino.x : destino.x + destino.ancho;
    const canal = pasillo(haciaLaDerecha ? destino.columna : origen.columna);
    puntos = [
      [xSalida, yOrigen],
      [canal, yOrigen],
      [canal, yDestino],
      [xLlegada, yDestino],
    ];
    doc.circulo(xLlegada, yDestino, 2.2, destino.grupo.color);
  } else {
    // Lejanas: se baja por el pasillo de al lado, se cruza por abajo de todo
    // y se sube por el pasillo del destino. Es más largo, pero se ve entero.
    const carril = bandaDeAbajo + carrilesAbajo++ * 7;
    const xSalida = haciaLaDerecha ? origen.x + origen.ancho : origen.x;
    const xLlegada = haciaLaDerecha ? destino.x : destino.x + destino.ancho;
    const canalOrigen = pasillo(haciaLaDerecha ? origen.columna + 1 : origen.columna);
    const canalDestino = pasillo(haciaLaDerecha ? destino.columna : destino.columna + 1);
    puntos = [
      [xSalida, yOrigen],
      [canalOrigen, yOrigen],
      [canalOrigen, carril],
      [canalDestino, carril],
      [canalDestino, yDestino],
      [xLlegada, yDestino],
    ];
    doc.circulo(xLlegada, yDestino, 2.2, destino.grupo.color);
  }

  doc.camino(puntos, { color: [150, 150, 150] });
}

// --- las cajas ------------------------------------------------------------
for (const [nombre, caja] of cajas) {
  doc.rectangulo(caja.x, caja.y, caja.ancho, caja.alto, {
    relleno: caja.grupo.suave,
    borde: [190, 190, 190],
  });
  doc.rectangulo(caja.x, caja.y, caja.ancho, ALTO_TITULO, { relleno: caja.grupo.color });
  doc.texto(nombre, caja.x + caja.ancho / 2 - medir(nombre, 9.5) / 2, caja.y + 13, {
    tamanio: 9.5,
    negrita: true,
    color: [255, 255, 255],
  });

  let y = caja.y + ALTO_TITULO + 10;
  for (const col of caja.tabla.columnas) {
    const marcas = [col.pk && 'PK', col.fk && 'FK', col.unico && 'UQ'].filter(Boolean).join('+');
    if (marcas) {
      doc.texto(marcas, caja.x + 7, y, { tamanio: 6.5, negrita: true, color: caja.grupo.color });
    }
    // El nombre arranca después de la marca más larga que puede haber,
    // PK+FK: si no, en usuarios_insignias quedaban pegados.
    doc.texto(col.nombre, caja.x + 35, y, {
      tamanio: 8,
      negrita: col.pk,
      color: col.pk ? [20, 20, 20] : [55, 55, 55],
    });
    doc.texto(col.tipo, caja.x + caja.ancho - 7, y, {
      tamanio: 6.5,
      color: [150, 150, 150],
      alineacion: 'derecha',
    });
    y += ALTO_FILA;
  }
}

const bytesPdf = pdf.guardar(SALIDA);
const rutaSvg = SALIDA.replace(/\.pdf$/i, '.svg');
const bytesSvg = svg.guardar(rutaSvg);

console.log(`escrito: ${SALIDA} (${bytesPdf} bytes)`);
console.log(`escrito: ${rutaSvg} (${bytesSvg} bytes)`);
console.log(
  `${tablas.length} tablas, ${relaciones.length} relaciones, ` +
    `${Math.round(anchoPagina)}x${Math.round(altoPagina)} puntos`
);

// --- se revisa lo que se acaba de escribir --------------------------------
//
// El diagrama anterior era una imagen y no habia forma de comprobar que
// dijera lo que tenia que decir: habia que abrirlo y mirarlo. Este lleva el
// texto adentro, asi que se puede leer de vuelta y confirmar que esten las
// trece tablas y todas sus columnas.
const escrito = readFileSync(SALIDA, 'latin1');
const faltan = [];
for (const tabla of tablas) {
  if (!escrito.includes(`(${tabla.nombre})`)) faltan.push(tabla.nombre);
  for (const col of tabla.columnas) {
    if (!escrito.includes(`(${col.nombre})`)) faltan.push(`${tabla.nombre}.${col.nombre}`);
  }
}

if (faltan.length > 0) {
  console.error(`\nFALLA: el PDF no contiene ${faltan.length} nombres: ${faltan.join(', ')}`);
  process.exit(1);
}
console.log('revisado: los nombres de las 13 tablas y sus columnas están en el PDF');

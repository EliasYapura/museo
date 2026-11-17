// Lo mínimo de PDF para dibujar el diagrama: rectángulos, líneas y texto.
//
// Escrito a mano y sin bibliotecas a propósito. Un PDF con formas y texto es
// un archivo de texto con una tabla de posiciones al final, y así el generador
// se corre con `node` pelado, sin instalar nada. Las otras herramientas de
// docs/ arrastraban pdfkit, que son 80 paquetes para dibujar cuadrados.
//
// Usa Helvetica, que todo lector de PDF ya trae, así que no hay que incrustar
// ninguna fuente. De paso el texto queda seleccionable y se puede extraer para
// comprobarlo, que es lo que no se podía hacer con el diagrama anterior: era
// una imagen.

import { writeFileSync } from 'node:fs';

// Anchos de Helvetica en milésimas de unidad, de su AFM. Hacen falta para
// alinear a la derecha y para medir los cuadros: sin esto habría que adivinar.
const ANCHOS = {
  ' ': 278, '!': 278, '"': 355, '#': 556, '$': 556, '%': 889, '&': 667, "'": 191,
  '(': 333, ')': 333, '*': 389, '+': 584, ',': 278, '-': 333, '.': 278, '/': 278,
  '0': 556, '1': 556, '2': 556, '3': 556, '4': 556, '5': 556, '6': 556, '7': 556,
  '8': 556, '9': 556, ':': 278, ';': 278, '<': 584, '=': 584, '>': 584, '?': 556,
  '@': 1015, A: 667, B: 667, C: 722, D: 722, E: 667, F: 611, G: 778, H: 722,
  I: 278, J: 500, K: 667, L: 556, M: 833, N: 722, O: 778, P: 667, Q: 778, R: 722,
  S: 667, T: 611, U: 722, V: 667, W: 944, X: 667, Y: 667, Z: 611,
  '[': 278, '\\': 278, ']': 278, '^': 469, _: 556, '`': 333,
  a: 556, b: 556, c: 500, d: 556, e: 556, f: 278, g: 556, h: 556, i: 222, j: 222,
  k: 500, l: 222, m: 833, n: 556, o: 556, p: 556, q: 556, r: 333, s: 500, t: 278,
  u: 556, v: 500, w: 722, x: 500, y: 500, z: 500,
  '{': 334, '|': 260, '}': 334, '~': 584,
};

/// Cuánto mide un texto. Los acentos y la ñ cuentan como su letra sin acento,
/// que en Helvetica miden lo mismo.
export function medir(texto, tamanio) {
  let milesimas = 0;
  for (const c of texto) {
    const base = c.normalize('NFD')[0];
    milesimas += ANCHOS[base] ?? ANCHOS[c] ?? 556;
  }
  return (milesimas / 1000) * tamanio;
}

// Los caracteres que no entran en latin1 pero sí en WinAnsi, que es la
// codificación con la que se declara la fuente. Sin esto, la raya del título
// se convertía en un byte de control y desaparecía: el texto quedaba con un
// hueco y no se notaba hasta mirar el PDF.
const WINANSI = {
  '—': 0x97,
  '–': 0x96,
  '‘': 0x91,
  '’': 0x92,
  '“': 0x93,
  '”': 0x94,
  '•': 0x95,
  '…': 0x85,
  '€': 0x80,
};

const escapar = (texto) =>
  [...texto]
    .map((c) => (WINANSI[c] ? String.fromCharCode(WINANSI[c]) : c))
    .join('')
    .replace(/\\/g, '\\\\')
    .replace(/\(/g, '\\(')
    .replace(/\)/g, '\\)');

export class Pdf {
  constructor(ancho, alto) {
    this.ancho = ancho;
    this.alto = alto;
    this.ordenes = [];
  }

  /// El PDF tiene el origen abajo a la izquierda y es más cómodo pensar de
  /// arriba hacia abajo, así que las coordenadas se dan desde arriba y se dan
  /// vuelta acá.
  y(desdeArriba) {
    return this.alto - desdeArriba;
  }

  color(rgb, trazo = false) {
    const [r, g, b] = rgb.map((v) => (v / 255).toFixed(3));
    this.ordenes.push(`${r} ${g} ${b} ${trazo ? 'RG' : 'rg'}`);
  }

  rectangulo(x, y, ancho, alto, { relleno, borde, grosor = 0.8 } = {}) {
    this.ordenes.push('q');
    if (relleno) this.color(relleno);
    if (borde) {
      this.color(borde, true);
      this.ordenes.push(`${grosor} w`);
    }
    this.ordenes.push(`${x} ${this.y(y + alto)} ${ancho} ${alto} re`);
    this.ordenes.push(relleno && borde ? 'B' : relleno ? 'f' : 'S');
    this.ordenes.push('Q');
  }

  /// Una línea quebrada por los puntos que se le pasen.
  camino(puntos, { color = [120, 120, 120], grosor = 0.7, punteada = false } = {}) {
    this.ordenes.push('q');
    this.color(color, true);
    this.ordenes.push(`${grosor} w`);
    if (punteada) this.ordenes.push('[3 2] 0 d');
    puntos.forEach(([x, y], i) => {
      this.ordenes.push(`${x.toFixed(1)} ${this.y(y).toFixed(1)} ${i === 0 ? 'm' : 'l'}`);
    });
    this.ordenes.push('S');
    this.ordenes.push('Q');
  }

  circulo(x, y, radio, color) {
    // Cuatro curvas de Bézier: 0.5523 es la constante que aproxima un cuarto
    // de círculo con una cúbica.
    const k = radio * 0.5523;
    const cy = this.y(y);
    this.ordenes.push('q');
    this.color(color);
    this.ordenes.push(`${x + radio} ${cy} m`);
    this.ordenes.push(`${x + radio} ${cy + k} ${x + k} ${cy + radio} ${x} ${cy + radio} c`);
    this.ordenes.push(`${x - k} ${cy + radio} ${x - radio} ${cy + k} ${x - radio} ${cy} c`);
    this.ordenes.push(`${x - radio} ${cy - k} ${x - k} ${cy - radio} ${x} ${cy - radio} c`);
    this.ordenes.push(`${x + k} ${cy - radio} ${x + radio} ${cy - k} ${x + radio} ${cy} c`);
    this.ordenes.push('f');
    this.ordenes.push('Q');
  }

  /// [alineacion] puede ser 'izquierda' o 'derecha'; con la segunda, x es el
  /// borde derecho del texto.
  texto(cadena, x, y, { tamanio = 9, negrita = false, color = [20, 20, 20], alineacion = 'izquierda' } = {}) {
    const ancho = medir(cadena, tamanio);
    const xFinal = alineacion === 'derecha' ? x - ancho : x;
    this.ordenes.push('q');
    this.color(color);
    this.ordenes.push('BT');
    this.ordenes.push(`/${negrita ? 'F2' : 'F1'} ${tamanio} Tf`);
    this.ordenes.push(`${xFinal.toFixed(1)} ${(this.y(y)).toFixed(1)} Td`);
    this.ordenes.push(`(${escapar(cadena)}) Tj`);
    this.ordenes.push('ET');
    this.ordenes.push('Q');
    return ancho;
  }

  /// Arma el archivo. La tabla xref del final lleva la posición exacta de cada
  /// objeto en bytes, así que se calcula a medida que se escribe.
  guardar(ruta) {
    const contenido = Buffer.from(this.ordenes.join('\n'), 'latin1');

    const objetos = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      `<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${this.ancho} ${this.alto}] ` +
        '/Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> /Contents 4 0 R >>',
      `<< /Length ${contenido.length} >>\nstream\n${contenido.toString('latin1')}\nendstream`,
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>',
    ];

    let pdf = '%PDF-1.4\n';
    const posiciones = [];
    objetos.forEach((cuerpo, i) => {
      posiciones.push(Buffer.byteLength(pdf, 'latin1'));
      pdf += `${i + 1} 0 obj\n${cuerpo}\nendobj\n`;
    });

    const inicioXref = Buffer.byteLength(pdf, 'latin1');
    pdf += `xref\n0 ${objetos.length + 1}\n0000000000 65535 f \n`;
    for (const p of posiciones) pdf += `${String(p).padStart(10, '0')} 00000 n \n`;
    pdf += `trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\n`;
    pdf += `startxref\n${inicioXref}\n%%EOF\n`;

    writeFileSync(ruta, Buffer.from(pdf, 'latin1'));
    return Buffer.byteLength(pdf, 'latin1');
  }
}

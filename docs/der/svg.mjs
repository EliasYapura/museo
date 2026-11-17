// El mismo dibujo que pdf.mjs, pero en SVG.
//
// Tiene los mismos métodos y recibe las mismas coordenadas, así que
// armar-der.mjs dibuja una sola vez y sale en los dos formatos. El PDF es el
// entregable; el SVG lo muestra GitHub al abrir el archivo, y se puede ver el
// cambio en un diff cuando la base cambia.

import { writeFileSync } from 'node:fs';
import { medir } from './pdf.mjs';

export { medir };

const escapar = (texto) =>
  texto.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const color = (rgb) => `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;

export class Svg {
  constructor(ancho, alto) {
    this.ancho = ancho;
    this.alto = alto;
    this.partes = [];
  }

  /// En SVG el origen ya está arriba a la izquierda, así que no hay nada que
  /// dar vuelta. Existe para que el código de dibujo sea el mismo.
  y(desdeArriba) {
    return desdeArriba;
  }

  rectangulo(x, y, ancho, alto, { relleno, borde, grosor = 0.8 } = {}) {
    const atributos = [
      `x="${x}"`,
      `y="${y}"`,
      `width="${ancho}"`,
      `height="${alto}"`,
      `fill="${relleno ? color(relleno) : 'none'}"`,
    ];
    if (borde) atributos.push(`stroke="${color(borde)}"`, `stroke-width="${grosor}"`);
    this.partes.push(`<rect ${atributos.join(' ')}/>`);
  }

  camino(puntos, { color: trazo = [120, 120, 120], grosor = 0.7, punteada = false } = {}) {
    const d = puntos.map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
    this.partes.push(
      `<path d="${d}" fill="none" stroke="${color(trazo)}" stroke-width="${grosor}"` +
        `${punteada ? ' stroke-dasharray="3 2"' : ''}/>`
    );
  }

  circulo(x, y, radio, relleno) {
    this.partes.push(`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${radio}" fill="${color(relleno)}"/>`);
  }

  texto(cadena, x, y, { tamanio = 9, negrita = false, color: tinta = [20, 20, 20], alineacion = 'izquierda' } = {}) {
    const ancho = medir(cadena, tamanio);
    const xFinal = alineacion === 'derecha' ? x - ancho : x;
    this.partes.push(
      `<text x="${xFinal.toFixed(1)}" y="${y.toFixed(1)}" font-family="Helvetica, Arial, sans-serif" ` +
        `font-size="${tamanio}" fill="${color(tinta)}"${negrita ? ' font-weight="bold"' : ''}>` +
        `${escapar(cadena)}</text>`
    );
    return ancho;
  }

  guardar(ruta) {
    const svg =
      `<svg xmlns="http://www.w3.org/2000/svg" width="${this.ancho}" height="${this.alto}" ` +
      `viewBox="0 0 ${this.ancho} ${this.alto}">\n` +
      `<rect width="${this.ancho}" height="${this.alto}" fill="#ffffff"/>\n` +
      this.partes.join('\n') +
      '\n</svg>\n';
    writeFileSync(ruta, svg, 'utf8');
    return Buffer.byteLength(svg, 'utf8');
  }
}

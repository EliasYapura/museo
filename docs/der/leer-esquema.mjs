// Lee docs/schema.sql y devuelve las tablas con sus columnas y sus relaciones.
//
// El diagrama se dibuja con esto y no a mano: asi no puede quedar mostrando una
// tabla que ya no existe, que es lo que le paso al anterior.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = dirname(fileURLToPath(import.meta.url));
export const ESQUEMA = join(AQUI, '..', 'schema.sql');

/// Las columnas que son clave primaria, de la linea PRIMARY KEY o de la
/// palabra en la propia columna.
function clavesPrimarias(cuerpo) {
  const compuesta = cuerpo.match(/^\s*PRIMARY KEY \(([^)]*)\)/m);
  if (compuesta) return compuesta[1].split(',').map((c) => c.trim());
  const simple = cuerpo.match(/^\s*(\w+)\s+[A-Z].*\bPRIMARY KEY\b/m);
  return simple ? [simple[1]] : [];
}

/// Donde termina el tipo y empiezan los modificadores.
const MODIFICADORES = new Set([
  'NOT',
  'NULL',
  'PRIMARY',
  'REFERENCES',
  'DEFAULT',
  'UNIQUE',
  'CHECK',
  'CONSTRAINT',
  'GENERATED',
]);

/// Tipo legible: lo que se escribio en el esquema, sin los modificadores.
///
/// Toma palabras hasta toparse con un modificador, asi entran los tipos de dos
/// palabras y, sobre todo, los enums propios del esquema —tipo_desafio,
/// estado_progreso, rol_usuario— que van en minuscula.
function tipoLegible(resto) {
  const palabras = [];
  for (const palabra of resto.trim().split(/\s+/)) {
    if (MODIFICADORES.has(palabra.toUpperCase().replace(/\(.*$/, ''))) break;
    palabras.push(palabra);
    // El parentesis de VARCHAR(200) o NUMERIC(5,2) cierra el tipo.
    if (palabra.includes(')')) break;
  }
  return palabras
    .join(' ')
    .toLowerCase()
    .replace(/,$/, '')
    .replace(/^bigserial$/, 'bigint')
    .replace(/^serial$/, 'int')
    .replace(/^integer$/, 'int')
    .replace(/^timestamptz$/, 'timestamp')
    .replace(/^boolean$/, 'bool');
}

export function leerEsquema(archivo = ESQUEMA) {
  const sql = readFileSync(archivo, 'utf8').replace(/\r\n/g, '\n');

  const tablas = [];
  const relaciones = [];

  for (const m of sql.matchAll(/CREATE TABLE (\w+) \(([\s\S]*?)\n\);/g)) {
    const [, nombre, cuerpo] = m;
    const pks = clavesPrimarias(cuerpo);
    const columnas = [];

    // Las lineas de columna empiezan con el nombre y siguen con un tipo en
    // mayusculas. Las de CONSTRAINT, PRIMARY KEY y las continuaciones de
    // REFERENCES no entran por eso mismo.
    for (const linea of cuerpo.split('\n')) {
      const c = linea.match(/^\s{4}(\w+)\s+(\S[\s\S]*)$/);
      if (!c) continue;
      const [, columna, resto] = c;
      if (['PRIMARY', 'CONSTRAINT', 'FOREIGN', 'UNIQUE', 'CHECK', 'REFERENCES'].includes(columna.toUpperCase())) {
        continue;
      }
      columnas.push({
        nombre: columna,
        tipo: tipoLegible(resto),
        pk: pks.includes(columna),
        unico: /\bUNIQUE\b/.test(resto),
        fk: false,
      });
    }

    // Las claves foraneas pueden estar en la misma linea de la columna o en la
    // siguiente, cuando el REFERENCES se escribio aparte.
    const bloque = cuerpo.replace(/\n\s+/g, ' ');
    for (const r of bloque.matchAll(/(\w+)\s+[A-Z][^,]*?REFERENCES\s+(\w+)\((\w+)\)([^,]*)/g)) {
      const [, columna, destino, columnaDestino, cola] = r;
      const col = columnas.find((x) => x.nombre === columna);
      if (!col) continue;
      col.fk = true;
      relaciones.push({
        desde: nombre,
        columna,
        hasta: destino,
        columnaDestino,
        alBorrar: /ON DELETE (\w+(?: \w+)?)/.exec(cola)?.[1]?.toLowerCase() ?? 'no action',
      });
    }

    tablas.push({ nombre, columnas });
  }

  return { tablas, relaciones };
}

// Correrlo suelto muestra lo que entendio, que es como se revisa el lector.
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const { tablas, relaciones } = leerEsquema();
  console.log(`${tablas.length} tablas, ${relaciones.length} claves foráneas\n`);
  for (const t of tablas) {
    console.log(`${t.nombre} (${t.columnas.length} columnas)`);
    for (const c of t.columnas) {
      const marcas = [c.pk && 'PK', c.fk && 'FK', c.unico && 'UQ'].filter(Boolean).join('+');
      console.log(`   ${(marcas || '  ').padEnd(6)} ${c.nombre.padEnd(22)} ${c.tipo}`);
    }
  }
  console.log('\nrelaciones:');
  for (const r of relaciones) {
    console.log(`   ${r.desde}.${r.columna} -> ${r.hasta}.${r.columnaDestino}  (al borrar: ${r.alBorrar})`);
  }
}

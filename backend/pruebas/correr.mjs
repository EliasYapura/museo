// Corre todas las pruebas y resume como fue.
//
//   npm test
//
// Hace falta la API escuchando en localhost:3000 (npm run dev) y el .env con
// la conexion a la base: son pruebas de integracion, van contra la base y el
// Storage de verdad. Cada una crea sus datos y los borra al terminar.
//
// Cada prueba corre en su propio proceso: si una se cuelga o se cae, las demas
// siguen, y el estado de una no se le mezcla a la siguiente.

import { spawn } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));

const archivos = readdirSync(aqui)
  .filter((f) => f.startsWith('probar-') && f.endsWith('.mjs'))
  .sort();

if (archivos.length === 0) {
  console.error('No encontre ninguna prueba.');
  process.exit(2);
}

// --- que la API este viva, una sola vez -----------------------------------
const API = process.env.PRUEBAS_API ?? 'http://localhost:3000';
try {
  const res = await fetch(`${API}/health`, { signal: AbortSignal.timeout(5000) });
  if (!res.ok) throw new Error(String(res.status));
} catch {
  console.error(`No hay una API escuchando en ${API}.`);
  console.error('Arrancala en otra terminal con "npm run dev" y volve a probar.');
  process.exit(2);
}

function correr(archivo) {
  return new Promise((resolve) => {
    const hijo = spawn(process.execPath, [join(aqui, archivo)], {
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
    });

    let salida = '';
    hijo.stdout.on('data', (d) => (salida += d));
    hijo.stderr.on('data', (d) => (salida += d));
    hijo.on('close', (codigo) => resolve({ archivo, codigo, salida }));
  });
}

// En serie y no en paralelo: varias pruebas cuentan filas de la base, y otra
// insertando al mismo tiempo les cambiaria el numero abajo de los pies.
const resultados = [];
for (const archivo of archivos) {
  console.log(`\n${'-'.repeat(70)}\n${archivo}\n${'-'.repeat(70)}`);
  const r = await correr(archivo);
  process.stdout.write(r.salida);
  resultados.push(r);
}

// --- el resumen -----------------------------------------------------------
console.log(`\n${'='.repeat(70)}`);

const cuentaDe = (salida) => ({
  ok: (salida.match(/^OK {4}/gm) ?? []).length,
  fallas: (salida.match(/^FALLA /gm) ?? []).length,
});

let totalOk = 0;
let totalFallas = 0;
const rotas = [];

for (const r of resultados) {
  const { ok, fallas } = cuentaDe(r.salida);
  totalOk += ok;
  totalFallas += fallas;
  // Codigo 2 es la prueba avisando que no pudo ni empezar: sin administrador
  // en la base, sin sala, sin API. No es lo mismo que una comprobacion que da
  // mal, y conviene que se lea distinto.
  const estado = r.codigo === 0 ? 'bien' : r.codigo === 2 ? 'NO PUDO CORRER' : 'CON FALLAS';
  if (r.codigo !== 0) rotas.push(r.archivo);
  console.log(`  ${estado.padEnd(16)} ${r.archivo.padEnd(34)} ${ok} ok, ${fallas} fallas`);
}

console.log(`${'='.repeat(70)}`);
console.log(`${archivos.length} pruebas, ${totalOk} comprobaciones bien, ${totalFallas} mal.`);

if (rotas.length > 0) {
  console.log(`\nRevisar: ${rotas.join(', ')}`);
  process.exit(1);
}
console.log('\nTodo bien.');

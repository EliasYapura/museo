import pg from 'pg';
import { config } from './config.js';

// Los BIGINT de PostgreSQL (tipo 20: BIGSERIAL, COUNT) son enteros de 64 bits,
// y JavaScript solo representa enteros exactos hasta 2^53. Para no perder
// precision en silencio, pg los entrega como texto: un id llega como "9".
// Eso rompe comparaciones como mision.creada_por === usuario.id en el panel
// y en la app. Se convierten a numero porque ni los ids ni los conteos de
// este sistema se acercan a 2^53 (unos 9 mil billones).
pg.types.setTypeParser(20, (valor) => Number(valor));

// Un pool reutiliza conexiones abiertas en lugar de abrir una por peticion,
// que seria lento y agotaria el limite de conexiones de Supabase.
export const pool = new pg.Pool({
  connectionString: config.databaseUrl,
  // Supabase exige conexiones cifradas. rejectUnauthorized: false cifra el
  // trafico pero no verifica el certificado del servidor. Para verificarlo
  // hay que descargar el certificado CA desde el panel de Supabase.
  ssl: { rejectUnauthorized: false },
});

// Si una conexion inactiva del pool se cae (por ejemplo, un corte de red),
// pg emite este evento. Sin un manejador, el proceso entero terminaria.
pool.on('error', (err) => {
  console.error('Error en una conexion inactiva de la base:', err.message);
});

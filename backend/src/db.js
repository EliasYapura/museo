import pg from 'pg';
import { config } from './config.js';

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

// Lee y valida las variables de entorno una sola vez, al arrancar.
// Si falta algo, el servidor no levanta: es preferible fallar enseguida con un
// mensaje claro que descubrir el problema en la primera peticion.

const faltantes = ['DATABASE_URL', 'JWT_SECRET', 'SUPABASE_URL', 'SUPABASE_SERVICE_KEY']
  .filter((n) => !process.env[n]);
if (faltantes.length > 0) {
  throw new Error(
    `Faltan variables de entorno: ${faltantes.join(', ')}. ` +
      'Copia .env.example a .env y completa los valores.'
  );
}

// Un secreto corto se puede adivinar por fuerza bruta, y con el secreto
// cualquiera puede fabricar tokens validos (por ejemplo, de administrador).
if (process.env.JWT_SECRET.length < 32) {
  throw new Error('JWT_SECRET debe tener al menos 32 caracteres.');
}

// Si la clave viniera mal pegada, el fallo aparecería recién al subir la
// primera imagen y se buscaría en el lugar equivocado. Se corta acá.
if (!process.env.SUPABASE_URL.startsWith('https://')) {
  throw new Error('SUPABASE_URL tiene que ser la dirección del proyecto, empezando con https://');
}
if (!/^sb_secret_[A-Za-z0-9_-]+$/.test(process.env.SUPABASE_SERVICE_KEY)) {
  throw new Error(
    'SUPABASE_SERVICE_KEY no parece una Secret key de Supabase (empieza con sb_secret_). ' +
      'Revisá que no haya quedado entre < >, con comillas o con espacios.'
  );
}

export const config = {
  puerto: Number(process.env.PORT) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  // La dirección del proyecto de Supabase, sin barra final, y la clave que
  // saltea RLS. Sólo la usa el servidor: nunca sale de acá (ADM25).
  supabaseUrl: process.env.SUPABASE_URL.replace(/\/+$/, ''),
  supabaseServiceKey: process.env.SUPABASE_SERVICE_KEY,
  jwtExpira: process.env.JWT_EXPIRA || '8h',
  // Origenes autorizados por CORS: el panel y, si la app del visitante se
  // corre en el navegador, su servidor de desarrollo. En un emulador o en un
  // telefono no hace falta: CORS es una regla de los navegadores.
  // En produccion, las URLs de Vercel.
  origenesPermitidos: [
    process.env.PANEL_ORIGIN || 'http://localhost:5173',
    process.env.APP_ORIGIN || 'http://localhost:5000',
  ],
};

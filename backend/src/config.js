// Lee y valida las variables de entorno una sola vez, al arrancar.
// Si falta algo, el servidor no levanta: es preferible fallar enseguida con un
// mensaje claro que descubrir el problema en la primera peticion.

const faltantes = ['DATABASE_URL', 'JWT_SECRET'].filter((n) => !process.env[n]);
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

export const config = {
  puerto: Number(process.env.PORT) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  jwtSecret: process.env.JWT_SECRET,
  jwtExpira: process.env.JWT_EXPIRA || '8h',
  // Origen del panel autorizado por CORS. En produccion, la URL de Vercel.
  panelOrigin: process.env.PANEL_ORIGIN || 'http://localhost:5173',
};

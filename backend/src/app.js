import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { authRouter } from './routes/auth.js';
import { misionesRouter } from './routes/misiones.js';

// La app se configura aca y se arranca en index.js. Asi se puede importar
// la app completa sin abrir un puerto, por ejemplo para probarla.
export const app = express();

// El navegador bloquea por defecto que una pagina llame a una API de otro
// origen (el panel corre en otro puerto o dominio). CORS le indica que el
// panel esta autorizado. Solo se habilita ese origen, no cualquiera.
app.use(cors({ origin: config.panelOrigin }));

// Permite recibir cuerpos JSON en las peticiones.
app.use(express.json());

// Endpoint de diagnostico: sirve para confirmar que la API esta viva.
// No consulta la base; responde aunque la base este caida.
app.get('/health', (req, res) => {
  res.json({
    estado: 'ok',
    servicio: 'exploradores-museo-backend',
    hora: new Date().toISOString(),
  });
});

app.use('/auth', authRouter);
app.use('/misiones', misionesRouter);

// Cualquier ruta que no coincidio con las anteriores.
app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

// Manejador de errores. Express 5 captura automaticamente los errores de las
// funciones async y los manda aca, sin necesidad de try/catch en cada ruta.
// Tiene que declarar los 4 parametros para que Express lo reconozca como tal.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'El cuerpo de la petición no es JSON válido' });
  }

  // El detalle queda en el log del servidor; al cliente no se le muestra
  // porque puede revelar la estructura interna de la base.
  console.error(err);
  return res.status(500).json({ error: 'Error interno del servidor' });
});

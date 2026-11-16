import cors from 'cors';
import express from 'express';
import { config } from './config.js';
import { authRouter } from './routes/auth.js';
import { categoriasRouter } from './routes/categorias.js';
import { desafiosDeMisionRouter, desafiosRouter } from './routes/desafios.js';
import { estadisticasRouter } from './routes/estadisticas.js';
import { insigniasRouter } from './routes/insignias.js';
import { misionesRouter } from './routes/misiones.js';
import { objetosRouter } from './routes/objetos.js';
import { pistasDeDesafioRouter, pistasRouter } from './routes/pistas.js';
import { publicoRouter } from './routes/publico.js';
import { salasRouter } from './routes/salas.js';

// La app se configura aca y se arranca en index.js. Asi se puede importar
// la app completa sin abrir un puerto, por ejemplo para probarla.
export const app = express();

// Render (y cualquier hosting con TLS por delante) termina el cifrado en un
// proxy y reenvia la peticion. Sin esto, express ve la IP del proxy en todas,
// y el limite de intentos de SIS04 contaria a todo el mundo junto: el primero
// que fallara diez veces dejaria afuera a los demas.
//
// Es 1 y no true: con true, express le cree a cualquier X-Forwarded-For que
// llegue, y entonces basta con falsificar esa cabecera para saltearse el
// limite. Con 1 solo confia en el proxy inmediato, que es el de Render.
app.set('trust proxy', 1);

// El navegador bloquea por defecto que una pagina llame a una API de otro
// origen (el panel corre en otro puerto o dominio). CORS le indica cuales
// estan autorizados: el panel y la app del visitante cuando se la corre en el
// navegador. Solo esos dos, no cualquiera.
app.use(cors({ origin: config.origenesPermitidos }));

// Permite recibir cuerpos JSON en las peticiones.
app.use(express.json());

// Las imágenes que se suben llegan como bytes y no como JSON: el ícono de una
// insignia, la portada de una misión y la foto de una pieza (ADM25).
// Se declara ruta por ruta, y con los tipos acotados, para que ninguna otra
// pueda recibir un cuerpo binario sin querer.
//
// El límite acá es el del protocolo: deja pasar lo que no es absurdo y
// almacenamiento.js aplica el de verdad, mirando el contenido. Sin este tope,
// alguien podría mandar un cuerpo enorme y hacernos reservar memoria antes de
// que nadie lo revise.
const cuerpoDeImagen = express.raw({
  type: ['image/png', 'image/jpeg', 'image/webp'],
  limit: '3mb',
});

app.use('/insignias/:id/icono', cuerpoDeImagen);
app.use('/misiones/:id/imagen', cuerpoDeImagen);
app.use('/objetos/:id/imagen', cuerpoDeImagen);

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
// Lo que consume la app del visitante, sin token (VIS01).
app.use('/publico', publicoRouter);
// Va antes de /misiones porque es una direccion mas especifica.
app.use('/misiones/:misionId/desafios', desafiosDeMisionRouter);
app.use('/misiones', misionesRouter);
// Va antes de /desafios porque es una direccion mas especifica.
app.use('/desafios/:desafioId/pistas', pistasDeDesafioRouter);
app.use('/desafios', desafiosRouter);
app.use('/pistas', pistasRouter);
app.use('/objetos', objetosRouter);
app.use('/insignias', insigniasRouter);
app.use('/salas', salasRouter);
app.use('/categorias', categoriasRouter);
// Las estadisticas de uso (ADM22). En su propia direccion y no dentro de
// /misiones: alla /misiones/estadisticas lo tomaria GET /misiones/:id, que
// revisa el id primero y responderia 404.
app.use('/estadisticas', estadisticasRouter);

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

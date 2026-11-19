import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import { normalizarEmail } from '../validaciones/email.js';

// Limites de peticiones para las rutas de autenticacion (SIS04).
//
// Sin esto, /auth/login acepta todos los intentos que le manden. Son dos
// problemas en uno:
//
// - Probar contrasenas de a miles hasta acertar una.
// - Tumbar la API. Cada intento gasta unos 100 ms de CPU en bcrypt, a
//   proposito —esa lentitud es lo que hace cara la fuerza bruta—, pero
//   tambien significa que unos cientos de pedidos simultaneos dejan al
//   servidor sin tiempo para nadie mas. En el plan gratuito de Render, que
//   es una sola instancia chica, alcanza con poco.
//
// El conteo es en memoria: si el proceso se reinicia, los contadores se
// pierden. Para una sola instancia alcanza. El dia que haya varias habra que
// mover esto a un almacen compartido, porque cada instancia contaria por su
// cuenta y el limite real seria el doble, el triple, etc.
//
// La ventana es fija: arranca con el primer intento contado y se reinicia ese
// tanto despues, no desde el ultimo. Seguir intentando no estira el castigo.

/// Respuesta cuando se pasa del limite. El 429 es el codigo que corresponde.
const demasiados = (mensaje) => (req, res) => res.status(429).json({ error: mensaje });

/// La IP del pedido, en la forma que recomienda la libreria.
///
/// No se usa req.ip directo: en IPv6 cada persona suele tener un bloque
/// enorme de direcciones, asi que contar por direccion exacta es contar por
/// intento. ipKeyGenerator agrupa por subred.
const porIp = (req) => ipKeyGenerator(req.ip);

/// Intentos fallidos contra UNA cuenta, desde UNA conexion.
///
/// Diez cada quince minutos: de sobra para alguien que se equivoco y vuelve a
/// probar, y nada para quien recorre un diccionario.
///
/// La clave incluye el email y no solo la IP porque el wifi del museo es una
/// sola IP para todos. Contando solo por IP, diez visitantes distintos que se
/// equivocan dejan afuera al siguiente, que no tuvo nada que ver.
///
/// skipSuccessfulRequests hace que solo cuenten los intentos fallidos. Alguien
/// que entra bien, sale y vuelve a entrar no tiene por que quedar bloqueado.
export const limiteDeLogin = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  skipSuccessfulRequests: true,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  // Sin email —un cuerpo vacio o mal formado— se cuenta solo por IP. Esos
  // pedidos no pueden acertar ninguna contrasena, pero igual gastan servidor.
  keyGenerator: (req) => {
    const email = typeof req.body?.email === 'string' ? normalizarEmail(req.body.email) : '';
    return email === '' ? porIp(req) : `${porIp(req)}|${email}`;
  },
  handler: demasiados(
    'Demasiados intentos fallidos con esa cuenta. Esperá unos minutos antes de volver a probar.'
  ),
});

/// Intentos fallidos desde una conexion, contra cualquier cuenta.
///
/// Es la red de seguridad del limite de arriba: contando por cuenta, alguien
/// que prueba una sola contrasena contra miles de emails distintos nunca
/// llega a diez en ninguna y no se frena jamas. Esto lo frena igual.
///
/// Sesenta cada quince minutos es flojo a proposito: tiene que molestar a un
/// ataque y no a una sala llena de visitantes equivocandose.
export const limiteDeLoginPorIp = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60,
  skipSuccessfulRequests: true,
  standardHeaders: false, // las cabeceras las pone el limite por cuenta
  legacyHeaders: false,
  keyGenerator: porIp,
  handler: demasiados(
    'Se hicieron demasiados intentos desde esta conexión. Probá de nuevo más tarde.'
  ),
});

/// Altas de cuenta por IP.
///
/// Acá sí va por IP sola: lo que se quiere evitar es que alguien cree cuentas
/// en masa, y el email de cada una es distinto por definicion.
///
/// Mas permisivo que el login porque una familia entera puede registrarse
/// desde el wifi del museo. Cinco por hora corta la creacion masiva sin
/// molestar a nadie real.
export const limiteDeRegistro = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: porIp,
  handler: demasiados(
    'Se crearon demasiadas cuentas desde esta conexión. Probá de nuevo más tarde.'
  ),
});

/// Redacciones con IA (ADM27).
///
/// Esta ruta es la unica del sistema que cuesta plata por pedido: cada llamada
/// se le factura al museo. Sin limite, un boton que se queda apretado o un
/// script con el token de un administrador vacian el credito.
///
/// Treinta por hora y por administrador alcanza de sobra para armar una mision
/// entera en una sesion de trabajo. Se cuenta por usuario y no por IP porque
/// aca ya sabemos quien es: todos los administradores del museo pueden estar
/// detras de la misma conexion.
export const limiteDeRedaccion = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  keyGenerator: (req) => String(req.usuario?.id ?? porIp(req)),
  handler: demasiados(
    'Se usaron demasiadas redacciones con IA en la última hora. Probá de nuevo más tarde.'
  ),
});

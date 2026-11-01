import jwt from 'jsonwebtoken';
import { config } from '../config.js';

// Exige un token valido en el header "Authorization: Bearer <token>".
// Si lo es, deja los datos del usuario en req.usuario para las rutas.
export function verificarToken(req, res, next) {
  const header = req.headers.authorization || '';
  const [esquema, token] = header.split(' ');

  if (esquema !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Falta el token de autenticación' });
  }

  try {
    // Se fija el algoritmo explicitamente. Si se aceptara el que declara el
    // propio token, un atacante podria elegir uno mas debil.
    const payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
    req.usuario = { id: Number(payload.sub), rol: payload.rol };
    next();
  } catch {
    // Mismo mensaje para token vencido, alterado o mal formado: al cliente
    // le basta saber que tiene que volver a iniciar sesion.
    return res.status(401).json({ error: 'Token inválido o vencido' });
  }
}

// Se usa despues de verificarToken. Corta con 403 si el rol no alcanza.
// 401 significa "no se quien sos"; 403, "se quien sos y no podes".
export function requerirRol(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.usuario?.rol)) {
      return res.status(403).json({ error: 'No tenés permiso para esta acción' });
    }
    next();
  };
}

// Igual que verificarToken pero sin exigirlo: si viene un token valido deja
// los datos en req.usuario, y si no viene sigue sin usuario.
//
// Lo usan las rutas publicas, que tienen que servir a los dos casos: el
// visitante con cuenta, al que se le guarda el progreso (SIS03), y el que
// recorre sin cuenta, que es como funciono el museo hasta ahora.
//
// Un token vencido tampoco corta: seria dejar a alguien parado en medio de una
// sala sin poder seguir la mision. Pierde el guardado, no la visita.
export function tokenOpcional(req, res, next) {
  const header = req.headers.authorization || '';
  const [esquema, token] = header.split(' ');
  if (esquema !== 'Bearer' || !token) return next();

  try {
    const payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
    req.usuario = { id: Number(payload.sub), rol: payload.rol };
  } catch {
    // Token vencido o alterado: se sigue como anonimo, a proposito.
  }
  next();
}

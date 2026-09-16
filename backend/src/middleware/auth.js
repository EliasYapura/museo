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

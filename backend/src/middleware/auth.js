import jwt from 'jsonwebtoken';
import { config } from '../config.js';
import { pool } from '../db.js';

/// Busca al usuario del token en la base.
///
/// El token dice quien es y que rol tenia AL MOMENTO DE ENTRAR, y vale hasta
/// ocho horas. Creerle significa que bajarle el rol a alguien, o desactivarle
/// la cuenta, no tiene efecto hasta que el token venza: durante ese rato sigue
/// entrando como administrador (SIS04).
///
/// Por eso el rol y el estado se leen de la base en cada peticion protegida.
/// Cuesta una consulta, que al volumen de esto no se nota, y hace que cortarle
/// el acceso a alguien sea inmediato.
///
/// Devuelve null si el usuario ya no existe o esta desactivado.
async function usuarioVigente(id) {
  const { rows } = await pool.query(
    'SELECT id, rol, activo FROM usuarios WHERE id = $1',
    [id]
  );
  const usuario = rows[0];
  if (!usuario || !usuario.activo) return null;
  return { id: usuario.id, rol: usuario.rol };
}

// Exige un token valido en el header "Authorization: Bearer <token>".
// Si lo es, deja los datos del usuario en req.usuario para las rutas.
export async function verificarToken(req, res, next) {
  const header = req.headers.authorization || '';
  const [esquema, token] = header.split(' ');

  if (esquema !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Falta el token de autenticación' });
  }

  let payload;
  try {
    // Se fija el algoritmo explicitamente. Si se aceptara el que declara el
    // propio token, un atacante podria elegir uno mas debil.
    payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
  } catch {
    // Mismo mensaje para token vencido, alterado o mal formado: al cliente
    // le basta saber que tiene que volver a iniciar sesion.
    return res.status(401).json({ error: 'Token inválido o vencido' });
  }

  // El token es valido, pero eso solo prueba que lo emitimos nosotros. Quien
  // manda sobre el rol y sobre si la cuenta sigue habilitada es la base.
  const usuario = await usuarioVigente(Number(payload.sub));
  if (!usuario) {
    // Mismo 401 que un token vencido: la app ya sabe cerrar la sesion con
    // ese codigo, y al cliente le da igual por cual de los dos motivos fue.
    return res.status(401).json({ error: 'Token inválido o vencido' });
  }

  req.usuario = usuario;
  next();
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
export async function tokenOpcional(req, res, next) {
  const header = req.headers.authorization || '';
  const [esquema, token] = header.split(' ');
  if (esquema !== 'Bearer' || !token) return next();

  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
  } catch {
    // Token vencido o alterado: se sigue como anonimo, a proposito.
    return next();
  }

  // Una cuenta desactivada recorre como anonima: no se le corta la visita,
  // pero deja de acumular progreso contra esa cuenta (SIS04).
  const usuario = await usuarioVigente(Number(payload.sub));
  if (usuario) req.usuario = usuario;
  next();
}

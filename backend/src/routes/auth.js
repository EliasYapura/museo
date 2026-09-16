import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { pool } from '../db.js';
import { config } from '../config.js';
import { verificarToken } from '../middleware/auth.js';

export const authRouter = Router();

// Cantidad de rondas de bcrypt (2^10). Cada punto extra duplica el tiempo de
// hasheo, tanto para nosotros como para quien intente adivinar contrasenas.
const COSTO_BCRYPT = 10;

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Hash de una contrasena que nadie usa. Cuando el email no existe se compara
// contra este, para que la respuesta tarde lo mismo que con un email real.
// Si no, midiendo el tiempo se podria averiguar que emails estan registrados.
const HASH_FICTICIO = bcrypt.hashSync('contrasena-ficticia-solo-para-igualar-tiempos', COSTO_BCRYPT);

// "Ana@Mail.com" y "ana@mail.com" son la misma casilla: se guardan iguales
// para que no se puedan crear dos cuentas con el mismo email.
const normalizarEmail = (email) => email.trim().toLowerCase();

function validarRegistro({ email, password, nombre }) {
  const errores = [];

  if (typeof email !== 'string' || !EMAIL_REGEX.test(email.trim()) || email.trim().length > 255) {
    errores.push('email: formato inválido');
  }

  if (typeof password !== 'string' || password.length < 8) {
    errores.push('password: mínimo 8 caracteres');
  } else if (Buffer.byteLength(password, 'utf8') > 72) {
    // bcrypt ignora en silencio todo lo que pase de 72 bytes. Sin este
    // limite, dos contrasenas largas que solo difieren al final serian
    // intercambiables.
    errores.push('password: máximo 72 bytes');
  }

  if (typeof nombre !== 'string' || nombre.trim().length === 0) {
    errores.push('nombre: obligatorio');
  } else if (nombre.trim().length > 120) {
    errores.push('nombre: máximo 120 caracteres');
  }

  return errores;
}

// POST /auth/registro — crea una cuenta de visitante
authRouter.post('/registro', async (req, res) => {
  const { email, password, nombre } = req.body ?? {};

  const errores = validarRegistro({ email, password, nombre });
  if (errores.length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', detalles: errores });
  }

  const passwordHash = await bcrypt.hash(password, COSTO_BCRYPT);

  try {
    // El rol NUNCA se toma del cuerpo de la peticion: no se inserta y la base
    // aplica su valor por defecto, 'visitante'. Los administradores se crean
    // promoviendo un usuario directamente en la base.
    const { rows } = await pool.query(
      `INSERT INTO usuarios (email, password_hash, nombre)
       VALUES ($1, $2, $3)
       RETURNING id, email, nombre, rol, creado_en`,
      [normalizarEmail(email), passwordHash, nombre.trim()]
    );
    return res.status(201).json({ usuario: rows[0] });
  } catch (err) {
    // 23505 es el codigo de PostgreSQL para violacion de UNIQUE.
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Ya existe una cuenta con ese email' });
    }
    throw err;
  }
});

// POST /auth/login — devuelve un JWT si las credenciales son correctas
authRouter.post('/login', async (req, res) => {
  const { email, password } = req.body ?? {};

  if (typeof email !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ error: 'Email y contraseña son obligatorios' });
  }

  // Consulta parametrizada ($1): el email nunca se concatena al SQL, asi que
  // no hay forma de inyectar codigo a traves de el.
  const { rows } = await pool.query(
    'SELECT id, email, nombre, rol, activo, password_hash FROM usuarios WHERE email = $1',
    [normalizarEmail(email)]
  );
  const usuario = rows[0];

  const coincide = await bcrypt.compare(password, usuario?.password_hash ?? HASH_FICTICIO);

  // Mismo codigo y mismo mensaje si el email no existe o si la contrasena es
  // incorrecta, para no revelar que emails estan registrados.
  if (!usuario || !coincide) {
    return res.status(401).json({ error: 'Email o contraseña incorrectos' });
  }

  if (!usuario.activo) {
    return res.status(403).json({ error: 'La cuenta está desactivada' });
  }

  const token = jwt.sign({ rol: usuario.rol }, config.jwtSecret, {
    subject: String(usuario.id),
    expiresIn: config.jwtExpira,
    algorithm: 'HS256',
  });

  return res.json({
    token,
    usuario: { id: usuario.id, email: usuario.email, nombre: usuario.nombre, rol: usuario.rol },
  });
});

// GET /auth/perfil — devuelve el usuario del token. Ruta protegida.
authRouter.get('/perfil', verificarToken, async (req, res) => {
  const { rows } = await pool.query(
    'SELECT id, email, nombre, rol, creado_en FROM usuarios WHERE id = $1',
    [req.usuario.id]
  );

  if (!rows[0]) {
    return res.status(404).json({ error: 'Usuario no encontrado' });
  }
  return res.json({ usuario: rows[0] });
});

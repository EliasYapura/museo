// Lo que comparten todas las pruebas: pedir a la API, firmar un token, llevar
// la cuenta de los aciertos y generar imagenes de verdad.
//
// Cada prueba arma sus propios datos, comprueba lo que le toca y los borra al
// terminar. No hay orden entre ellas ni dependen unas de otras.

import { randomBytes } from 'node:crypto';
import { deflateSync } from 'node:zlib';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import { config } from '../src/config.js';

export const API = process.env.PRUEBAS_API ?? 'http://localhost:3000';

export const bd = new pg.Pool({ connectionString: config.databaseUrl });

// --- la cuenta de lo que salio bien y lo que no ----------------------------

let fallas = 0;
let total = 0;

/// Anota una comprobacion y la imprime. [detalle] es lo que se vio, que es lo
/// primero que se quiere leer cuando algo falla.
export function comprobar(nombre, ok, detalle = '') {
  total++;
  if (!ok) fallas++;
  console.log((ok ? 'OK    ' : 'FALLA ') + nombre + (detalle ? ' -> ' + detalle : ''));
}

/// Cierra la prueba: imprime el resumen, suelta la conexion y sale con 0 si
/// todo anduvo. El codigo de salida es lo que mira el corredor.
export async function terminar() {
  await bd.end();
  console.log(fallas === 0 ? `\nTodo bien (${total} comprobaciones).` : `\n${fallas} de ${total} fallaron.`);
  process.exit(fallas === 0 ? 0 : 1);
}

// --- hablar con la API -----------------------------------------------------

/// Un pedido a la API. Devuelve el estado y el cuerpo ya interpretado, o null
/// si la respuesta no era JSON.
///
/// [cuerpo] puede ser un objeto, que se manda como JSON, o un Buffer, que se
/// manda crudo con el [tipo] que se le pase.
///
/// [extra] agrega cabeceras, que es como las pruebas del limite de intentos se
/// hacen pasar por clientes distintos (ver [ipDePrueba]).
export async function pedir(metodo, ruta, token, cuerpo, tipo, extra = {}) {
  const cabeceras = { ...extra };
  if (token) cabeceras.Authorization = `Bearer ${token}`;
  if (cuerpo !== undefined) cabeceras['Content-Type'] = tipo ?? 'application/json';

  const res = await fetch(API + ruta, {
    method: metodo,
    headers: cabeceras,
    body:
      cuerpo === undefined
        ? undefined
        : Buffer.isBuffer(cuerpo)
          ? cuerpo
          : JSON.stringify(cuerpo),
  });

  const texto = await res.text();
  let json = null;
  try {
    json = texto ? JSON.parse(texto) : null;
  } catch {
    json = null;
  }
  return { estado: res.status, cuerpo: json };
}

/// Una IP inventada, distinta en cada llamada, para las pruebas que gastan a
/// proposito la cuota de intentos de login (SIS04).
///
/// La API confia en el X-Forwarded-For del proxy inmediato —es trust proxy = 1,
/// porque en produccion esta detras de Render—, asi que cada prueba puede
/// presentarse como un cliente distinto. Sin esto, la primera prueba que agota
/// la cuota deja a las demas sin poder entrar, y de paso bloquea la IP de
/// quien esta programando por los siguientes quince minutos.
///
/// Son direcciones del rango 198.18.0.0/15, reservado para pruebas de
/// rendimiento: no existe ninguna maquina detras.
///
/// Los dos ultimos numeros salen al azar y no de un contador: con un contador,
/// dos pruebas que corren en procesos distintos arrancan las dos en el mismo
/// numero y vuelven a compartir la cuota, que es justo lo que esto evita.
let ultimaIp = 0;
export function ipDePrueba() {
  ultimaIp++;
  return `198.18.${randomBytes(1)[0]}.${(randomBytes(1)[0] % 254) + 1}`;
}

// --- quien hace el pedido --------------------------------------------------

/// Firma un token como lo firma la API, para no necesitar la contrasenia de
/// nadie: las pruebas corren contra la misma base y con el mismo secreto que
/// el servidor, asi que pueden emitir el token ellas mismas.
export function tokenDe(id, rol) {
  return jwt.sign({ rol }, config.jwtSecret, {
    subject: String(id),
    expiresIn: '15m',
    algorithm: 'HS256',
  });
}

/// El id del primer administrador activo. Las pruebas no crean
/// administradores: crear cuentas con permisos y olvidarse de borrarlas es
/// justo lo que no hay que dejar en una base de verdad.
export async function administrador() {
  const { rows } = await bd.query(
    "SELECT id FROM usuarios WHERE rol = 'administrador' AND activo = TRUE ORDER BY id LIMIT 1"
  );
  if (!rows[0]) {
    console.error('No hay ningun administrador activo en la base.');
    process.exit(2);
  }
  return Number(rows[0].id);
}

/// Un visitante descartable, con su id y su token.
///
/// El hash no corresponde a ninguna contrasenia: la cuenta existe solo para la
/// prueba, nunca se entra con ella y se borra con [borrarUsuarios].
export async function visitanteNuevo(nombre = 'Visitante de prueba') {
  const marca = `${Date.now()}-${randomBytes(3).toString('hex')}`;
  const { rows } = await bd.query(
    `INSERT INTO usuarios (email, password_hash, nombre, rol)
     VALUES ($1, 'no-es-un-hash-valido-solo-para-las-pruebas', $2, 'visitante')
     RETURNING id`,
    [`prueba-${marca}@prueba.test`, nombre]
  );
  const id = Number(rows[0].id);
  return { id, token: tokenDe(id, 'visitante') };
}

/// Borra por id, nunca por un patron: con un LIKE, una cuenta que entre
/// despues por casualidad se borraria sin que nadie la haya visto.
export async function borrarUsuarios(ids) {
  if (ids.length === 0) return;
  const { rowCount } = await bd.query('DELETE FROM usuarios WHERE id = ANY($1)', [ids]);
  console.log(`limpieza: ${rowCount} de ${ids.length} usuarios de prueba borrados`);
}

// --- imagenes de verdad ----------------------------------------------------

/// Un PNG de un pixel del color que se le pida, armado a mano: un PNG es una
/// firma y despues trozos, cada uno con su largo, su nombre, sus datos y un
/// CRC32. Sirve para probar que el servidor reconozca el tipo por el
/// contenido y no por lo que diga el cliente.
export function pngDeUnPixel(rgb = [0xd0, 0x30, 0x30]) {
  const tabla = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })();

  const crc32 = (datos) => {
    let c = 0xffffffff;
    for (const byte of datos) c = tabla[(c ^ byte) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };

  const trozo = (nombre, datos) => {
    const largo = Buffer.alloc(4);
    largo.writeUInt32BE(datos.length);
    const cuerpo = Buffer.concat([Buffer.from(nombre, 'latin1'), datos]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(cuerpo));
    return Buffer.concat([largo, cuerpo, crc]);
  };

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(1, 0);
  ihdr.writeUInt32BE(1, 4);
  ihdr[8] = 8; // bits por canal
  ihdr[9] = 2; // color verdadero, sin alfa

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    trozo('IHDR', ihdr),
    trozo('IDAT', deflateSync(Buffer.from([0, ...rgb]))),
    trozo('IEND', Buffer.alloc(0)),
  ]);
}

/// Algo que no es una imagen, para comprobar que se rechace.
export const NO_ES_IMAGEN = Buffer.from('%PDF-1.4 esto no es una imagen', 'latin1');

// --- Supabase Storage ------------------------------------------------------

/// Los nombres de los archivos que hay en un bucket.
///
/// Se mira la lista y no la URL publica: Storage sirve las URLs publicas por
/// una cache de borde que sigue respondiendo un rato despues de borrar el
/// archivo, asi que bajarla no prueba que siga estando.
export async function archivosDelBucket(bucket) {
  const res = await fetch(`${config.supabaseUrl}/storage/v1/object/list/${bucket}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.supabaseServiceKey}`,
      apikey: config.supabaseServiceKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prefix: '', limit: 1000 }),
  });
  if (!res.ok) throw new Error(`no pude listar el bucket ${bucket} (${res.status})`);
  return (await res.json()).map((a) => a.name);
}

/// Avisa y corta si la API no esta levantada. Sin esto, la prueba falla con
/// veinte errores de conexion y hay que leerlos todos para entender que lo
/// unico que pasaba era que faltaba arrancar el servidor.
export async function exigirApiViva() {
  try {
    const res = await fetch(`${API}/health`, { signal: AbortSignal.timeout(5000) });
    if (res.ok) return;
    console.error(`La API responde ${res.status} en ${API}/health.`);
  } catch {
    console.error(`No hay una API escuchando en ${API}. Arrancala con "npm run dev".`);
  }
  await bd.end();
  process.exit(2);
}

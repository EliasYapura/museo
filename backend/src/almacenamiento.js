import { randomBytes } from 'node:crypto';
import { config } from './config.js';

// Guardado de imagenes en Supabase Storage (ADM25).
//
// El archivo NO viaja de la app a Supabase: va de la app a esta API, y de aca
// a Storage con la clave de servicio. Si la app subiera sola, esa clave
// tendria que estar dentro del APK, y cualquiera que lo abra la tiene. Es el
// mismo criterio que con la base: todo pasa por el backend, por eso las tablas
// tienen RLS sin politicas.
//
// Se usa la API REST de Storage con fetch y no el SDK de Supabase: son tres
// pedidos HTTP y el SDK arrastraria una dependencia entera para eso.

/// Un bucket por tabla que guarda imagenes. Separados y no uno solo con
/// carpetas para que borrar de mas en uno no se lleve las imagenes de otro, y
/// porque cada uno tiene su tope de tamanio configurado en Supabase.
export const BUCKET_INSIGNIAS = 'insignias';
export const BUCKET_MISIONES = 'misiones';
export const BUCKET_OBJETOS = 'objetos';

const BUCKETS = [BUCKET_INSIGNIAS, BUCKET_MISIONES, BUCKET_OBJETOS];

/// El bucket va a la URL, asi que no puede ser cualquier texto. Un bucket que
/// no esta en la lista es un error de programacion nuestro, no del
/// administrador: por eso corta con Error y no con ErrorDeImagen.
function verificarBucket(bucket) {
  if (!BUCKETS.includes(bucket)) {
    throw new Error(`Bucket desconocido: ${bucket}`);
  }
}

/// Tipos que se aceptan, con los bytes que los identifican.
///
/// El tipo se decide por el CONTENIDO y no por lo que diga el cliente: que un
/// archivo se llame .png o venga con Content-Type: image/png no prueba nada,
/// y es la forma mas comun de colar algo que no es una imagen.
const FIRMAS = [
  { tipo: 'image/png', extension: 'png', bytes: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a] },
  { tipo: 'image/jpeg', extension: 'jpg', bytes: [0xff, 0xd8, 0xff] },
];

/// WebP no se reconoce con un prefijo fijo: son los bytes "RIFF", cuatro del
/// tamanio, y despues "WEBP".
const esWebp = (datos) =>
  datos.length >= 12 &&
  datos.subarray(0, 4).toString('latin1') === 'RIFF' &&
  datos.subarray(8, 12).toString('latin1') === 'WEBP';

/// Tope de tamanio. El bucket tambien lo tiene configurado, pero el limite que
/// manda es este: el del bucket es la segunda red, no la primera.
export const TAMANIO_MAXIMO = 2 * 1024 * 1024;

/// Reconoce el tipo real de la imagen, o null si no es ninguna de las tres.
export function reconocerImagen(datos) {
  for (const firma of FIRMAS) {
    if (datos.length < firma.bytes.length) continue;
    if (firma.bytes.every((byte, i) => datos[i] === byte)) return firma;
  }
  if (esWebp(datos)) return { tipo: 'image/webp', extension: 'webp' };
  return null;
}

/// Sube una imagen y devuelve su direccion publica.
///
/// El nombre lo genera esta funcion y nunca viene del cliente: un nombre que
/// manda el cliente es texto sin controlar apuntando a una ruta.
///
/// Ademas es unico en cada subida, incluso al reemplazar la imagen de la misma
/// insignia. Storage sirve las URLs publicas por una cache de borde que sigue
/// respondiendo un rato despues de borrar el archivo; reutilizando el nombre,
/// cambiar la imagen mostraria la vieja hasta que la cache se vacie.
export async function subirImagen(datos, bucket) {
  verificarBucket(bucket);

  const imagen = reconocerImagen(datos);
  if (!imagen) throw new ErrorDeImagen('El archivo no es una imagen PNG, JPEG o WebP');
  if (datos.length > TAMANIO_MAXIMO) {
    throw new ErrorDeImagen(`La imagen no puede pesar más de ${TAMANIO_MAXIMO / 1024 / 1024} MB`);
  }

  const nombre = `${randomBytes(16).toString('hex')}.${imagen.extension}`;
  const res = await fetch(`${config.supabaseUrl}/storage/v1/object/${bucket}/${nombre}`, {
    method: 'POST',
    headers: { ...autorizacion(), 'Content-Type': imagen.tipo },
    body: datos,
  });

  if (!res.ok) {
    throw new Error(`Storage rechazó la subida (${res.status}): ${await res.text()}`);
  }
  return `${config.supabaseUrl}/storage/v1/object/public/${bucket}/${nombre}`;
}

/// Borra una imagen a partir de su direccion publica.
///
/// Solo borra lo que esta en el bucket que se le indica: una direccion de otro
/// lado —o de otro de nuestros buckets— se ignora en silencio. Asi, una mision
/// cuya portada se habia cargado antes pegando un enlace de internet no hace
/// fallar nada al reemplazarla.
///
/// Nunca lanza. Borrar la imagen vieja es limpieza, y que falle no puede
/// arruinar la operacion que el administrador si pidio.
export async function borrarImagen(url, bucket) {
  verificarBucket(bucket);

  const nombre = nombreDeLaUrl(url, bucket);
  if (!nombre) return;

  try {
    const res = await fetch(`${config.supabaseUrl}/storage/v1/object/${bucket}/${nombre}`, {
      method: 'DELETE',
      headers: autorizacion(),
    });
    if (!res.ok) {
      console.error(`No se pudo borrar ${nombre} de Storage: ${res.status}`);
    }
  } catch (err) {
    console.error(`No se pudo borrar ${nombre} de Storage:`, err.message);
  }
}

/// El nombre del archivo si la URL es de ese bucket nuestro, o null.
function nombreDeLaUrl(url, bucket) {
  if (typeof url !== 'string') return null;
  const prefijo = `${config.supabaseUrl}/storage/v1/object/public/${bucket}/`;
  if (!url.startsWith(prefijo)) return null;

  const nombre = url.slice(prefijo.length);
  // Solo los nombres que genera subirImagen. Sin esto, una URL armada a mano
  // con ../ podria apuntar a otro lugar del bucket.
  return /^[0-9a-f]{32}\.(png|jpg|webp)$/.test(nombre) ? nombre : null;
}

const autorizacion = () => ({
  Authorization: `Bearer ${config.supabaseServiceKey}`,
  apikey: config.supabaseServiceKey,
});

/// Lo que el administrador hizo mal, y hay que contarle. Se distingue de un
/// fallo de Storage, que es un problema nuestro y va como 500.
export class ErrorDeImagen extends Error {}

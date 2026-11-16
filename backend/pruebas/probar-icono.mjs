// Comprueba la subida y el borrado del ícono de una insignia (ADM25).
//
// Crea su propia insignia y la borra al terminar. Lo que más importa: que el
// tipo se decida por el contenido y no por lo que diga el cliente, y que al
// reemplazar o quitar la imagen no queden archivos huérfanos en el bucket.

import { API, administrador, borrarUsuarios, comprobar, pedir, terminar, tokenDe, visitanteNuevo } from './ayuda.mjs';

// El token se firma aca: la prueba no necesita la contrasenia de nadie.
const token = tokenDe(await administrador(), 'administrador');
const visitantes = [];

// Imágenes mínimas de verdad, generadas acá.
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64'
);
const JPEG = Buffer.from(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a' +
    'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA' +
    'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
  'base64'
);

const sello = Date.now();
let insigniaId = null;
const subidas = [];

/// Cuántos archivos hay en el bucket, preguntándole a Storage directamente.
async function enElBucket() {
  const res = await fetch(process.env.SUPABASE_URL + '/storage/v1/object/list/insignias', {
    method: 'POST',
    headers: {
      Authorization: 'Bearer ' + process.env.SUPABASE_SERVICE_KEY,
      apikey: process.env.SUPABASE_SERVICE_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prefix: '', limit: 1000 }),
  });
  const objetos = await res.json();
  return Array.isArray(objetos) ? objetos.length : -1;
}

const antesDeTodo = await enElBucket();

try {
  const alta = await pedir('POST', '/insignias', token, {
    nombre: 'Prueba ícono ' + sello,
    descripcion: 'Insignia de prueba de la subida de imágenes.',
  });
  insigniaId = alta.cuerpo.insignia.id;
  comprobar('la insignia nueva no tiene ícono', alta.cuerpo.insignia.icono_url === null);

  // ----------------------------------------------------------- subir un PNG
  const conPng = await pedir('POST', `/insignias/${insigniaId}/icono`, token, PNG, 'image/png');
  comprobar('subir un PNG devuelve 200', conPng.estado === 200, 'estado ' + conPng.estado);
  const url1 = conPng.cuerpo?.insignia?.icono_url;
  comprobar('y devuelve una dirección de nuestro bucket',
    typeof url1 === 'string' && url1.includes('/storage/v1/object/public/insignias/'), url1);
  subidas.push(url1);

  const publica = await fetch(url1);
  comprobar('la imagen se lee sin credenciales', publica.status === 200,
    'estado ' + publica.status);
  comprobar('y es la que subimos',
    Buffer.from(await publica.arrayBuffer()).equals(PNG));

  comprobar('hay un archivo más en el bucket', (await enElBucket()) === antesDeTodo + 1);

  // -------------------------------------- reemplazarla no deja el anterior
  const conJpeg = await pedir('POST', `/insignias/${insigniaId}/icono`, token, JPEG, 'image/jpeg');
  comprobar('reemplazar por un JPEG devuelve 200', conJpeg.estado === 200,
    'estado ' + conJpeg.estado);
  const url2 = conJpeg.cuerpo?.insignia?.icono_url;
  subidas.push(url2);
  comprobar('la dirección cambia al reemplazar', url2 !== url1);
  comprobar('y la extensión sigue al contenido', url2.endsWith('.jpg'), url2);
  comprobar('sigue habiendo UN archivo: el anterior se borró',
    (await enElBucket()) === antesDeTodo + 1);

  // ------------------------------- el Content-Type del cliente no decide nada
  const mentira = await pedir('POST', `/insignias/${insigniaId}/icono`, token,
    Buffer.from('esto no es una imagen, pero digo que sí'), 'image/png');
  comprobar('un archivo que no es imagen se rechaza aunque diga image/png',
    mentira.estado === 400 && mentira.cuerpo.errores?.icono !== undefined,
    JSON.stringify(mentira.cuerpo));
  comprobar('y no deja nada en el bucket', (await enElBucket()) === antesDeTodo + 1);

  const vacio = await pedir('POST', `/insignias/${insigniaId}/icono`, token,
    Buffer.alloc(0), 'image/png');
  comprobar('un cuerpo vacío se rechaza', vacio.estado === 400, 'estado ' + vacio.estado);

  // -------------------------------------------------------------- quitarla
  const sinIcono = await pedir('DELETE', `/insignias/${insigniaId}/icono`, token);
  comprobar('quitar el ícono devuelve 200', sinIcono.estado === 200, 'estado ' + sinIcono.estado);
  comprobar('y la insignia queda sin ícono',
    sinIcono.cuerpo.insignia.icono_url === null,
    JSON.stringify(sinIcono.cuerpo.insignia.icono_url));
  comprobar('el bucket vuelve a como estaba', (await enElBucket()) === antesDeTodo);

  // ------------------------------------------------------------ no existen
  comprobar('subir a una insignia que no existe devuelve 404',
    (await pedir('POST', '/insignias/999999/icono', token, PNG, 'image/png')).estado === 404);

  // ------------------------------------------------------------- seguridad
  // El visitante se crea en la base y su token se firma acá, en lugar de
  // registrarse y entrar: el login tiene límite de intentos (SIS04) y esta
  // prueba gastaría una cuota que no necesita.
  const visitante = await visitanteNuevo('Visitante de la prueba del ícono');
  visitantes.push(visitante.id);
  comprobar('un visitante no puede subir íconos',
    (await pedir('POST', `/insignias/${insigniaId}/icono`, visitante.token, PNG, 'image/png')).estado === 403);
} finally {
  if (insigniaId) {
    await pedir('DELETE', '/insignias/' + insigniaId, token);
    console.log('\nInsignia de prueba ' + insigniaId + ' borrada.');
  }
  await borrarUsuarios(visitantes);
  console.log('Archivos en el bucket al terminar: ' + (await enElBucket()) +
    ' (había ' + antesDeTodo + ')');
}

await terminar();

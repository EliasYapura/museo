// Comprueba la portada de una mision (ADM26).
//
// Lo que importa: que la imagen no se borre al guardar el formulario —el error
// que tuvimos con las insignias—, que el tipo lo decida el contenido y no el
// cliente, y que no queden archivos huerfanos en el bucket.
//
// El token se firma aca con el secreto del .env, en vez de entrar con usuario
// y contrasenia: la prueba no necesita credenciales de nadie.
//
// Se corre desde backend/ con --env-file=.env

import { API, NO_ES_IMAGEN, administrador, bd, comprobar, pedir, pngDeUnPixel, terminar, tokenDe } from './ayuda.mjs';

import { config } from '../src/config.js';

// --- el administrador con el que se prueba --------------------------------
const admins = await bd.query(
  "SELECT id, email FROM usuarios WHERE rol = 'administrador' AND activo = TRUE ORDER BY id LIMIT 1"
);
if (!admins.rows[0]) {
  console.error('No hay ningun administrador activo en la base.');
  process.exit(2);
}
const adminId = admins.rows[0].id;
console.log(`probando como administrador id ${adminId}`);

const token = tokenDe(adminId, 'administrador');

const PNG_ROJO = pngDeUnPixel([0xd0, 0x30, 0x30]);
const PNG_VERDE = pngDeUnPixel([0x30, 0xd0, 0x30]);

// --- una mision propia para la prueba ------------------------------------
const alta = await pedir('POST', '/misiones', token, {
  nombre: `Portada de prueba ${Date.now()}`,
  descripcion: 'Mision creada por la prueba automatica de ADM26.',
  duracion_estimada: 30,
  // Se manda a proposito: la API tiene que ignorarlo.
  imagen_url: 'https://ejemplo.invalido/colada.png',
});
comprobar('crear la mision', alta.estado === 201, `estado ${alta.estado}`);
const mision = alta.cuerpo?.mision;
if (!mision) {
  console.error('Sin mision no se puede seguir.');
  process.exit(2);
}
comprobar('el alta ignora imagen_url del cuerpo', mision.imagen_url === null, String(mision.imagen_url));

const id = mision.id;
const urlPublica = (u) => u ?? '(sin imagen)';

try {
  // --- subir ---------------------------------------------------------------
  const sinNada = await pedir('POST', `/misiones/${id}/imagen`, token, Buffer.alloc(0), 'image/png');
  comprobar('cuerpo vacio -> 400', sinNada.estado === 400, `estado ${sinNada.estado}`);

  const falsa = await pedir('POST', `/misiones/${id}/imagen`, token, NO_ES_IMAGEN, 'image/png');
  comprobar(
    'un PDF disfrazado de PNG -> 400',
    falsa.estado === 400 && /no es una imagen/i.test(falsa.cuerpo?.errores?.imagen ?? ''),
    `estado ${falsa.estado} ${JSON.stringify(falsa.cuerpo?.errores ?? {})}`
  );

  const subida = await pedir('POST', `/misiones/${id}/imagen`, token, PNG_ROJO, 'image/png');
  comprobar('subir la portada', subida.estado === 200, `estado ${subida.estado}`);
  const primera = subida.cuerpo?.mision?.imagen_url;
  comprobar(
    'la direccion es del bucket de misiones',
    typeof primera === 'string' && primera.includes('/object/public/misiones/'),
    urlPublica(primera)
  );

  const bajada = await fetch(primera);
  comprobar('la imagen se puede descargar', bajada.ok, `estado ${bajada.status}`);
  const bytes = Buffer.from(await bajada.arrayBuffer());
  comprobar('es la misma imagen que subimos', bytes.equals(PNG_ROJO), `${bytes.length} bytes`);

  // --- lo que fallo con las insignias -------------------------------------
  const guardado = await pedir('PUT', `/misiones/${id}`, token, {
    nombre: `Portada de prueba ${Date.now()} editada`,
    descripcion: 'Se le cambia el nombre, no la portada.',
    duracion_estimada: 45,
  });
  comprobar('editar la mision', guardado.estado === 200, `estado ${guardado.estado}`);
  comprobar(
    'guardar el formulario NO borra la portada',
    guardado.cuerpo?.mision?.imagen_url === primera,
    urlPublica(guardado.cuerpo?.mision?.imagen_url)
  );

  // --- reemplazar ----------------------------------------------------------
  const segunda = await pedir('POST', `/misiones/${id}/imagen`, token, PNG_VERDE, 'image/png');
  const urlSegunda = segunda.cuerpo?.mision?.imagen_url;
  comprobar('reemplazar la portada', segunda.estado === 200, `estado ${segunda.estado}`);
  comprobar('la direccion cambia al reemplazar', urlSegunda !== primera, urlPublica(urlSegunda));

  // Se mira la lista del bucket y no la URL publica: Storage sirve las URLs
  // publicas por una cache de borde que sigue respondiendo un rato despues de
  // borrar el archivo, asi que bajarla no prueba nada.
  const nombreViejo = primera.split('/').pop();
  const lista = await fetch(`${config.supabaseUrl}/storage/v1/object/list/misiones`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${config.supabaseServiceKey}`,
      apikey: config.supabaseServiceKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ prefix: '', limit: 1000 }),
  });
  const archivos = lista.ok ? (await lista.json()).map((a) => a.name) : null;
  comprobar(
    'la portada anterior se borro del bucket',
    archivos !== null && !archivos.includes(nombreViejo),
    archivos === null ? `no pude listar (${lista.status})` : `${archivos.length} archivos en el bucket`
  );

  // --- quitar --------------------------------------------------------------
  const quitada = await pedir('DELETE', `/misiones/${id}/imagen`, token);
  comprobar('quitar la portada', quitada.estado === 200, `estado ${quitada.estado}`);
  comprobar(
    'queda sin imagen',
    quitada.cuerpo?.mision?.imagen_url === null,
    urlPublica(quitada.cuerpo?.mision?.imagen_url)
  );

  const antes = await bd.query('SELECT actualizada_en FROM misiones WHERE id = $1', [id]);
  const otraVez = await pedir('DELETE', `/misiones/${id}/imagen`, token);
  const despues = await bd.query('SELECT actualizada_en FROM misiones WHERE id = $1', [id]);
  comprobar('quitarla dos veces no falla', otraVez.estado === 200, `estado ${otraVez.estado}`);
  comprobar(
    'quitar una portada que no esta no mueve la fecha de modificacion',
    antes.rows[0].actualizada_en.getTime() === despues.rows[0].actualizada_en.getTime(),
    `${antes.rows[0].actualizada_en.toISOString()} vs ${despues.rows[0].actualizada_en.toISOString()}`
  );

  // --- misiones que no existen --------------------------------------------
  const inexistente = await pedir('POST', '/misiones/999999/imagen', token, PNG_ROJO, 'image/png');
  comprobar('mision inexistente -> 404', inexistente.estado === 404, `estado ${inexistente.estado}`);

  const sinToken = await pedir('POST', `/misiones/${id}/imagen`, null, PNG_ROJO, 'image/png');
  comprobar('sin token -> 401', sinToken.estado === 401, `estado ${sinToken.estado}`);
} finally {
  // --- limpieza ------------------------------------------------------------
  await bd.query('DELETE FROM misiones WHERE id = $1', [id]);
  console.log(`mision de prueba ${id} borrada`);
  }

await terminar();

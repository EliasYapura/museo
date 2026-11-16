// Comprueba la foto de una pieza (ADM26).
//
// Lo mismo que se comprobo con la portada de una mision, mas dos cosas que
// solo pasan con los objetos: que borrar la pieza se lleve su archivo —la fila
// desaparece de verdad, no se archiva— y que el visitante reciba la foto al
// escanear el codigo correcto, pero no al escanear uno equivocado.
//
// Se corre desde backend/ con --env-file=.env

import { API, NO_ES_IMAGEN, administrador, archivosDelBucket, bd, comprobar, pedir, pngDeUnPixel, terminar, tokenDe } from './ayuda.mjs';

const PNG_A = pngDeUnPixel([0xd0, 0x30, 0x30]);
const PNG_B = pngDeUnPixel([0x30, 0x30, 0xd0]);

// --- el administrador con el que se prueba --------------------------------
const admins = await bd.query(
  "SELECT id FROM usuarios WHERE rol = 'administrador' AND activo = TRUE ORDER BY id LIMIT 1"
);
if (!admins.rows[0]) {
  console.error('No hay ningun administrador activo en la base.');
  process.exit(2);
}
const token = tokenDe(Number(admins.rows[0].id), 'administrador');

const salas = await bd.query('SELECT id FROM salas ORDER BY id LIMIT 1');
if (!salas.rows[0]) {
  console.error('No hay ninguna sala en la base.');
  process.exit(2);
}

// --- una pieza propia para la prueba -------------------------------------
const alta = await pedir('POST', '/objetos', token, {
  nombre: `Pieza de prueba ${Date.now()}`,
  sala_id: salas.rows[0].id,
  dato_clave: 'Dato clave de la prueba automatica de ADM26.',
  descripcion: 'Pieza creada por la prueba automatica.',
  // Se manda a proposito: la API tiene que ignorarlo.
  imagen_url: 'https://ejemplo.invalido/colada.png',
});
comprobar('registrar la pieza', alta.estado === 201, `estado ${alta.estado}`);
const objeto = alta.cuerpo?.objeto;
if (!objeto) {
  console.error('Sin pieza no se puede seguir.');
  process.exit(2);
}
comprobar('el alta ignora imagen_url del cuerpo', objeto.imagen_url === null, String(objeto.imagen_url));

const id = objeto.id;
let borrada = false;

try {
  // --- subir ---------------------------------------------------------------
  const vacio = await pedir('POST', `/objetos/${id}/imagen`, token, Buffer.alloc(0), 'image/png');
  comprobar('cuerpo vacio -> 400', vacio.estado === 400, `estado ${vacio.estado}`);

  const falsa = await pedir('POST', `/objetos/${id}/imagen`, token, NO_ES_IMAGEN, 'image/png');
  comprobar(
    'un archivo que no es imagen -> 400',
    falsa.estado === 400 && /no es una imagen/i.test(falsa.cuerpo?.errores?.imagen ?? ''),
    `estado ${falsa.estado}`
  );

  const subida = await pedir('POST', `/objetos/${id}/imagen`, token, PNG_A, 'image/png');
  comprobar('subir la foto', subida.estado === 200, `estado ${subida.estado}`);
  const primera = subida.cuerpo?.objeto?.imagen_url;
  comprobar(
    'la direccion es del bucket de objetos',
    typeof primera === 'string' && primera.includes('/object/public/objetos/'),
    String(primera)
  );
  comprobar(
    'la respuesta trae la sala y la categoria',
    subida.cuerpo?.objeto?.sala !== undefined && 'categoria' in (subida.cuerpo?.objeto ?? {}),
    JSON.stringify({ sala: subida.cuerpo?.objeto?.sala, categoria: subida.cuerpo?.objeto?.categoria })
  );

  const bajada = await fetch(primera);
  const bytes = Buffer.from(await bajada.arrayBuffer());
  comprobar('es la misma imagen que subimos', bajada.ok && bytes.equals(PNG_A), `${bytes.length} bytes`);

  // --- lo que fallo con las insignias -------------------------------------
  const guardado = await pedir('PUT', `/objetos/${id}`, token, {
    nombre: `Pieza de prueba ${Date.now()} editada`,
    sala_id: salas.rows[0].id,
    dato_clave: 'Se le cambia el nombre, no la foto.',
  });
  comprobar('editar la pieza', guardado.estado === 200, `estado ${guardado.estado}`);
  comprobar(
    'guardar el formulario NO borra la foto',
    guardado.cuerpo?.objeto?.imagen_url === primera,
    String(guardado.cuerpo?.objeto?.imagen_url)
  );

  // --- reemplazar ----------------------------------------------------------
  const segunda = await pedir('POST', `/objetos/${id}/imagen`, token, PNG_B, 'image/png');
  const urlSegunda = segunda.cuerpo?.objeto?.imagen_url;
  comprobar('reemplazar la foto', segunda.estado === 200, `estado ${segunda.estado}`);
  comprobar('la direccion cambia al reemplazar', urlSegunda !== primera, String(urlSegunda));

  // Se mira la lista del bucket y no la URL publica: Storage sirve las URLs
  // publicas por una cache de borde que sigue respondiendo un rato despues de
  // borrar el archivo, asi que bajarla no prueba nada.
  const tras = await archivosDelBucket('objetos');
  comprobar(
    'la foto anterior se borro del bucket',
    !tras.includes(primera.split('/').pop()),
    `${tras.length} archivos`
  );

  // --- lo que ve el visitante al escanear ----------------------------------
  const desafio = await bd.query(
    `WITH m AS (
       INSERT INTO misiones (nombre, descripcion, duracion_estimada, activa, creada_por)
       VALUES ($2, 'Mision de la prueba de ADM26', 20, TRUE, $3)
       RETURNING id
     )
     INSERT INTO desafios (mision_id, tipo, enunciado, puntos, orden, objeto_id)
     SELECT m.id, 'escaneo_objeto', 'Encontra la pieza de prueba', 10, 1, $1 FROM m
     RETURNING id, mision_id`,
    [id, `Mision de prueba ADM26 ${Date.now()}`, admins.rows[0].id]
  );
  const desafioId = desafio.rows[0].id;
  const misionId = desafio.rows[0].mision_id;

  const codigo = (await bd.query('SELECT codigo FROM objetos WHERE id = $1', [id])).rows[0].codigo;

  const bien = await pedir('POST', `/publico/desafios/${desafioId}/escaneo`, null, { codigo });
  comprobar('escaneo correcto', bien.cuerpo?.correcto === true, `estado ${bien.estado}`);
  comprobar(
    'el escaneo correcto devuelve la foto',
    bien.cuerpo?.imagen_url === urlSegunda,
    String(bien.cuerpo?.imagen_url)
  );

  const mal = await pedir('POST', `/publico/desafios/${desafioId}/escaneo`, null, {
    codigo: 'OBJ-NOEXISTE',
  });
  comprobar('escaneo equivocado', mal.cuerpo?.correcto === false, `estado ${mal.estado}`);
  comprobar(
    'el escaneo equivocado NO filtra la foto',
    mal.cuerpo?.imagen_url === undefined && mal.cuerpo?.pieza === undefined,
    JSON.stringify(mal.cuerpo)
  );

  await bd.query('DELETE FROM desafios WHERE id = $1', [desafioId]);
  await bd.query('DELETE FROM misiones WHERE id = $1', [misionId]);

  // --- quitar --------------------------------------------------------------
  const quitada = await pedir('DELETE', `/objetos/${id}/imagen`, token);
  comprobar('quitar la foto', quitada.estado === 200, `estado ${quitada.estado}`);
  comprobar('queda sin foto', quitada.cuerpo?.objeto?.imagen_url === null, String(quitada.cuerpo?.objeto?.imagen_url));
  const otraVez = await pedir('DELETE', `/objetos/${id}/imagen`, token);
  comprobar('quitarla dos veces no falla', otraVez.estado === 200, `estado ${otraVez.estado}`);

  // --- borrar la pieza se lleva su archivo ---------------------------------
  const ultima = await pedir('POST', `/objetos/${id}/imagen`, token, PNG_A, 'image/png');
  const urlUltima = ultima.cuerpo?.objeto?.imagen_url;
  const borrado = await pedir('DELETE', `/objetos/${id}`, token);
  comprobar('borrar la pieza', borrado.estado === 204, `estado ${borrado.estado}`);
  borrada = borrado.estado === 204;

  const alFinal = await archivosDelBucket('objetos');
  comprobar(
    'borrar la pieza borra tambien su archivo',
    !alFinal.includes(urlUltima.split('/').pop()),
    `${alFinal.length} archivos quedaron`
  );

  // --- sin permiso ---------------------------------------------------------
  const sinToken = await pedir('POST', `/objetos/${id}/imagen`, null, PNG_A, 'image/png');
  comprobar('sin token -> 401', sinToken.estado === 401, `estado ${sinToken.estado}`);
} finally {
  if (!borrada) {
    await bd.query('DELETE FROM objetos WHERE id = $1', [id]);
    console.log(`pieza de prueba ${id} borrada en la limpieza`);
  }
  }

await terminar();

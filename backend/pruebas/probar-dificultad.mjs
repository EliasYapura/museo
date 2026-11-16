// Comprueba que la dificultad la calcule el servidor y que se mantenga al dia
// cuando cambia la mision o sus desafios (ADM03).
//
// Crea su propia mision de prueba y la deja archivada al terminar.

import { API, administrador, comprobar, pedir, terminar, tokenDe } from './ayuda.mjs';

// El token se firma aca: la prueba no necesita la contrasenia de nadie.
const token = tokenDe(await administrador(), 'administrador');

const sello = Date.now();
let misionId = null;

const dificultadDe = async (id) =>
  (await pedir('GET', '/misiones/' + id, token)).cuerpo?.mision?.dificultad;

async function agregarDesafio(tipo, extra = {}) {
  const cuerpo = {
    tipo,
    enunciado: 'Desafío de prueba de ADM03 ' + sello,
    puntos: 10,
    ...extra,
  };
  // La configuración va suelta en el cuerpo, no anidada: el servidor la arma
  // según el tipo (validarSegunTipo, en validaciones/desafio.js).
  if (tipo === 'pregunta_opcion_multiple') {
    cuerpo.opciones = ['Una', 'Otra'];
    cuerpo.respuesta_correcta = 'Una';
  }
  if (tipo === 'respuesta_corta') {
    cuerpo.tolerancia = 'exacta';
    cuerpo.respuesta_correcta = 'Una';
  }
  const res = await pedir('POST', '/misiones/' + misionId + '/desafios', token, cuerpo);
  if (res.estado !== 201) throw new Error('no pude crear el desafío: ' + JSON.stringify(res.cuerpo));
  return res.cuerpo.desafio.id;
}

try {
  // ---------------------------------------------------- mision recien creada
  // 15 minutos, sin desafios -> 15/15 = 1 punto -> facil
  const alta = await pedir('POST', '/misiones', token, {
    nombre: 'Prueba ADM03 ' + sello,
    descripcion: 'Mision de prueba del calculo de dificultad.',
    duracion_estimada: 15,
    dificultad: 'dificil', // se manda a proposito: tiene que ignorarse
  });
  comprobar('crear una misión devuelve 201', alta.estado === 201, 'estado ' + alta.estado);
  misionId = alta.cuerpo.mision.id;
  comprobar(
    'la dificultad que manda el cliente se ignora',
    alta.cuerpo.mision.dificultad === 'facil',
    'quedó ' + alta.cuerpo.mision.dificultad
  );

  // ------------------------------------------------- sumar desafios la sube
  // 1 + 1 opcion multiple = 2 -> facil
  const d1 = await agregarDesafio('pregunta_opcion_multiple');
  comprobar('con una pregunta sigue siendo fácil', (await dificultadDe(misionId)) === 'facil');

  // 1 + 1 + 2 escaneo + 2 escaneo = 6 -> media
  const objetos = (await pedir('GET', '/objetos', token)).cuerpo.objetos.filter((o) => o.activo);
  const d2 = await agregarDesafio('escaneo_objeto', { objeto_id: objetos[0].id });
  const d3 = await agregarDesafio('escaneo_objeto', { objeto_id: objetos[1].id });
  comprobar(
    'con dos escaneos pasa a media',
    (await dificultadDe(misionId)) === 'media',
    'quedó ' + (await dificultadDe(misionId))
  );

  // 1 + 1 + 2 + 2 + 3 busqueda = 9 -> dificil
  await agregarDesafio('busqueda_guiada', { objeto_id: objetos[2].id });
  comprobar(
    'una búsqueda guiada la lleva a difícil',
    (await dificultadDe(misionId)) === 'dificil',
    'quedó ' + (await dificultadDe(misionId))
  );

  // ------------------------------------------------ cambiar el tipo la mueve
  // El escaneo (2) pasa a opcion multiple (1): 9 - 1 = 8 -> media
  const cambio = await pedir('PUT', '/desafios/' + d2, token, {
    tipo: 'pregunta_opcion_multiple',
    enunciado: 'Cambiado a opción múltiple ' + sello,
    puntos: 10,
    opciones: ['Una', 'Otra'],
    respuesta_correcta: 'Una',
  });
  comprobar('cambiar el tipo devuelve 200', cambio.estado === 200, 'estado ' + cambio.estado);
  comprobar(
    'al aflojar un desafío la dificultad baja a media',
    (await dificultadDe(misionId)) === 'media',
    'quedó ' + (await dificultadDe(misionId))
  );

  // ------------------------------------------------- borrar un desafio baja
  await pedir('DELETE', '/desafios/' + d3, token);
  comprobar(
    'borrar un escaneo la deja en media',
    (await dificultadDe(misionId)) === 'media',
    'quedó ' + (await dificultadDe(misionId))
  );

  // ---------------------------------------------- la duracion tambien cuenta
  // Mismos desafios (6) pero 240 minutos: 6 + 16 = 22 -> dificil
  const edicion = await pedir('PUT', '/misiones/' + misionId, token, {
    nombre: 'Prueba ADM03 ' + sello,
    descripcion: 'Mision de prueba del calculo de dificultad.',
    duracion_estimada: 240,
  });
  comprobar('editar la misión devuelve 200', edicion.estado === 200, 'estado ' + edicion.estado);
  comprobar(
    'alargar la misión la vuelve difícil',
    edicion.cuerpo.mision.dificultad === 'dificil',
    'quedó ' + edicion.cuerpo.mision.dificultad
  );

  // ------------------------------------- guardar sin cambios no mueve la fecha
  const antes = (await pedir('GET', '/misiones/' + misionId, token)).cuerpo.mision;
  const sinCambios = await pedir('PUT', '/misiones/' + misionId, token, {
    nombre: antes.nombre,
    descripcion: antes.descripcion,
    duracion_estimada: antes.duracion_estimada,
    imagen_url: antes.imagen_url,
  });
  comprobar('guardar sin cambios informa que no modificó nada', sinCambios.cuerpo.modificada === false);
  comprobar(
    'y no mueve la fecha de última modificación',
    sinCambios.cuerpo.mision.actualizada_en === antes.actualizada_en,
    antes.actualizada_en + ' -> ' + sinCambios.cuerpo.mision.actualizada_en
  );

  // ---------------------------------------- el visitante ve la misma dificultad
  await pedir('PATCH', '/misiones/' + misionId + '/activa', token, { activa: true });
  const publica = await pedir('GET', '/publico/misiones/' + misionId, null);
  comprobar(
    'el visitante ve la dificultad calculada',
    publica.cuerpo?.mision?.dificultad === 'dificil',
    'vio ' + publica.cuerpo?.mision?.dificultad
  );
  await pedir('PATCH', '/misiones/' + misionId + '/activa', token, { activa: false });
} finally {
  if (misionId) {
    await pedir('PATCH', '/misiones/' + misionId + '/archivada', token, { archivada: true });
    console.log('\nMisión de prueba ' + misionId + ' archivada.');
  }
}

await terminar();

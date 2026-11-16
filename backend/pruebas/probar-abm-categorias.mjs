// Comprueba el alta, la edición y el borrado de categorías, y sobre todo que
// borrar una NO borre las piezas que la tenían.
//
// Crea su propia categoría y su propio objeto, y los limpia al terminar.

import { API, administrador, comprobar, pedir, terminar, tokenDe } from './ayuda.mjs';

// El token se firma aca: la prueba no necesita la contrasenia de nadie.
const token = tokenDe(await administrador(), 'administrador');

const sello = Date.now();
let categoriaId = null;
let otraId = null;
let objetoId = null;

try {
  // ------------------------------------------------------------------ alta
  const creada = await pedir('POST', '/categorias', token, {
    nombre: 'Prueba ABM ' + sello,
  });
  comprobar('crear devuelve 201', creada.estado === 201, 'estado ' + creada.estado);
  categoriaId = creada.cuerpo.categoria?.id;
  comprobar('la categoría nueva nace sin piezas', creada.cuerpo.categoria?.objetos === 0,
    JSON.stringify(creada.cuerpo.categoria?.objetos));

  // ----------------------------------------------------------- validaciones
  const sinNombre = await pedir('POST', '/categorias', token, {});
  comprobar('sin nombre rechaza con 400',
    sinNombre.estado === 400 && sinNombre.cuerpo.errores?.nombre !== undefined);

  const largo = await pedir('POST', '/categorias', token, { nombre: 'x'.repeat(81) });
  comprobar('un nombre de 81 caracteres rechaza con 400', largo.estado === 400);

  const repetida = await pedir('POST', '/categorias', token, { nombre: 'Prueba ABM ' + sello });
  comprobar('un nombre repetido devuelve 409',
    repetida.estado === 409 && repetida.cuerpo.errores?.nombre !== undefined,
    'estado ' + repetida.estado);

  // --------------------------------------------------------------- edición
  const renombrada = await pedir('PUT', '/categorias/' + categoriaId, token, {
    nombre: 'Prueba ABM renombrada ' + sello,
  });
  comprobar('renombrar devuelve 200 y el nombre nuevo',
    renombrada.estado === 200 && renombrada.cuerpo.categoria.nombre.includes('renombrada'));

  otraId = (await pedir('POST', '/categorias', token, { nombre: 'Prueba ABM otra ' + sello }))
    .cuerpo.categoria.id;
  const choque = await pedir('PUT', '/categorias/' + otraId, token, {
    nombre: 'Prueba ABM renombrada ' + sello,
  });
  comprobar('renombrar al nombre de otra devuelve 409', choque.estado === 409,
    'estado ' + choque.estado);

  // ------------------------------------ una pieza clasificada con la nueva
  const salas = (await pedir('GET', '/salas', token)).cuerpo.salas;
  const objeto = await pedir('POST', '/objetos', token, {
    nombre: 'Pieza de prueba ABM ' + sello,
    sala_id: salas[0].id,
    dato_clave: 'Dato de prueba.',
    categoria_id: categoriaId,
  });
  objetoId = objeto.cuerpo.objeto.id;
  comprobar('la pieza queda clasificada', objeto.cuerpo.objeto.categoria_id === categoriaId);

  const conPieza = (await pedir('GET', '/categorias', token)).cuerpo.categorias
    .find((c) => c.id === categoriaId);
  comprobar('la categoría ahora cuenta una pieza', conPieza?.objetos === 1,
    JSON.stringify(conPieza?.objetos));

  // Renombrar no desclasifica.
  await pedir('PUT', '/categorias/' + categoriaId, token, {
    nombre: 'Prueba ABM final ' + sello,
  });
  const trasRenombrar = await pedir('GET', '/objetos/' + objetoId, token);
  comprobar('renombrar no desclasifica la pieza',
    trasRenombrar.cuerpo.objeto.categoria_id === categoriaId);
  comprobar('y la pieza muestra el nombre nuevo',
    trasRenombrar.cuerpo.objeto.categoria.includes('final'),
    trasRenombrar.cuerpo.objeto.categoria);

  // ------------------------------------------------------------- borrado
  const sinClasificarAntes = (await pedir('GET', '/categorias', token)).cuerpo.sin_categoria;

  const borrada = await pedir('DELETE', '/categorias/' + categoriaId, token);
  comprobar('borrar devuelve 200', borrada.estado === 200, 'estado ' + borrada.estado);
  comprobar('y avisa cuántas piezas quedaron sueltas',
    borrada.cuerpo.sin_clasificar === 1, JSON.stringify(borrada.cuerpo));

  const pieza = await pedir('GET', '/objetos/' + objetoId, token);
  comprobar('LA PIEZA NO SE BORRÓ', pieza.estado === 200, 'estado ' + pieza.estado);
  comprobar('y quedó sin categoría', pieza.cuerpo.objeto.categoria_id === null,
    JSON.stringify(pieza.cuerpo.objeto.categoria_id));

  const despues = await pedir('GET', '/categorias', token);
  comprobar('la cuenta de sin clasificar subió una',
    despues.cuerpo.sin_categoria === sinClasificarAntes + 1,
    despues.cuerpo.sin_categoria + ' vs ' + (sinClasificarAntes + 1));
  comprobar('la categoría ya no está en la lista',
    !despues.cuerpo.categorias.some((c) => c.id === categoriaId));

  categoriaId = null; // ya borrada

  const reborrada = await pedir('DELETE', '/categorias/999999', token);
  comprobar('borrar una que no existe devuelve 404', reborrada.estado === 404);

  // ----------------------------------------------- el nombre vuelve a estar libre
  const reusada = await pedir('POST', '/categorias', token, {
    nombre: 'Prueba ABM final ' + sello,
  });
  comprobar('el nombre de la borrada vuelve a estar libre', reusada.estado === 201,
    'estado ' + reusada.estado);
  if (reusada.estado === 201) categoriaId = reusada.cuerpo.categoria.id;
} finally {
  for (const id of [categoriaId, otraId]) {
    if (id) await pedir('DELETE', '/categorias/' + id, token);
  }
  if (objetoId) {
    const r = await pedir('DELETE', '/objetos/' + objetoId, token);
    console.log('\nPieza de prueba ' + objetoId + ' borrada (estado ' + r.estado + ').');
  }
}

await terminar();

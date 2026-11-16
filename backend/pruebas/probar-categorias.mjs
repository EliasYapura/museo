// Comprueba la clasificación de objetos por categoría y el filtrado (ADM23).
//
// Crea su propio objeto de prueba y lo borra al terminar.

import { API, administrador, borrarUsuarios, comprobar, pedir, terminar, tokenDe, visitanteNuevo } from './ayuda.mjs';

// El token se firma aca: la prueba no necesita la contrasenia de nadie.
const token = tokenDe(await administrador(), 'administrador');

const sello = Date.now();
let objetoId = null;
let visitanteToken = null;
const visitantes = [];

const cuantos = async (filtro) => {
  const ruta = filtro === undefined ? '/objetos' : '/objetos?categoria=' + filtro;
  const res = await pedir('GET', ruta, token);
  return res.cuerpo.objetos.length;
};

try {
  // ------------------------------------------------------------- categorías
  const cats = await pedir('GET', '/categorias', token);
  comprobar('listar categorías devuelve 200', cats.estado === 200, 'estado ' + cats.estado);
  comprobar('vienen con la cuenta de objetos',
    cats.cuerpo.categorias.every((c) => typeof c.objetos === 'number'));
  comprobar('viene cuántas quedaron sin clasificar',
    typeof cats.cuerpo.sin_categoria === 'number',
    JSON.stringify(cats.cuerpo.sin_categoria));

  const conPiezas = cats.cuerpo.categorias.find((c) => c.objetos > 0);
  const vacia = cats.cuerpo.categorias.find((c) => c.objetos === 0);
  if (!conPiezas || !vacia) throw new Error('necesito una categoría con piezas y otra vacía');

  // ----------------------------------------------- alta con y sin categoría
  const salas = (await pedir('GET', '/salas', token)).cuerpo.salas;

  const sinCat = await pedir('POST', '/objetos', token, {
    nombre: 'Prueba ADM23 sin categoría ' + sello,
    sala_id: salas[0].id,
    dato_clave: 'Dato de prueba.',
  });
  comprobar('se puede crear una pieza sin categoría', sinCat.estado === 201,
    'estado ' + sinCat.estado);
  comprobar('y queda con categoría nula', sinCat.cuerpo.objeto.categoria_id === null,
    JSON.stringify(sinCat.cuerpo.objeto.categoria_id));
  objetoId = sinCat.cuerpo.objeto.id;

  // ------------------------------------------------- asignar una categoría
  const clasificado = await pedir('PUT', '/objetos/' + objetoId, token, {
    nombre: 'Prueba ADM23 sin categoría ' + sello,
    sala_id: salas[0].id,
    dato_clave: 'Dato de prueba.',
    categoria_id: vacia.id,
  });
  comprobar('asignarle una categoría cuenta como cambio',
    clasificado.cuerpo.modificado === true);
  comprobar('y devuelve el nombre de la categoría',
    clasificado.cuerpo.objeto.categoria === vacia.nombre,
    clasificado.cuerpo.objeto.categoria);

  // Guardar lo mismo otra vez no es un cambio.
  const otraVez = await pedir('PUT', '/objetos/' + objetoId, token, {
    nombre: 'Prueba ADM23 sin categoría ' + sello,
    sala_id: salas[0].id,
    dato_clave: 'Dato de prueba.',
    categoria_id: vacia.id,
  });
  comprobar('guardar sin cambios no cuenta como cambio', otraVez.cuerpo.modificado === false);

  // ------------------------------------------------------------- filtrado
  const enVacia = await cuantos(vacia.id);
  comprobar('el filtro por categoría trae sólo esa', enVacia === 1, enVacia + ' objetos');

  const total = await cuantos();
  const sinClasificar = await cuantos('sin');
  const porCategoria = await Promise.all(
    cats.cuerpo.categorias.map((c) => cuantos(c.id))
  );
  const suma = porCategoria.reduce((a, b) => a + b, 0) + sinClasificar;
  comprobar('las partes suman el total', suma === total,
    suma + ' vs ' + total);

  const basura = await cuantos('pepe');
  comprobar('un filtro con basura devuelve la lista entera', basura === total,
    basura + ' vs ' + total);

  // -------------------------------------------------- sacarle la categoría
  const desclasificado = await pedir('PUT', '/objetos/' + objetoId, token, {
    nombre: 'Prueba ADM23 sin categoría ' + sello,
    sala_id: salas[0].id,
    dato_clave: 'Dato de prueba.',
    categoria_id: null,
  });
  comprobar('sacarle la categoría cuenta como cambio',
    desclasificado.cuerpo.modificado === true);
  comprobar('y vuelve a quedar sin clasificar',
    desclasificado.cuerpo.objeto.categoria_id === null,
    JSON.stringify(desclasificado.cuerpo.objeto.categoria_id));

  const sinClasificarAhora = await cuantos('sin');
  comprobar('vuelve a aparecer entre las sin clasificar',
    sinClasificarAhora === sinClasificar + 1,
    sinClasificarAhora + ' vs ' + (sinClasificar + 1));

  // ----------------------------------------------- una categoría que no existe
  const inventada = await pedir('PUT', '/objetos/' + objetoId, token, {
    nombre: 'Prueba ADM23 sin categoría ' + sello,
    sala_id: salas[0].id,
    dato_clave: 'Dato de prueba.',
    categoria_id: 999999,
  });
  comprobar('una categoría inexistente devuelve 400',
    inventada.estado === 400 && inventada.cuerpo.errores?.categoria_id !== undefined,
    JSON.stringify(inventada.cuerpo));

  const noEntero = await pedir('POST', '/objetos', token, {
    nombre: 'x', sala_id: salas[0].id, dato_clave: 'y', categoria_id: 'tres',
  });
  comprobar('una categoría que no es número devuelve 400', noEntero.estado === 400);

  // ------------------------------------------------------------- seguridad
  // El visitante se crea en la base y su token se firma acá, en lugar de
  // registrarse y entrar: el login tiene límite de intentos (SIS04) y esta
  // prueba gastaría una cuota que no necesita para nada.
  const visitante = await visitanteNuevo('Visitante de la prueba de categorías');
  visitantes.push(visitante.id);
  visitanteToken = visitante.token;

  comprobar('sin token no se listan las categorías',
    (await pedir('GET', '/categorias', null)).estado === 401);
  comprobar('un visitante tampoco',
    (await pedir('GET', '/categorias', visitanteToken)).estado === 403);
} finally {
  if (objetoId) {
    const borrado = await pedir('DELETE', '/objetos/' + objetoId, token);
    console.log('\nObjeto de prueba ' + objetoId + ' borrado (estado ' + borrado.estado + ').');
  }
  await borrarUsuarios(visitantes);
}

await terminar();

// Comprueba lo que ve el administrador de las valoraciones (ADM26).
//
// Lo que importa: que el promedio y el reparto sean los correctos, que una
// mision sin calificar devuelva null y no cero, y que las subconsultas nuevas
// no rompan el alta ni la edicion —van dentro del RETURNING, que es donde se
// podrian haber roto sin que se note en el listado—.
//
// Crea su propia mision y sus propios visitantes, y los borra al terminar.
//
// Se corre desde backend/ con --env-file=.env

import { API, administrador, bd, comprobar, pedir, terminar, tokenDe } from './ayuda.mjs';

const marca = Date.now();
const visitantes = [];
let conValoraciones = null;
let sinValoraciones = null;

try {
  const admin = await bd.query(
    "SELECT id FROM usuarios WHERE rol = 'administrador' AND activo = TRUE ORDER BY id LIMIT 1"
  );
  const adminId = admin.rows[0].id;
  const tokenAdmin = tokenDe(adminId, 'administrador');

  // --- una mision calificada y otra sin calificar --------------------------
  const a = await bd.query(
    `INSERT INTO misiones (nombre, descripcion, duracion_estimada, activa, creada_por)
     VALUES ($1, 'Mision calificada de la prueba ADM26', 20, TRUE, $2) RETURNING id`,
    [`ADM26 calificada ${marca}`, adminId]
  );
  // Number(): pg entrega los bigint como texto y la API como numero.
  conValoraciones = Number(a.rows[0].id);

  const b = await bd.query(
    `INSERT INTO misiones (nombre, descripcion, duracion_estimada, activa, creada_por)
     VALUES ($1, 'Mision sin calificar de la prueba ADM26', 20, TRUE, $2) RETURNING id`,
    [`ADM26 sin calificar ${marca}`, adminId]
  );
  sinValoraciones = Number(b.rows[0].id);

  // Tres visitantes que la terminaron y la califican con 5, 3 y 3.
  // Promedio 3.67 y reparto [0, 0, 2, 0, 1].
  const estrellasDeCadaUno = [5, 3, 3];
  for (let i = 0; i < estrellasDeCadaUno.length; i++) {
    const u = await bd.query(
      `INSERT INTO usuarios (email, password_hash, nombre, rol)
       VALUES ($1, 'no-es-un-hash-valido-solo-para-la-prueba', $2, 'visitante') RETURNING id`,
      [`adm26-${i}-${marca}@prueba.test`, `Visitante ${i} de la prueba ADM26`]
    );
    visitantes.push(u.rows[0].id);

    await bd.query(
      `INSERT INTO progreso_misiones (usuario_id, mision_id, estado, finalizada_en)
       VALUES ($1, $2, 'completada', NOW())`,
      [u.rows[0].id, conValoraciones]
    );

    const token = tokenDe(Number(u.rows[0].id), 'visitante');
    const r = await pedir('POST', `/publico/misiones/${conValoraciones}/valoracion`, token, {
      puntuacion: estrellasDeCadaUno[i],
    });
    if (r.estado !== 200) throw new Error(`no pude calificar con ${estrellasDeCadaUno[i]}: ${r.estado}`);
  }

  // --- el listado ----------------------------------------------------------
  const listado = await pedir('GET', '/misiones', tokenAdmin);
  comprobar('el listado responde', listado.estado === 200, `estado ${listado.estado}`);
  const enListado = listado.cuerpo?.misiones?.find((m) => m.id === conValoraciones);
  comprobar('la mision calificada aparece', enListado !== undefined);
  comprobar('el listado trae la cantidad', enListado?.valoraciones === 3, String(enListado?.valoraciones));
  comprobar(
    'el listado trae el promedio (3.67)',
    enListado?.valoracion_promedio === 3.67,
    String(enListado?.valoracion_promedio)
  );
  comprobar(
    'el promedio llega como numero y no como texto',
    typeof enListado?.valoracion_promedio === 'number',
    typeof enListado?.valoracion_promedio
  );

  const sinNada = listado.cuerpo?.misiones?.find((m) => m.id === sinValoraciones);
  comprobar('sin valoraciones la cantidad es 0', sinNada?.valoraciones === 0, String(sinNada?.valoraciones));
  comprobar(
    'sin valoraciones el promedio es null y no 0',
    sinNada?.valoracion_promedio === null,
    String(sinNada?.valoracion_promedio)
  );

  // --- el detalle ----------------------------------------------------------
  const detalle = await pedir('GET', `/misiones/${conValoraciones}`, tokenAdmin);
  comprobar('el detalle responde', detalle.estado === 200, `estado ${detalle.estado}`);
  const reparto = detalle.cuerpo?.mision?.reparto_valoraciones;
  comprobar('el reparto son siempre cinco numeros', Array.isArray(reparto) && reparto.length === 5, JSON.stringify(reparto));
  comprobar(
    'el reparto es [0,0,2,0,1]',
    JSON.stringify(reparto) === JSON.stringify([0, 0, 2, 0, 1]),
    JSON.stringify(reparto)
  );
  comprobar(
    'el reparto suma la cantidad de valoraciones',
    Array.isArray(reparto) && reparto.reduce((s, n) => s + n, 0) === detalle.cuerpo.mision.valoraciones,
    `${JSON.stringify(reparto)} vs ${detalle.cuerpo?.mision?.valoraciones}`
  );

  const detalleSinNada = await pedir('GET', `/misiones/${sinValoraciones}`, tokenAdmin);
  comprobar(
    'sin valoraciones el reparto son cinco ceros',
    JSON.stringify(detalleSinNada.cuerpo?.mision?.reparto_valoraciones) ===
      JSON.stringify([0, 0, 0, 0, 0]),
    JSON.stringify(detalleSinNada.cuerpo?.mision?.reparto_valoraciones)
  );

  // --- que las subconsultas no rompan el alta ni la edicion ----------------
  const editada = await pedir('PUT', `/misiones/${conValoraciones}`, tokenAdmin, {
    nombre: `ADM26 calificada ${marca} editada`,
    descripcion: 'Se le cambia el nombre para ver el RETURNING.',
    duracion_estimada: 35,
  });
  comprobar('editar la mision sigue funcionando', editada.estado === 200, `estado ${editada.estado}`);
  comprobar(
    'la respuesta del PUT trae las valoraciones',
    editada.cuerpo?.mision?.valoraciones === 3 && editada.cuerpo?.mision?.valoracion_promedio === 3.67,
    JSON.stringify({
      n: editada.cuerpo?.mision?.valoraciones,
      promedio: editada.cuerpo?.mision?.valoracion_promedio,
    })
  );

  const creada = await pedir('POST', '/misiones', tokenAdmin, {
    nombre: `ADM26 recien creada ${marca}`,
    descripcion: 'Para ver el RETURNING del alta.',
    duracion_estimada: 15,
  });
  comprobar('crear una mision sigue funcionando', creada.estado === 201, `estado ${creada.estado}`);
  comprobar(
    'la mision nueva nace sin valoraciones',
    creada.cuerpo?.mision?.valoraciones === 0 && creada.cuerpo?.mision?.valoracion_promedio === null,
    JSON.stringify({
      n: creada.cuerpo?.mision?.valoraciones,
      promedio: creada.cuerpo?.mision?.valoracion_promedio,
    })
  );
  if (creada.cuerpo?.mision?.id) {
    await bd.query('DELETE FROM misiones WHERE id = $1', [creada.cuerpo.mision.id]);
  }

  // --- publicar y despublicar tambien pasan por COLUMNAS -------------------
  const despublicada = await pedir('PATCH', `/misiones/${conValoraciones}/activa`, tokenAdmin, {
    activa: false,
  });
  comprobar(
    'despublicar sigue funcionando y trae las valoraciones',
    despublicada.estado === 200 && despublicada.cuerpo?.mision?.valoraciones === 3,
    `estado ${despublicada.estado}, n ${despublicada.cuerpo?.mision?.valoraciones}`
  );
} finally {
  if (conValoraciones) await bd.query('DELETE FROM misiones WHERE id = $1', [conValoraciones]);
  if (sinValoraciones) await bd.query('DELETE FROM misiones WHERE id = $1', [sinValoraciones]);
  for (const id of visitantes) await bd.query('DELETE FROM usuarios WHERE id = $1', [id]);
  const quedan = await bd.query(
    "SELECT count(*)::int AS n FROM usuarios WHERE email LIKE 'adm26-%@prueba.test'"
  );
  console.log(`limpieza: quedan ${quedan.rows[0].n} usuarios de esta prueba`);
  }

await terminar();

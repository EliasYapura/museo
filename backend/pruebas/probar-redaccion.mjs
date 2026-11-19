// Comprueba la redaccion de desafios con IA (ADM27).
//
// Lo que importa: que la ruta sea solo de administradores, que valide antes de
// gastar una llamada a la IA —tipo, pieza, indicacion—, y que el borrador que
// devuelve pase el mismo validador que el formulario, porque un borrador que
// el formulario rechaza no sirve de nada.
//
// La llamada real a la IA se hace una sola vez y solo si hay clave
// configurada. Sin clave, se comprueba que la ruta avise con 503 en lugar de
// fallar de cualquier manera: es el estado en el que esta un despliegue recien
// hecho, y tiene que ser entendible.
//
// Crea su propia mision y la borra al terminar.
//
// Se corre desde backend/ con --env-file=.env

import { administrador, bd, comprobar, pedir, terminar, tokenDe, visitanteNuevo, borrarUsuarios } from './ayuda.mjs';

import { config } from '../src/config.js';
import { validarDesafio } from '../src/validaciones/desafio.js';

const marca = Date.now();
let misionId = null;
let visitanteId = null;

try {
  const adminId = await administrador();
  const token = tokenDe(adminId, 'administrador');

  const m = await bd.query(
    `INSERT INTO misiones (nombre, descripcion, duracion_estimada, creada_por)
     VALUES ($1, 'Mision de la prueba de ADM27', 20, $2) RETURNING id`,
    [`Prueba ADM27 ${marca}`, adminId]
  );
  misionId = m.rows[0].id;

  // Una pieza real, con dato clave cargado: es lo que la IA necesita para no
  // inventar contenido del museo.
  const o = await bd.query(
    "SELECT id, nombre FROM objetos WHERE codigo = 'MLP-OBJ-005' LIMIT 1"
  );
  const piezaId = o.rows[0].id;

  const ruta = `/misiones/${misionId}/desafios/redaccion`;

  // --- quien puede entrar --------------------------------------------------
  const sinToken = await pedir('POST', ruta, null, { objeto_id: piezaId, tipo: 'respuesta_corta' });
  comprobar('sin token -> 401', sinToken.estado === 401, `estado ${sinToken.estado}`);

  const visitante = await visitanteNuevo('Visitante ADM27');
  visitanteId = visitante.id;
  const comoVisitante = await pedir('POST', ruta, visitante.token, {
    objeto_id: piezaId,
    tipo: 'respuesta_corta',
  });
  comprobar('un visitante no redacta -> 403', comoVisitante.estado === 403, `estado ${comoVisitante.estado}`);

  // --- valida antes de gastar una llamada ----------------------------------
  const tipoMal = await pedir('POST', ruta, token, { objeto_id: piezaId, tipo: 'inventado' });
  comprobar('tipo invalido -> 400', tipoMal.estado === 400, `estado ${tipoMal.estado}`);
  comprobar(
    'y dice que el problema es el tipo',
    tipoMal.cuerpo?.errores?.tipo !== undefined,
    JSON.stringify(tipoMal.cuerpo)
  );

  const sinPieza = await pedir('POST', ruta, token, { tipo: 'respuesta_corta' });
  comprobar('sin pieza -> 400', sinPieza.estado === 400, `estado ${sinPieza.estado}`);
  comprobar(
    'y dice que falta la pieza',
    sinPieza.cuerpo?.errores?.objeto_id !== undefined,
    JSON.stringify(sinPieza.cuerpo)
  );

  const piezaFantasma = await pedir('POST', ruta, token, {
    objeto_id: 999999999,
    tipo: 'respuesta_corta',
  });
  comprobar('pieza inexistente -> 400', piezaFantasma.estado === 400, `estado ${piezaFantasma.estado}`);

  const indicacionMal = await pedir('POST', ruta, token, {
    objeto_id: piezaId,
    tipo: 'respuesta_corta',
    indicacion: 42,
  });
  comprobar('indicacion que no es texto -> 400', indicacionMal.estado === 400, `estado ${indicacionMal.estado}`);

  const misionFantasma = await pedir('POST', '/misiones/999999999/desafios/redaccion', token, {
    objeto_id: piezaId,
    tipo: 'respuesta_corta',
  });
  comprobar('mision inexistente -> 404', misionFantasma.estado === 404, `estado ${misionFantasma.estado}`);

  // --- la redaccion de verdad ----------------------------------------------
  if (!config.anthropicApiKey) {
    const sinClave = await pedir('POST', ruta, token, {
      objeto_id: piezaId,
      tipo: 'pregunta_opcion_multiple',
    });
    comprobar('sin clave configurada -> 503', sinClave.estado === 503, `estado ${sinClave.estado}`);
    comprobar(
      'y el aviso nombra la variable que falta',
      String(sinClave.cuerpo?.error ?? '').includes('ANTHROPIC_API_KEY'),
      JSON.stringify(sinClave.cuerpo)
    );
    console.log('\n  (sin ANTHROPIC_API_KEY: no se probó la redacción real)');
  } else {
    // Una sola llamada real, de opcion multiple, que es el tipo con mas
    // reglas que respetar.
    const r = await pedir('POST', ruta, token, {
      objeto_id: piezaId,
      tipo: 'pregunta_opcion_multiple',
      indicacion: 'Que la pregunta hable del tamaño de la pieza.',
    });
    comprobar('redacta -> 200', r.estado === 200, `estado ${r.estado} ${JSON.stringify(r.cuerpo).slice(0, 200)}`);

    const borrador = r.cuerpo?.borrador ?? {};
    comprobar('trae enunciado', typeof borrador.enunciado === 'string' && borrador.enunciado.length > 10,
      JSON.stringify(borrador.enunciado));
    comprobar('trae pista', typeof borrador.pista === 'string' && borrador.pista.length > 0,
      JSON.stringify(borrador.pista));
    comprobar(
      'la respuesta correcta esta entre las opciones',
      Array.isArray(borrador.opciones) && borrador.opciones.includes(borrador.respuesta_correcta),
      JSON.stringify({ opciones: borrador.opciones, correcta: borrador.respuesta_correcta })
    );

    // Lo que importa de verdad: que el borrador se pueda guardar tal cual.
    const { errores } = validarDesafio({ ...borrador, puntos: 10 });
    comprobar(
      'el borrador pasa el validador del formulario',
      Object.keys(errores).length === 0,
      JSON.stringify(errores)
    );

    // No se guarda: la ruta devuelve un borrador y nada mas.
    const { rows } = await bd.query('SELECT count(*)::int AS n FROM desafios WHERE mision_id = $1', [misionId]);
    comprobar('no guardo ningun desafio', rows[0].n === 0, `desafios: ${rows[0].n}`);
  }
} finally {
  if (misionId) await bd.query('DELETE FROM misiones WHERE id = $1', [misionId]);
  if (visitanteId) await borrarUsuarios([visitanteId]);
  await terminar();
}

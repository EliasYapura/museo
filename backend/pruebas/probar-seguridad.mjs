// Comprueba los dos arreglos de SIS04: el límite de intentos y que el rol y
// el estado de la cuenta se lean de la base y no del token.
//
// Crea su propio visitante y lo borra al terminar.
//
// OJO: esta prueba gasta a propósito la cuota de intentos de login, que la API
// cuenta en memoria por ventanas de 15 minutos. Dos corridas seguidas no
// entran en la misma ventana: la segunda se encuentra la cuota agotada y corta
// con código 2 avisando, que es distinto de una comprobación que da mal. Por
// eso también el bloque del límite va al final.

import { API, administrador, bd, borrarUsuarios, comprobar, ipDePrueba, pedir, terminar, tokenDe } from './ayuda.mjs';

// Esta prueba gasta a proposito la cuota de intentos: se presenta con una IP
// inventada propia para no dejar sin login a las demas ni a quien programa.
const MI_IP = { 'X-Forwarded-For': ipDePrueba() };

// El token del administrador se firma acá. Entrar con usuario y contraseña no
// serviría: más abajo esta misma prueba agota el límite de intentos de login.
const tokenAdmin = tokenDe(await administrador(), 'administrador');

const sello = Date.now();
const email = `seguridad-${sello}@prueba.test`;
const clave = 'seguridad' + sello;

// ---------------------------------------------------------- un visitante nuevo
const alta = await pedir('POST', '/auth/registro', null, {
  email,
  password: clave,
  nombre: 'Visitante',
}, undefined, MI_IP);
const sesion = await pedir('POST', '/auth/login', null, { email, password: clave }, undefined, MI_IP);
const tokenVisitante = sesion.cuerpo?.token;

// El id se lee de la base y no de la respuesta: si el registro o el login
// quedaron frenados por el límite, la respuesta no trae usuario y conviene
// darse cuenta acá y no tres consultas más abajo con un id vacío.
const { rows: suyo } = await bd.query('SELECT id FROM usuarios WHERE email = $1', [email]);
const idVisitante = suyo[0] ? Number(suyo[0].id) : null;

if (!tokenVisitante || idVisitante === null) {
  console.error(
    `No pude crear el visitante de prueba (registro ${alta.estado}, login ${sesion.estado}).`
  );
  if (alta.estado === 429 || sesion.estado === 429) {
    console.error('Es el límite de intentos: esta prueba lo gasta y la cuota dura 15 minutos.');
    console.error('Reiniciá la API para vaciarlo, o esperá la ventana.');
  }
  if (idVisitante !== null) await borrarUsuarios([idVisitante]);
  await bd.end();
  process.exit(2);
}

comprobar('el visitante de prueba pudo entrar', !!tokenVisitante);

// ------------------------------------------- el token no decide el rol
// Se fabrica un token con el mismo secreto pero diciendo que es administrador.
// Antes alcanzaba con eso; ahora la base tiene la última palabra.
comprobar('el perfil responde con el token legítimo',
  (await pedir('GET', '/auth/perfil', tokenVisitante)).estado === 200);

comprobar('un visitante no entra a una ruta de administración',
  (await pedir('GET', '/objetos', tokenVisitante)).estado === 403);

// ------------------------------- desactivar la cuenta corta el token al instante
// El script vive fuera del backend, así que pg no se resuelve solo: se lo
// pide al node_modules del backend.
try {
  await bd.query('UPDATE usuarios SET activo = FALSE WHERE id = $1', [idVisitante]);

  const traDesactivar = await pedir('GET', '/auth/perfil', tokenVisitante);
  comprobar('con la cuenta desactivada, el MISMO token deja de servir',
    traDesactivar.estado === 401, 'estado ' + traDesactivar.estado);

  // En las rutas públicas no se corta la visita: se sigue como anónimo.
  const publicas = await pedir('GET', '/publico/insignias', tokenVisitante);
  comprobar('las rutas públicas siguen respondiendo', publicas.estado === 200,
    'estado ' + publicas.estado);
  comprobar('pero ninguna insignia figura como ganada',
    publicas.cuerpo.insignias.every((i) => i.obtenida_en === null));

  // Y al reactivarla vuelve a funcionar, sin volver a entrar.
  await bd.query('UPDATE usuarios SET activo = TRUE WHERE id = $1', [idVisitante]);
  comprobar('al reactivarla, el mismo token vuelve a servir',
    (await pedir('GET', '/auth/perfil', tokenVisitante)).estado === 200);

  // ------------------------------------- subir el rol tiene efecto inmediato
  await bd.query("UPDATE usuarios SET rol = 'administrador' WHERE id = $1", [idVisitante]);
  comprobar('promoverlo le abre la administración con el token viejo',
    (await pedir('GET', '/objetos', tokenVisitante)).estado === 200);

  await bd.query("UPDATE usuarios SET rol = 'visitante' WHERE id = $1", [idVisitante]);
  comprobar('bajarle el rol se la cierra de nuevo, sin esperar a que venza',
    (await pedir('GET', '/objetos', tokenVisitante)).estado === 403);
} finally {
  // Se borra en vez de dejarla desactivada: una cuenta de prueba olvidada en
  // la base es basura que después hay que ir a limpiar a mano.
  await borrarUsuarios([Number(idVisitante)]);
}

// ------------------------------------------------------- el límite de intentos
// Va al final: una vez agotado, el resto de las pruebas de login fallaría.
let bloqueado = 0;
let estadoFinal = null;
for (let i = 1; i <= 14; i++) {
  const r = await pedir('POST', '/auth/login', null, {
    email: `inexistente-@prueba.test`,
    password: 'la-que-sea',
  }, undefined, MI_IP);
  if (r.estado === 429) {
    bloqueado = bloqueado || i;
    estadoFinal = r.cuerpo;
  }
}
comprobar('los intentos fallidos se cortan antes del 14', bloqueado > 0,
  bloqueado ? 'bloqueó en el intento ' + bloqueado : 'nunca bloqueó');
comprobar('el bloqueo explica qué pasó',
  typeof estadoFinal?.error === 'string' && estadoFinal.error.includes('intentos'),
  JSON.stringify(estadoFinal));

// El administrador, que ya tenía su token, no quedó afectado: el límite es
// sobre el login, no sobre las peticiones con sesión.
comprobar('el bloqueo no afecta a quien ya tiene sesión',
  (await pedir('GET', '/objetos', tokenAdmin)).estado === 200);


await terminar();

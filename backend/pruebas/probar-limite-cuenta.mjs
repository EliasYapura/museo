// Comprueba que el límite de login cuente por cuenta y no sólo por IP (SIS04).
//
// Lo importante: bloquear una cuenta no tiene que dejar afuera a otra desde la
// misma conexión, que es lo que pasaría en el wifi del museo.
//
// Los contadores viven en memoria y por cliente. Esta prueba se presenta con
// una IP inventada propia, así que arranca siempre con la cuota entera y no se
// la gasta ni a las otras pruebas ni a quien esté programando.

import { API, comprobar, ipDePrueba, terminar } from './ayuda.mjs';

const MI_IP = ipDePrueba();

async function intentar(email, password = 'la-que-sea') {
  const res = await fetch(API + '/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Forwarded-For': MI_IP },
    body: JSON.stringify({ email, password }),
  });
  const texto = await res.text();
  let json = null;
  try {
    json = texto ? JSON.parse(texto) : null;
  } catch {
    json = null;
  }
  return { estado: res.status, cuerpo: json };
}

const sello = Date.now();
const victima = `victima-${sello}@prueba.test`;
const vecino = `vecino-${sello}@prueba.test`;

// ------------------------------------------- se agota la cuota de UNA cuenta
let bloqueoVictima = 0;
for (let i = 1; i <= 12; i++) {
  const r = await intentar(victima);
  if (r.estado === 429 && !bloqueoVictima) bloqueoVictima = i;
}
comprobar('la cuenta atacada se bloquea', bloqueoVictima === 11,
  'bloqueó en el intento ' + bloqueoVictima);

// ----------------------------- otra cuenta desde la MISMA IP sigue entrando
const otro = await intentar(vecino);
comprobar('otra cuenta desde la misma conexión NO queda bloqueada',
  otro.estado === 401, 'estado ' + otro.estado);

// ------------------------------- cambiar mayúsculas no reinicia el contador
const conMayusculas = await intentar(victima.toUpperCase());
comprobar('cambiar las mayúsculas del email no reinicia la cuota',
  conMayusculas.estado === 429, 'estado ' + conMayusculas.estado);

const conEspacios = await intentar('  ' + victima + '  ');
comprobar('agregarle espacios tampoco', conEspacios.estado === 429,
  'estado ' + conEspacios.estado);

// ------------------- la red de seguridad por IP corta el ataque disperso
// Cada email es distinto, así que el límite por cuenta nunca llega a diez.
// El que tiene que cortar es el de la IP, a los 60 fallidos en total.
let bloqueoPorIp = 0;
for (let i = 1; i <= 70; i++) {
  const r = await intentar(`disperso-${sello}-${i}@prueba.test`);
  if (r.estado === 429 && !bloqueoPorIp) bloqueoPorIp = i;
}
comprobar('probar una contraseña contra muchas cuentas también se corta',
  bloqueoPorIp > 0, bloqueoPorIp ? 'cortó en el email nº ' + bloqueoPorIp : 'nunca cortó');

await terminar();

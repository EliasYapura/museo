// Normaliza un email para compararlo y guardarlo siempre igual.
//
// Esta en un modulo propio porque lo usan dos lugares que no se pueden
// importar entre si: el alta y el login (routes/auth.js), y el limite de
// intentos (middleware/limites.js), que auth.js ya importa. Tenerlo en auth.js
// y pedirselo desde limites.js armaria un ciclo.
//
// Importa que los dos usen exactamente la misma funcion: si el limite contara
// "Ana@museo.ar" y "ana@museo.ar" como cuentas distintas, bastaria con cambiar
// una mayuscula para empezar de cero.
export const normalizarEmail = (email) => email.trim().toLowerCase();

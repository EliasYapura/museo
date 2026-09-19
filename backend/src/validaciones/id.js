// Un id de la URL tiene que ser un entero positivo. Se limita a 15 digitos:
// con mas, Number() pierde precision y PostgreSQL rechazaria el valor.
// Las rutas responden un id imposible como "no encontrado", igual que uno
// inexistente.
export const esIdValido = (texto) => /^[1-9]\d{0,14}$/.test(texto);

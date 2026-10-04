import { randomBytes } from 'node:crypto';
import { Router } from 'express';
import { pool } from '../db.js';
import { responderSiEsErrorDeDatos } from '../erroresDeDatos.js';
import { verificarToken, requerirRol } from '../middleware/auth.js';
import { esIdValido } from '../validaciones/id.js';
import { validarObjeto } from '../validaciones/objeto.js';

export const objetosRouter = Router();

// Todas las rutas de objetos son solo para administradores.
objetosRouter.use(verificarToken, requerirRol('administrador'));

// Columnas que se devuelven de un objeto. Incluyen el nombre de la sala para
// que el panel no tenga que buscarlo aparte. Las consultas llaman "o" a la
// fila del objeto y "s" a su sala.
// desafios es en cuantos desafios se usa la pieza (ADM18). Va en todas las
// respuestas y no solo en el listado, asi el panel puede reemplazar una fila
// con lo que devuelve un PATCH sin perder el dato. count() da bigint, que
// node-pg entrega como texto; el ::int lo devuelve como numero.
const COLUMNAS = `o.id, o.nombre, o.dato_clave, o.descripcion, o.imagen_url, o.codigo,
                  o.tipo_identificador, o.activo, o.creado_en, o.sala_id, s.nombre AS sala,
                  (SELECT count(*) FROM desafios d WHERE d.objeto_id = o.id)::int AS desafios`;

const NO_ENCONTRADO = { error: 'El objeto no existe' };
const SALA_INEXISTENTE = { error: 'Datos inválidos', errores: { sala_id: 'La sala elegida no existe' } };

// --- Codigo del objeto ---------------------------------------------------
// Es lo que va a contener el QR pegado junto a la pieza, y en el Sprint 3 el
// escaneo se valida contra el (SIS01). Por eso se genera al azar y no con
// numeros seguidos: con OBJ-0001, OBJ-0002... cualquiera podria adivinar el
// codigo de otra pieza y cargarlo sin haberla visitado.
//
// El alfabeto no tiene I, O, 0 ni 1, que se confunden si alguna vez hay que
// leer o tipear el codigo. Tiene 32 simbolos: como 256 es multiplo de 32,
// byte % 32 elige cada simbolo con la misma probabilidad. Con 8 simbolos hay
// 32^8 (mas de un billon) de codigos posibles.
const ALFABETO = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const INTENTOS_DE_CODIGO = 5;

function generarCodigo() {
  const simbolos = [...randomBytes(8)].map((byte) => ALFABETO[byte % ALFABETO.length]);
  return `OBJ-${simbolos.join('')}`;
}

// La base avisa con estos errores cuando algo no cumple una clave.
const esCodigoRepetido = (err) => err.code === '23505' && err.constraint === 'objetos_codigo_key';
const esSalaInexistente = (err) => err.code === '23503' && err.constraint === 'objetos_sala_id_fkey';

// GET /objetos — lista todos los objetos, activos y dados de baja, en el
// orden en que aparecen en el recorrido del museo.
objetosRouter.get('/', async (req, res) => {
  const { rows } = await pool.query(
    `SELECT ${COLUMNAS}
     FROM objetos o JOIN salas s ON s.id = o.sala_id
     ORDER BY s.orden_recorrido, o.nombre, o.id`
  );
  return res.json({ objetos: rows });
});

// GET /objetos/:id — datos de un objeto, para precargar la edicion.
objetosRouter.get('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const { rows } = await pool.query(
    `SELECT ${COLUMNAS} FROM objetos o JOIN salas s ON s.id = o.sala_id WHERE o.id = $1`,
    [req.params.id]
  );
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADO);
  return res.json({ objeto: rows[0] });
});

// GET /objetos/:id/desafios — en que desafios se usa la pieza (ADM18).
//
// Es la vuelta del selector de objeto del formulario de desafios: desde el
// objeto se ve donde esta usado, que es lo que hay que mirar antes de darlo
// de baja o borrarlo. Incluye los desafios de misiones archivadas, marcados
// como tales: son los que explican que un objeto que parece libre no se pueda
// borrar.
objetosRouter.get('/:id/desafios', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const objeto = await pool.query('SELECT id, nombre, codigo FROM objetos WHERE id = $1', [
    req.params.id,
  ]);
  if (!objeto.rows[0]) return res.status(404).json(NO_ENCONTRADO);

  const { rows } = await pool.query(
    `SELECT d.id, d.orden, d.tipo, d.enunciado, d.puntos,
            m.id AS mision_id, m.nombre AS mision, m.archivada
     FROM desafios d JOIN misiones m ON m.id = d.mision_id
     WHERE d.objeto_id = $1
     ORDER BY m.archivada, m.nombre, d.orden, d.id`,
    [req.params.id]
  );
  return res.json({ objeto: objeto.rows[0], desafios: rows });
});

// POST /objetos — registra un objeto (ADM15), con su descripcion e imagen
// opcionales (ADM16).
objetosRouter.post('/', async (req, res) => {
  const { valores, errores } = validarObjeto(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  // Si el codigo sorteado ya existe (casi imposible), se sortea otro. La base
  // es la que detecta la repeticion, gracias a la restriccion UNIQUE: revisar
  // antes con un SELECT no alcanzaria, porque otro alta simultanea podria
  // tomar el mismo codigo entre la consulta y el INSERT.
  for (let intento = 1; intento <= INTENTOS_DE_CODIGO; intento++) {
    try {
      // Se guardan solo los campos validados. El codigo lo pone la API y
      // activo toma su valor por defecto (TRUE), sin importar lo que traiga
      // el cuerpo. El WITH permite devolver el objeto junto con su sala.
      const { rows } = await pool.query(
        `WITH nuevo AS (
           INSERT INTO objetos (sala_id, nombre, dato_clave, descripcion, imagen_url,
                                tipo_identificador, codigo)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING *
         )
         SELECT ${COLUMNAS} FROM nuevo o JOIN salas s ON s.id = o.sala_id`,
        [
          valores.sala_id,
          valores.nombre,
          valores.dato_clave,
          valores.descripcion,
          valores.imagen_url,
          valores.tipo_identificador,
          generarCodigo(),
        ]
      );
      return res.status(201).json({ objeto: rows[0] });
    } catch (err) {
      if (esCodigoRepetido(err) && intento < INTENTOS_DE_CODIGO) continue;
      if (esSalaInexistente(err)) return res.status(400).json(SALA_INEXISTENTE);
      if (responderSiEsErrorDeDatos(err, res)) return;
      throw err;
    }
  }
});

// PUT /objetos/:id — modifica nombre, sala y dato clave (ADM15), descripcion
// e imagen (ADM16) y el tipo de identificador (ADM17) de un objeto.
// El codigo no se toca: si cambiara, el QR ya impreso dejaria de servir. Para
// cambiarlo a proposito esta PATCH /objetos/:id/codigo.
objetosRouter.put('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const { valores, errores } = validarObjeto(req.body ?? {});
  if (Object.keys(errores).length > 0) {
    return res.status(400).json({ error: 'Datos inválidos', errores });
  }

  try {
    // Igual que al editar una mision: solo se actualiza si algun dato cambio,
    // y asi la API puede avisar "no habia cambios".
    const { rows } = await pool.query(
      `WITH cambiado AS (
         UPDATE objetos
         SET sala_id = $2, nombre = $3, dato_clave = $4, descripcion = $5,
             imagen_url = $6, tipo_identificador = $7
         WHERE id = $1
           AND (sala_id IS DISTINCT FROM $2
                OR nombre IS DISTINCT FROM $3
                OR dato_clave IS DISTINCT FROM $4
                OR descripcion IS DISTINCT FROM $5
                OR imagen_url IS DISTINCT FROM $6
                OR tipo_identificador IS DISTINCT FROM $7)
         RETURNING *
       )
       SELECT ${COLUMNAS} FROM cambiado o JOIN salas s ON s.id = o.sala_id`,
      [
        req.params.id,
        valores.sala_id,
        valores.nombre,
        valores.dato_clave,
        valores.descripcion,
        valores.imagen_url,
        valores.tipo_identificador,
      ]
    );
    if (rows[0]) return res.json({ objeto: rows[0], modificado: true });

    // Ninguna fila actualizada: o el objeto no existe, o no habia cambios.
    const existente = await pool.query(
      `SELECT ${COLUMNAS} FROM objetos o JOIN salas s ON s.id = o.sala_id WHERE o.id = $1`,
      [req.params.id]
    );
    if (!existente.rows[0]) return res.status(404).json(NO_ENCONTRADO);
    return res.json({ objeto: existente.rows[0], modificado: false });
  } catch (err) {
    if (esSalaInexistente(err)) return res.status(400).json(SALA_INEXISTENTE);
    if (responderSiEsErrorDeDatos(err, res)) return;
    throw err;
  }
});

// PATCH /objetos/:id/codigo — genera un codigo nuevo para el objeto (ADM17).
//
// Es una ruta aparte y no un campo del formulario para que el codigo no se
// pueda cambiar sin querer al guardar los datos: cambiarlo deja inservible la
// etiqueta QR o NFC que ya esta puesta junto a la pieza.
objetosRouter.patch('/:id/codigo', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  for (let intento = 1; intento <= INTENTOS_DE_CODIGO; intento++) {
    try {
      const { rows } = await pool.query(
        `WITH cambiado AS (
           UPDATE objetos SET codigo = $2 WHERE id = $1 RETURNING *
         )
         SELECT ${COLUMNAS} FROM cambiado o JOIN salas s ON s.id = o.sala_id`,
        [req.params.id, generarCodigo()]
      );
      if (!rows[0]) return res.status(404).json(NO_ENCONTRADO);
      return res.json({ objeto: rows[0] });
    } catch (err) {
      if (esCodigoRepetido(err) && intento < INTENTOS_DE_CODIGO) continue;
      throw err;
    }
  }
});

// PATCH /objetos/:id/estado — da de baja ({ activo: false }) o reactiva
// ({ activo: true }) un objeto.
//
// Es una baja logica: el objeto sigue en la base. Borrarlo no es posible si
// algun desafio lo usa (la clave foranea lo impide) y ademas se perderia el
// historial de lo que los visitantes escanearon.
objetosRouter.patch('/:id/estado', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const activo = req.body?.activo;
  if (typeof activo !== 'boolean') {
    return res.status(400).json({ error: 'El estado debe ser activo (true) o inactivo (false)' });
  }

  const { rows } = await pool.query(
    `WITH cambiado AS (
       UPDATE objetos SET activo = $2 WHERE id = $1 RETURNING *
     )
     SELECT ${COLUMNAS} FROM cambiado o JOIN salas s ON s.id = o.sala_id`,
    [req.params.id, activo]
  );
  if (!rows[0]) return res.status(404).json(NO_ENCONTRADO);
  return res.json({ objeto: rows[0] });
});

// DELETE /objetos/:id — borra un objeto del museo (ADM07).
//
// A diferencia de la mision, que se archiva, aca el borrado es real: un
// objeto mal cargado no deja historial que valga la pena conservar. Lo que no
// se permite es borrar una pieza que algun desafio este usando: la clave
// foranea lo impide (ON DELETE RESTRICT) y dejaria desafios apuntando a una
// pieza inexistente. Para esos casos esta la baja logica.
objetosRouter.delete('/:id', async (req, res) => {
  if (!esIdValido(req.params.id)) return res.status(404).json(NO_ENCONTRADO);

  const enUso = await pool.query(
    'SELECT count(*)::int AS cantidad FROM desafios WHERE objeto_id = $1',
    [req.params.id]
  );
  if (enUso.rows[0].cantidad > 0) {
    return res.status(409).json({
      error: 'El objeto se usa en desafíos y no se puede borrar',
      desafios: enUso.rows[0].cantidad,
    });
  }

  try {
    const { rowCount } = await pool.query('DELETE FROM objetos WHERE id = $1', [req.params.id]);
    if (rowCount === 0) return res.status(404).json(NO_ENCONTRADO);
    return res.status(204).end();
  } catch (err) {
    // Entre la consulta de arriba y el DELETE alguien pudo crear un desafio
    // con este objeto. La base lo rechaza y se responde lo mismo.
    if (err.code === '23503') {
      return res.status(409).json({ error: 'El objeto se usa en desafíos y no se puede borrar' });
    }
    throw err;
  }
});

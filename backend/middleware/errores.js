const { HttpError } = require('../utils/validacion');

const SIN_BD = [503, 'La base de datos no está disponible. Ejecuta npm run db:check en el servidor.'];
const FALTA_MIGRACION = [503, 'Falta aplicar una migración en la base de datos. Ejecuta npm run db:check en el servidor.'];
const POR_CODIGO = {
  ER_DUP_ENTRY: [409, 'Ya existe un registro con estos datos.'],
  ER_NO_REFERENCED_ROW_2: [409, 'Un registro relacionado no existe.'],
  ER_CHECK_CONSTRAINT_VIOLATED: [400, 'Los datos no cumplen las restricciones de la base de datos.'],
  ER_DATA_TOO_LONG: [400, 'Uno de los campos supera la longitud permitida.'],
  ER_NO_SUCH_TABLE: FALTA_MIGRACION,
  ER_SP_DOES_NOT_EXIST: FALTA_MIGRACION,
  ECONNREFUSED: SIN_BD, ETIMEDOUT: SIN_BD, EHOSTUNREACH: SIN_BD, ENOTFOUND: SIN_BD,
  PROTOCOL_CONNECTION_LOST: SIN_BD, ER_ACCESS_DENIED_ERROR: SIN_BD, ER_BAD_DB_ERROR: SIN_BD,
};

const noEncontrado = (req, res) => res.status(404).json({ error: 'Ruta no encontrada.' });

function manejarErrores(error, req, res, next) {
  if (res.headersSent) return next(error);
  if (error instanceof HttpError) return res.status(error.status).json({ error: error.message });
  if (error.type === 'entity.parse.failed') return res.status(400).json({ error: 'El cuerpo JSON no es válido.' });
  if (error.type === 'entity.too.large') return res.status(413).json({ error: 'La solicitud es demasiado grande.' });
  // SIGNAL '45000' de los procedimientos y triggers de sihaychamba: mensajes de negocio escritos en el SQL.
  if (error.sqlState === '45000') return res.status(409).json({ error: error.sqlMessage });
  const conocido = POR_CODIGO[error.code];
  // Se registra el código y el mensaje del servidor, nunca la consulta con sus valores (error.sql).
  console.error(`[${req.method} ${req.path}]`, error.code || error.name, conocido ? '' : error.message);
  const [status, mensaje] = conocido || [500, 'No fue posible completar la operación.'];
  res.status(status).json({ error: mensaje });
}

module.exports = { noEncontrado, manejarErrores };

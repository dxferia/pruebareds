// Mecanismos ya definidos por la app Flutter (versión sin login):
//  - X-Admin-Key: clave de la Junta (ADMIN_API_KEY, mínimo 32 caracteres).
//  - X-Contact-Key: clave de edición que el servidor entregó al registrar "Mi contacto".
const crypto = require('node:crypto');
const { HttpError } = require('../utils/validacion');
const contactos = require('../services/contactos.service');

const sha256 = (v) => crypto.createHash('sha256').update(v).digest();

function admin(req, res, next) {
  const esperada = process.env.ADMIN_API_KEY || '';
  if (esperada.length < 32) throw new HttpError(503, 'La administración no está configurada en el servidor (ADMIN_API_KEY).');
  const recibida = req.get('X-Admin-Key');
  if (!recibida) throw new HttpError(401, 'Falta la clave administrativa.');
  if (!crypto.timingSafeEqual(sha256(esperada), sha256(recibida))) throw new HttpError(403, 'Clave administrativa incorrecta.');
  next();
}

async function cargarContacto(req, obligatorio) {
  const clave = req.get('X-Contact-Key');
  if (!clave) {
    if (obligatorio) throw new HttpError(401, 'Registra Mi contacto en este dispositivo para continuar.');
    return null;
  }
  if (!/^[a-f0-9]{64}$/.test(clave)) throw new HttpError(401, 'Identificador de contacto inválido.');
  const perfil = await contactos.porClave(clave);
  if (!perfil) throw new HttpError(401, 'No se reconoce el contacto de este dispositivo.');
  return perfil;
}

const contacto = async (req, res, next) => { req.contacto = await cargarContacto(req, true); next(); };
const contactoOpcional = async (req, res, next) => { req.contacto = await cargarContacto(req, false); next(); };

// Las cuentas suspendidas o rechazadas por la Junta no pueden crear solicitudes nuevas.
function cuentaHabilitada(req, res, next) {
  if (['SUSPENDIDA', 'RECHAZADA'].includes(req.contacto.estado)) {
    throw new HttpError(403, `Tu cuenta está ${req.contacto.estado.toLowerCase()}. Comunícate con la Junta.`);
  }
  next();
}

module.exports = { admin, contacto, contactoOpcional, cuentaHabilitada };

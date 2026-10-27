// Solicitudes de contacto de la persona identificada con X-Contact-Key (la publicación es directa:
// ver catalogo.service.crear). Las escrituras usan los procedimientos de sihaychamba.
const crypto = require('node:crypto');
const { pool } = require('../config/db');
const { HttpError } = require('../utils/validacion');

async function crearContacto(idCuenta, d) {
  const [rows] = await pool.execute(`SELECT id_responsable,
    (SELECT COUNT(*) FROM solicitud_contacto WHERE id_publicacion = ? AND id_remitente = ? AND estado = 'PENDIENTE') AS pendientes
    FROM publicacion WHERE id_publicacion = ?`, [d.id_publicacion, idCuenta, d.id_publicacion]);
  if (!rows.length) throw new HttpError(404, 'La publicación no existe.');
  if (rows[0].id_responsable === idCuenta) throw new HttpError(409, 'No puedes solicitar contacto a tu propia publicación.');
  if (Number(rows[0].pendientes) > 0) throw new HttpError(409, 'Ya tienes una solicitud pendiente para esta publicación.');
  const id = `sc-${crypto.randomUUID()}`;
  // El trigger trg_contacto_validar_bi rechaza publicaciones cerradas o vencidas (SIGNAL 45000 → 409).
  await pool.query('CALL sp_crear_solicitud_contacto(?,?,?,?,?)', [id, d.id_publicacion, idCuenta, d.motivo, d.telefono_autorizado]);
  return { id_solicitud_contacto: id, id_publicacion: d.id_publicacion, estado: 'PENDIENTE' };
}

async function misContactos(idCuenta) {
  const [rows] = await pool.execute(`SELECT id_solicitud_contacto, id_publicacion, publicacion, motivo, telefono_autorizado,
    fecha_solicitud, estado FROM vw_solicitudes_contacto WHERE id_remitente = ? ORDER BY fecha_solicitud DESC`, [idCuenta]);
  return rows;
}

module.exports = { crearContacto, misContactos };

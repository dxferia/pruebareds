// Gestión de la Junta (protegida con X-Admin-Key). Escrituras mediante los procedimientos de sihaychamba,
// que registran el actor en historial_gestion.
const crypto = require('node:crypto');
const { pool, transaccion } = require('../config/db');
const { HttpError } = require('../utils/validacion');

const ACTOR = 'Junta';

async function uno(sql, params, mensaje404) {
  const [rows] = await pool.execute(sql, params);
  if (!rows.length) throw new HttpError(404, mensaje404);
  return rows[0];
}

async function solicitudesPublicacion(estado) {
  const [rows] = await pool.execute(`SELECT id_solicitud, id_solicitante, solicitante, id_categoria, nombre_categoria, titulo,
    descripcion, cantidad, ubicacion, disponible_desde, disponible_hasta, contacto_autorizado, fecha_solicitud, estado, motivo_rechazo
    FROM vw_solicitudes_publicacion${estado ? ' WHERE estado = ?' : ''} ORDER BY fecha_solicitud DESC LIMIT 200`, estado ? [estado] : []);
  return rows;
}

async function aprobar(idSolicitud, tipo) {
  const s = await uno('SELECT id_solicitante FROM solicitud_publicacion WHERE id_solicitud = ?', [idSolicitud], 'La solicitud no existe.');
  const idPublicacion = `pub-${crypto.randomUUID()}`;
  // La persona solicitante queda como responsable; el método de pago no lo define el flujo actual.
  await pool.query('CALL sp_aprobar_solicitud_publicacion(?,?,?,?,?,?)', [idSolicitud, idPublicacion, s.id_solicitante, null, tipo, ACTOR]);
  return { id_solicitud: idSolicitud, id_publicacion: idPublicacion, estado: 'APROBADA' };
}

async function rechazar(idSolicitud, motivo) {
  await uno('SELECT 1 FROM solicitud_publicacion WHERE id_solicitud = ?', [idSolicitud], 'La solicitud no existe.');
  await pool.query('CALL sp_rechazar_solicitud_publicacion(?,?,?)', [idSolicitud, motivo, ACTOR]);
  return { id_solicitud: idSolicitud, estado: 'RECHAZADA' };
}

async function solicitudesContacto() {
  const [rows] = await pool.execute(`SELECT id_solicitud_contacto, id_publicacion, publicacion, id_remitente, remitente,
    id_responsable, responsable, motivo, telefono_autorizado, fecha_solicitud, estado
    FROM vw_solicitudes_contacto ORDER BY fecha_solicitud DESC LIMIT 200`);
  return rows;
}

// UPDATE condicionado: dos decisiones simultáneas no pueden procesar la misma solicitud.
async function decidirContacto(id, estado) {
  const [r] = await transaccion(ACTOR, (conn) => conn.execute(
    "UPDATE solicitud_contacto SET estado = ? WHERE id_solicitud_contacto = ? AND estado = 'PENDIENTE'", [estado, id]));
  if (!r.affectedRows) {
    await uno('SELECT 1 FROM solicitud_contacto WHERE id_solicitud_contacto = ?', [id], 'La solicitud de contacto no existe.');
    throw new HttpError(409, 'La solicitud de contacto ya fue procesada.');
  }
  return { id_solicitud_contacto: id, estado };
}

async function actualizarPublicacion(id, cambios) {
  const actual = await uno(`SELECT descripcion, cantidad, ubicacion, disponible_desde, disponible_hasta, id_metodo_pago
    FROM publicacion WHERE id_publicacion = ?`, [id], 'La publicación no existe.');
  const d = { ...actual, ...cambios }; // PATCH parcial: se conserva lo que no se envía (incluido el método de pago).
  if (d.disponible_hasta < d.disponible_desde) throw new HttpError(400, 'La fecha final no puede ser anterior a la inicial.');
  await pool.query('CALL sp_actualizar_publicacion(?,?,?,?,?,?,?,?)', [id, d.descripcion, d.cantidad, d.ubicacion,
    d.disponible_desde, d.disponible_hasta, d.id_metodo_pago, ACTOR]);
  return { id_publicacion: id, ...d };
}

async function cerrarPublicacion(id) {
  const p = await uno('SELECT activa FROM publicacion WHERE id_publicacion = ?', [id], 'La publicación no existe.');
  if (!p.activa) throw new HttpError(409, 'La publicación ya está cerrada.');
  await pool.query('CALL sp_cerrar_publicacion(?,?)', [id, ACTOR]);
  return { id_publicacion: id, activa: false };
}

async function cuentas() {
  const [rows] = await pool.execute('SELECT id_cuenta, nombre, estado FROM cuenta_acceso ORDER BY nombre LIMIT 500');
  return rows;
}

async function cambiarEstadoCuenta(id, estado) {
  await uno('SELECT 1 FROM cuenta_acceso WHERE id_cuenta = ?', [id], 'La cuenta no existe.');
  await pool.query('CALL sp_cambiar_estado_cuenta(?,?,?)', [id, estado, ACTOR]);
  return { id_cuenta: id, estado };
}

// Sin las columnas antes/después: contienen teléfonos y datos personales que la pantalla no necesita.
async function historial() {
  const [rows] = await pool.execute('SELECT fecha, actor, accion, elemento_afectado FROM vw_historial_gestion ORDER BY fecha DESC LIMIT 100');
  return rows;
}

module.exports = {
  solicitudesPublicacion, aprobar, rechazar, solicitudesContacto, decidirContacto,
  actualizarPublicacion, cerrarPublicacion, cuentas, cambiarEstadoCuenta, historial,
};

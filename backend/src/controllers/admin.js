const crypto = require('node:crypto');
const { asyncRoute, requerir, idValido, limpio, fechaValida, HttpError } = require('../utils/errors');
const { crearPoolAdmin } = require('../config/admin_database');
const pool = () => crearPoolAdmin();
module.exports = {
  solicitudes: asyncRoute(async (req, res) => { const [r] = await pool().execute('SELECT * FROM vw_solicitudes_publicacion ORDER BY fecha_solicitud DESC LIMIT 200'); res.json(r); }),
  solicitudDetalle: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido.');
    const [rows] = await pool().execute('SELECT * FROM vw_solicitudes_publicacion WHERE id_solicitud=?', [req.params.id]);
    if (!rows.length) throw new HttpError(404, 'La solicitud no existe.');
    res.json(rows[0]);
  }),
  solicitudesContacto: asyncRoute(async (req, res) => {
    const [rows] = await pool().execute(`SELECT id_solicitud_contacto,id_publicacion,publicacion,id_remitente,
     remitente,id_responsable,responsable,motivo,telefono_autorizado,fecha_solicitud,estado
     FROM vw_solicitudes_contacto ORDER BY fecha_solicitud DESC LIMIT 200`);
    res.json(rows);
  }),
  solicitudContactoDetalle: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido.');
    const [rows] = await pool().execute('SELECT * FROM vw_solicitudes_contacto WHERE id_solicitud_contacto=?', [req.params.id]);
    if (!rows.length) throw new HttpError(404, 'La solicitud de contacto no existe.');
    res.json(rows[0]);
  }),
  actualizarSolicitudContacto: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido.');
    const estado = req.body?.estado;
    requerir(['APROBADA', 'RECHAZADA'].includes(estado), 'El estado debe ser APROBADA o RECHAZADA.');
    // Un único UPDATE condicionado evita que dos decisiones aprueben/rechacen la misma solicitud.
    // El trigger original de MySQL conserva el historial de la transición.
    const [resultado] = await pool().execute(`UPDATE solicitud_contacto SET estado=?
     WHERE id_solicitud_contacto=? AND estado='PENDIENTE'`, [estado, req.params.id]);
    if (resultado.affectedRows === 0) {
      const [existente] = await pool().execute('SELECT estado FROM solicitud_contacto WHERE id_solicitud_contacto=?', [req.params.id]);
      if (!existente.length) throw new HttpError(404, 'La solicitud de contacto no existe.');
      throw new HttpError(409, 'La solicitud de contacto ya fue procesada.');
    }
    res.json({ id_solicitud_contacto: req.params.id, estado });
  }),
  publicaciones: asyncRoute(async (req, res) => {
    const [rows] = await pool().execute(`SELECT p.id_publicacion,p.id_solicitud_origen,p.id_categoria,p.id_responsable,
     p.id_metodo_pago,p.titulo,p.descripcion,p.ubicacion,p.disponible_desde,p.disponible_hasta,
     p.cantidad,p.tipo,p.activa,c.nombre_categoria
     FROM publicacion p JOIN categoria c ON c.id_categoria=p.id_categoria
     ORDER BY p.disponible_hasta DESC,p.titulo LIMIT 200`);
    res.json(rows);
  }),
  publicacionDetalle: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido.');
    const [rows] = await pool().execute(`SELECT id_publicacion,id_solicitud_origen,id_categoria,id_responsable,
     id_metodo_pago,titulo,descripcion,ubicacion,disponible_desde,disponible_hasta,cantidad,tipo,activa
     FROM publicacion WHERE id_publicacion=?`, [req.params.id]);
    if (!rows.length) throw new HttpError(404, 'La publicación no existe.');
    res.json(rows[0]);
  }),
  metodosPago: asyncRoute(async (req, res) => {
    const [rows] = await pool().execute('SELECT id_metodo_pago,nombre_metodo_pago FROM metodo_pago ORDER BY nombre_metodo_pago');
    res.json(rows);
  }),
  cuentas: asyncRoute(async (req, res) => { const [r] = await pool().execute('SELECT id_cuenta,nombre,estado FROM cuenta_acceso ORDER BY nombre LIMIT 200'); res.json(r); }),
  historial: asyncRoute(async (req, res) => { const [r] = await pool().execute('SELECT fecha,actor,accion,elemento_afectado FROM vw_historial_gestion ORDER BY fecha DESC LIMIT 100'); res.json(r); }),
  aprobar: asyncRoute(async (req, res) => {
    const id = req.params.id; requerir(idValido(id), 'ID inválido');
    const tipo = req.body?.tipo; requerir(['LABOR', 'SERVICIO'].includes(tipo), 'Tipo no válido');
    const [rr] = await pool().execute('SELECT id_solicitante FROM solicitud_publicacion WHERE id_solicitud=?', [id]);
    if (!rr.length) throw new HttpError(404, 'No existe la solicitud');
    await pool().query('CALL sp_aprobar_solicitud_publicacion(?,?,?,?,?,?)', [
      id, `pub-${crypto.randomUUID()}`, rr[0].id_solicitante, null, tipo, 'Junta']);
    res.json({ ok: true });
  }),
  rechazar: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido');
    const motivo = limpio(req.body?.motivo, 2000); requerir(motivo.length >= 5, 'Motivo obligatorio');
    await pool().query('CALL sp_rechazar_solicitud_publicacion(?,?,?)', [req.params.id, motivo, 'Junta']); res.json({ ok: true });
  }),
  cuenta: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido');
    const estado = req.body?.estado; requerir(['PENDIENTE', 'APROBADA', 'RECHAZADA', 'SUSPENDIDA'].includes(estado), 'Estado no válido');
    await pool().query('CALL sp_cambiar_estado_cuenta(?,?,?)', [req.params.id, estado, 'Junta']); res.json({ ok: true });
  }),
  actualizar: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido');
    const d = req.body || {}; requerir(fechaValida(d.disponible_desde) && fechaValida(d.disponible_hasta) && d.disponible_hasta >= d.disponible_desde, 'Fechas inválidas');
    const descripcion = limpio(d.descripcion, 10000), ubicacion = limpio(d.ubicacion, 255);
    requerir(descripcion.length >= 10 && ubicacion.length >= 3, 'Datos incompletos');
    await pool().query('CALL sp_actualizar_publicacion(?,?,?,?,?,?,?,?)', [
      req.params.id, descripcion, limpio(d.cantidad, 100) || null, ubicacion, d.disponible_desde, d.disponible_hasta, null, 'Junta']);
    res.json({ ok: true });
  }),
  cerrar: asyncRoute(async (req, res) => {
    requerir(idValido(req.params.id), 'ID inválido');
    await pool().query('CALL sp_cerrar_publicacion(?,?)', [req.params.id, 'Junta']); res.json({ ok: true });
  })
};

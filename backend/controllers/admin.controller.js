const admin = require('../services/admin.service');
const { requerir, texto, id, fechaValida } = require('../utils/validacion');

const ESTADOS_SOLICITUD = ['PENDIENTE', 'APROBADA', 'RECHAZADA'];
// Flutter envía RequestStatus.name.toUpperCase() (APPROVED, SUSPENDED…); se aceptan ambos idiomas.
const ESTADO_CUENTA = {
  PENDIENTE: 'PENDIENTE', APROBADA: 'APROBADA', RECHAZADA: 'RECHAZADA', SUSPENDIDA: 'SUSPENDIDA',
  PENDING: 'PENDIENTE', APPROVED: 'APROBADA', REJECTED: 'RECHAZADA', SUSPENDED: 'SUSPENDIDA',
};

module.exports = {
  solicitudesPublicacion: async (req, res) => {
    const { estado } = req.query;
    if (estado !== undefined) requerir(ESTADOS_SOLICITUD.includes(estado), 'Estado no válido.');
    res.json(await admin.solicitudesPublicacion(estado));
  },

  aprobar: async (req, res) => {
    const tipo = req.body?.tipo;
    requerir(['LABOR', 'SERVICIO'].includes(tipo), 'El tipo debe ser LABOR o SERVICIO.');
    res.json(await admin.aprobar(id(req.params.id), tipo));
  },

  rechazar: async (req, res) => res.json(await admin.rechazar(id(req.params.id),
    texto(req.body?.motivo, 2000, 'Escribe un motivo de rechazo (mínimo 5 caracteres).', 5))),

  solicitudesContacto: async (req, res) => res.json(await admin.solicitudesContacto()),

  decidirContacto: async (req, res) => {
    const estado = req.body?.estado;
    requerir(['APROBADA', 'RECHAZADA'].includes(estado), 'El estado debe ser APROBADA o RECHAZADA.');
    res.json(await admin.decidirContacto(id(req.params.id), estado));
  },

  actualizarPublicacion: async (req, res) => {
    const d = req.body || {};
    const cambios = {};
    if ('descripcion' in d) cambios.descripcion = texto(d.descripcion, 10000, 'La descripción debe tener al menos 10 caracteres.', 10);
    if ('ubicacion' in d) cambios.ubicacion = texto(d.ubicacion, 255, 'Ingresa la ubicación (3 a 255 caracteres).', 3);
    if ('cantidad' in d) cambios.cantidad = texto(d.cantidad, 100, 'La cantidad admite hasta 100 caracteres.', 0);
    for (const f of ['disponible_desde', 'disponible_hasta']) {
      if (f in d) { requerir(fechaValida(d[f]), 'Fecha no válida (AAAA-MM-DD).'); cambios[f] = d[f]; }
    }
    requerir(Object.keys(cambios).length, 'No se enviaron cambios.');
    res.json(await admin.actualizarPublicacion(id(req.params.id), cambios));
  },

  cerrarPublicacion: async (req, res) => res.json(await admin.cerrarPublicacion(id(req.params.id))),

  cuentas: async (req, res) => res.json(await admin.cuentas()),

  cambiarEstadoCuenta: async (req, res) => {
    const estado = ESTADO_CUENTA[String(req.body?.estado ?? '').toUpperCase()];
    requerir(estado, 'Estado de cuenta no válido.');
    res.json(await admin.cambiarEstadoCuenta(id(req.params.id), estado));
  },

  historial: async (req, res) => res.json(await admin.historial()),

  contactos: async (req, res) => res.json(await admin.contactos()),

  resultadosEncuesta: async (req, res) => res.json(await admin.resultadosEncuesta(id(req.params.id, 'Encuesta inválida.'))),

  cambiarEstadoEncuesta: async (req, res) => {
    const estado = req.body?.estado;
    requerir(['BORRADOR', 'ACTIVA', 'CERRADA'].includes(estado), 'El estado debe ser BORRADOR, ACTIVA o CERRADA.');
    res.json(await admin.cambiarEstadoEncuesta(id(req.params.id, 'Encuesta inválida.'), estado));
  },
};

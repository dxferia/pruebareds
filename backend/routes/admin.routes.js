// Montado en /api/admin detrás de middleware/auth.admin (X-Admin-Key).
// Las publicaciones ya no se aprueban: la Junta solo las edita o las cierra.
const { Router } = require('express');
const c = require('../controllers/admin.controller');

module.exports = Router()
  .get('/solicitudes-contacto', c.solicitudesContacto)
  .patch('/solicitudes-contacto/:id', c.decidirContacto)
  .patch('/publicaciones/:id', c.actualizarPublicacion)
  .post('/publicaciones/:id/cerrar', c.cerrarPublicacion)
  .get('/cuentas', c.cuentas)
  .patch('/cuentas/:id', c.cambiarEstadoCuenta)
  .get('/historial', c.historial)
  .get('/contactos', c.contactos)
  .get('/encuestas/:id/resultados', c.resultadosEncuesta)
  .patch('/encuestas/:id', c.cambiarEstadoEncuesta);

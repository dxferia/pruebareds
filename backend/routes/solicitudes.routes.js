const { Router } = require('express');
const c = require('../controllers/solicitudes.controller');
const { contacto, cuentaHabilitada } = require('../middleware/auth');

module.exports = Router()
  .post('/solicitudes-contacto', contacto, cuentaHabilitada, c.crearContacto)
  .get('/solicitudes-contacto/mias', contacto, c.misContactos);

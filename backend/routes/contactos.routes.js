const { Router } = require('express');
const c = require('../controllers/contactos.controller');
const { contacto } = require('../middleware/auth');

module.exports = Router()
  .post('/', c.crear)
  .get('/mi', contacto, c.mio)
  .put('/mi', contacto, c.actualizar);

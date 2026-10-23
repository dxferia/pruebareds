const { Router } = require('express');
const c = require('../controllers/encuestas.controller');
const { contactoOpcional } = require('../middleware/auth');

module.exports = Router()
  .get('/', c.listar)
  .get('/:id', c.detalle)
  .post('/:id/respuestas', contactoOpcional, c.responder);

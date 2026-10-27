const { Router } = require('express');
const c = require('../controllers/catalogo.controller');
const { contacto, cuentaHabilitada } = require('../middleware/auth');

// /publicaciones/mias va antes de /publicaciones/:id ("mias" también es un id válido).
module.exports = Router()
  .get('/categorias', c.categorias)
  .get('/publicaciones', c.publicaciones)
  .post('/publicaciones', contacto, cuentaHabilitada, c.crear)
  .get('/publicaciones/mias', contacto, c.mias)
  .get('/publicaciones/:id', c.publicacion);

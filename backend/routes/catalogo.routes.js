const { Router } = require('express');
const c = require('../controllers/catalogo.controller');

module.exports = Router()
  .get('/categorias', c.categorias)
  .get('/publicaciones', c.publicaciones)
  .get('/publicaciones/:id', c.publicacion);

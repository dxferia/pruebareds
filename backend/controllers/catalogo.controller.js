const catalogo = require('../services/catalogo.service');
const { HttpError, requerir, id } = require('../utils/validacion');

module.exports = {
  categorias: async (req, res) => res.json(await catalogo.categorias()),

  publicaciones: async (req, res) => {
    const { categoria } = req.query;
    if (categoria !== undefined) requerir(/^[1-9]\d{0,9}$/.test(String(categoria)), 'Categoría inválida.');
    res.json(await catalogo.publicaciones(categoria && Number(categoria)));
  },

  publicacion: async (req, res) => {
    const p = await catalogo.publicacion(id(req.params.id, 'Publicación inválida.'));
    if (!p) throw new HttpError(404, 'La publicación no existe o ya no está vigente.');
    res.json(p);
  },
};

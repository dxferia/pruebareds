const catalogo = require('../services/catalogo.service');
const { HttpError, requerir, texto, id, enteroPositivo, rangoFechas } = require('../utils/validacion');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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

  // 201 = creada ahora; 200 = reintento del mismo envío (misma clave_envio), devuelve la ya creada.
  crear: async (req, res) => {
    const d = req.body || {};
    requerir(enteroPositivo(d.id_categoria), 'Selecciona una categoría.');
    requerir(['LABOR', 'SERVICIO'].includes(d.tipo), 'Selecciona el tipo: Labor o Servicio.');
    requerir(d.clave_envio === undefined || UUID.test(d.clave_envio), 'Identificador de envío inválido.');
    rangoFechas(d.disponible_desde, d.disponible_hasta);
    const { creada, publicacion } = await catalogo.crear(req.contacto.id_cuenta, {
      id_categoria: d.id_categoria,
      tipo: d.tipo,
      titulo: texto(d.titulo, 255, 'El título debe tener entre 5 y 255 caracteres.', 5),
      descripcion: texto(d.descripcion, 10000, 'Agrega una descripción de al menos 10 caracteres.', 10),
      cantidad: texto(d.cantidad, 100, 'La cantidad admite hasta 100 caracteres.', 0),
      ubicacion: texto(d.ubicacion, 255, 'Ingresa la ubicación (3 a 255 caracteres).', 3),
      disponible_desde: d.disponible_desde,
      disponible_hasta: d.disponible_hasta,
    }, d.clave_envio?.toLowerCase());
    res.status(creada ? 201 : 200).json(publicacion);
  },

  mias: async (req, res) => res.json(await catalogo.mias(req.contacto.id_cuenta)),
};

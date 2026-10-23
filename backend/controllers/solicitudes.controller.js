const solicitudes = require('../services/solicitudes.service');
const { requerir, texto, id, enteroPositivo, rangoFechas } = require('../utils/validacion');

module.exports = {
  crearPublicacion: async (req, res) => {
    const d = req.body || {};
    requerir(enteroPositivo(d.id_categoria), 'Selecciona una categoría.');
    rangoFechas(d.disponible_desde, d.disponible_hasta);
    res.status(201).json(await solicitudes.crearPublicacion(req.contacto.id_cuenta, {
      id_categoria: d.id_categoria,
      titulo: texto(d.titulo, 255, 'El título debe tener entre 5 y 255 caracteres.', 5),
      descripcion: texto(d.descripcion, 10000, 'Agrega una descripción de al menos 10 caracteres.', 10),
      cantidad: texto(d.cantidad, 100, 'La cantidad admite hasta 100 caracteres.', 0),
      ubicacion: texto(d.ubicacion, 255, 'Ingresa la ubicación (3 a 255 caracteres).', 3),
      disponible_desde: d.disponible_desde,
      disponible_hasta: d.disponible_hasta,
      contacto_autorizado: texto(d.contacto_autorizado, 255, 'Indica cómo pueden contactarte.'),
    }));
  },

  misPublicaciones: async (req, res) => res.json(await solicitudes.misPublicaciones(req.contacto.id_cuenta)),

  crearContacto: async (req, res) => {
    const d = req.body || {};
    const telefono = texto(d.telefono_autorizado ?? req.contacto.telefono, 30, 'Ingresa un teléfono válido.', 7);
    requerir(/^\+?[0-9()\s-]{7,30}$/.test(telefono), 'Ingresa un teléfono válido.');
    res.status(201).json(await solicitudes.crearContacto(req.contacto.id_cuenta, {
      id_publicacion: id(d.id_publicacion, 'Publicación no válida.'),
      motivo: texto(d.motivo, 2000, 'Explica brevemente el motivo (mínimo 5 caracteres).', 5),
      telefono_autorizado: telefono,
    }));
  },

  misContactos: async (req, res) => res.json(await solicitudes.misContactos(req.contacto.id_cuenta)),
};

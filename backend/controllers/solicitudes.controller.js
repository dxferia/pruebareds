const solicitudes = require('../services/solicitudes.service');
const { requerir, texto, id } = require('../utils/validacion');

module.exports = {
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

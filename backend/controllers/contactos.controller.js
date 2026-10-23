const contactos = require('../services/contactos.service');
const { requerir, texto, correoValido, telefonoValido } = require('../utils/validacion');

function validar(d = {}) {
  const nombre = texto(d.nombre, 150, 'Ingresa tu nombre completo.', 2);
  const correo = String(d.correo ?? '').trim().toLowerCase();
  const telefono = String(d.telefono ?? '').trim();
  const medio = String(d.medio_preferido ?? '').trim().toUpperCase();
  requerir(correoValido(correo), 'El correo no es válido.');
  requerir(telefonoValido(telefono), 'El teléfono no es válido.');
  requerir(['WHATSAPP', 'LLAMADA', 'CORREO'].includes(medio), 'El medio de contacto no es válido.');
  return { nombre, correo, telefono, medio_preferido: medio };
}

module.exports = {
  validar,
  crear: async (req, res) => res.status(201).json(await contactos.crear(validar(req.body))),
  mio: (req, res) => res.json(req.contacto),
  actualizar: async (req, res) => res.json(await contactos.actualizar(req.contacto, validar(req.body))),
};

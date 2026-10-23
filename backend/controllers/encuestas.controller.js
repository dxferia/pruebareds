const encuestas = require('../services/encuestas.service');
const { id } = require('../utils/validacion');

module.exports = {
  listar: async (req, res) => res.json(await encuestas.listar()),
  detalle: async (req, res) => res.json(await encuestas.detalle(id(req.params.id, 'Encuesta inválida.'))),
  // Con X-Contact-Key la respuesta se vincula al contacto; sin ella queda anónima.
  responder: async (req, res) => res.status(201).json(
    await encuestas.responder(id(req.params.id, 'Encuesta inválida.'), req.contacto?.id_cuenta ?? null, req.body?.respuestas)),
};

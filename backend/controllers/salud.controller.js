const { estadoBd } = require('../services/salud.service');

module.exports = {
  // 200 si la API y MySQL responden; 503 si la base no está disponible o le faltan tablas.
  salud: async (req, res) => {
    const { version, ...bd } = await estadoBd(); // la versión de MySQL no se publica
    const ok = bd.conectada && !bd.tablas_faltantes.length;
    res.status(ok ? 200 : 503).json({ estado: ok ? 'ok' : 'degradado', servicio: 'sihaychamba', base_datos: bd });
  },
};

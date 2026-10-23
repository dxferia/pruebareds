const { Router } = require('express');
const auth = require('../middleware/auth');

const router = Router();
router.get('/health', require('../controllers/salud.controller').salud);
router.use(require('./catalogo.routes'));
router.use('/contactos', require('./contactos.routes'));
router.use(require('./solicitudes.routes'));
router.use('/encuestas', require('./encuestas.routes'));
router.use('/admin', auth.admin, require('./admin.routes'));

module.exports = router;

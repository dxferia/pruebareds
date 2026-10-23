// Orígenes de Flutter Web (CORS_ORIGIN). En desarrollo también se acepta cualquier puerto de localhost,
// porque `flutter run -d chrome` puede elegir otro puerto. Las apps móviles no envían Origin.
const cors = require('cors');

const permitidos = (process.env.CORS_ORIGIN || 'http://localhost:8080,http://127.0.0.1:8080').split(',').map((s) => s.trim());
const localhostDev = (o) => process.env.NODE_ENV !== 'production' && /^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(o);

module.exports = cors({ origin: (origen, cb) => cb(null, !origen || permitidos.includes(origen) || localhostDev(origen)) });

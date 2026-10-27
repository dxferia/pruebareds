const express = require('express');
const path = require('path');
const routes = require('./routes'); // carga config/db.js, que lee backend/.env y crea el pool de mysql2/promise
const cors = require('./middleware/cors');
const { noEncontrado, manejarErrores } = require('./middleware/errores');
const { estadoBd } = require('./services/salud.service');

const app = express();
app.disable('x-powered-by');

app.use(cors); // antes de express.json para que los errores de JSON también lleven cabeceras CORS
app.use(express.json({ limit: '32kb' }));

// Servir los archivos estáticos de la carpeta public.
app.use(express.static(path.join(__dirname, 'public')));

app.use('/api', routes);
app.use(noEncontrado);
app.use(manejarErrores);

// Iniciar servidor. La app Flutter usa el puerto 3000 por defecto (lib/utils/config.dart): PORT=3000 en .env.
const PORT = process.env.PORT || 8082;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Servidor corriendo en el puerto ${PORT}`);
    // .env solo se lee al arrancar (npm run dev tampoco lo vigila): reinicia tras cambiar ADMIN_API_KEY.
    const clave = (process.env.ADMIN_API_KEY || '').trim().length;
    console.log(clave >= 32 ? `Administración de la Junta: activa (clave de ${clave} caracteres).`
      : 'Administración de la Junta: DESACTIVADA. Pon ADMIN_API_KEY (≥ 32 caracteres) en backend/.env y reinicia.');
    estadoBd().then((bd) => console.log(bd.conectada
      ? `MySQL conectado a "${bd.base}". Tablas faltantes: ${bd.tablas_faltantes.join(', ') || 'ninguna'}`
      : `MySQL NO disponible (${bd.codigo}). ${bd.sugerencia || ''}`));
  });
}

module.exports = app;

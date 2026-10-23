const express=require('express');const cors=require('cors');
const routes=require('./routes/api');
const {noEncontrado,manejarErrores}=require('./middleware/errors');
function crearApp(db){
 const app=express();app.disable('x-powered-by');
 const permitidos=(process.env.CORS_ORIGIN||'http://localhost:8080,http://127.0.0.1:8080').split(',').map(s=>s.trim());
 const localhostDev=origin=>process.env.NODE_ENV!=='production'&&/^http:\/\/(localhost|127\.0\.0\.1):\d+$/.test(origin);
 app.use(cors({origin:(origen,cb)=>cb(null,!origen||(permitidos.includes(origen)||localhostDev(origen)))}));
 app.use(express.json({limit:'32kb'}));
 app.get('/api/health',(req,res)=>res.json({estado:'ok',servicio:'sihaychamba'}));
 // Modo de prueba SIN LOGIN: la API comunitaria está disponible sin token.
 // IMPORTANTE: /api/admin/* sigue requiriendo X-Admin-Key.
 // Los perfiles y solicitudes personales siguen exigiendo X-Contact-Key.
 app.use('/api',routes(db));
 app.use(noEncontrado);app.use(manejarErrores);
 return app;
}
module.exports={crearApp};

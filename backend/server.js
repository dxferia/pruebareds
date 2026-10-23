require('dotenv').config();
const {crearPool}=require('./src/config/database');
const {crearApp}=require('./src/app');
async function iniciar(){
 const db=crearPool();
 try{const conexion=await db.getConnection();await conexion.query('SELECT 1');conexion.release();}
 catch(error){console.error('No se pudo conectar a MySQL:',error.code||error.message);await db.end();process.exitCode=1;return;}
 const port=Number(process.env.PORT||3000);
 crearApp(db).listen(port,'0.0.0.0',()=>console.log(`API Travesías Conecta en http://localhost:${port}`));
}
if(require.main===module) iniciar();
module.exports={iniciar};

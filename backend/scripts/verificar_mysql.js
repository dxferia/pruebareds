// Diagnóstico de conexión; no muestra contraseñas ni las escribe en logs.
require('dotenv').config();
const {crearPool}=require('../src/config/database');

const tablasNecesarias=[
  'cuenta_acceso','categoria','solicitud_publicacion','publicacion',
  'metodo_pago','solicitud_contacto','historial_gestion',
  'contacto_perfil','encuesta','pregunta_encuesta','respuesta_encuesta',
  'detalle_respuesta_encuesta'
];

function sugerencia(codigo){
  switch(codigo){
    case 'ECONNREFUSED':
    case 'ETIMEDOUT':
    case 'EHOSTUNREACH':
    case 'ENETUNREACH':
      return `Comprueba acceso a ${process.env.DB_HOST||'127.0.0.1'}:${process.env.DB_PORT||3308}, la VPN/red y el firewall.`;
    case 'ER_ACCESS_DENIED_ERROR':
      return 'Comprueba la contraseña local de .env y que el usuario tenga permiso para conectarse desde este equipo.';
    case 'ER_BAD_DB_ERROR':
      return `No existe la base ${process.env.DB_NAME||'sihaychamba'} en el servidor; comprueba el esquema antes de importar SQL.`;
    case 'ER_DBACCESS_DENIED_ERROR':
      return `El usuario no tiene permisos en ${process.env.DB_NAME||'sihaychamba'}.`;
    default:
      return 'Verifica los parámetros en backend/.env y prueba la conexión en MySQL Workbench.';
  }
}

async function main(){
  const host=process.env.DB_HOST||'127.0.0.1';
  const port=Number(process.env.DB_PORT||3308);
  const schema=process.env.DB_NAME||'sihaychamba';
  const user=process.env.DB_USER||'tc_backend';
  console.log(`Probando MySQL: ${host}:${port} | base=${schema} | usuario=${user}`);
  if(!process.env.DB_PASSWORD || process.env.DB_PASSWORD==='TcBackend#Cambiar2026!'){
    console.error('FALTA CONFIGURACIÓN: escribe tu contraseña REAL en backend/.env (no en .env.example).');
    process.exitCode=2;
    return;
  }
  const pool=crearPool();
  try{
    const [rows]=await pool.query('SELECT DATABASE() AS base, VERSION() AS version_mysql');
    console.log(`CONEXIÓN OK | MySQL ${rows[0].version_mysql} | base ${rows[0].base}`);
    const [tablas]=await pool.execute('SELECT TABLE_NAME AS nombre FROM information_schema.TABLES WHERE TABLE_SCHEMA = ?', [schema]);
    const presentes=new Set(tablas.map(r=>r.nombre));
    const faltan=tablasNecesarias.filter(t=>!presentes.has(t));
    console.log(`Tablas detectadas en ${schema}: ${tablas.length}`);
    if(faltan.length){
      console.error('FALTAN TABLAS DEL PROYECTO:',faltan.join(', '));
      console.error('Revisa sql/modelo_fisico_original.sql y sql/migraciones/ antes de utilizar la aplicación.');
      process.exitCode=2;
    }else{
      console.log('Esquema del proyecto: todas las 12 tablas esperadas están presentes.');
    }
  }catch(error){
    console.error(`CONEXIÓN FALLIDA: ${error.code||error.name||'ERROR'}`);
    console.error(sugerencia(error.code));
    process.exitCode=1;
  }finally{
    await pool.end();
  }
}
if(require.main===module) main();
module.exports={sugerencia};

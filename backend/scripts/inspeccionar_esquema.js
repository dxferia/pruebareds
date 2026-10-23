/** Auditoría de solo lectura del esquema al que apunta la configuración vigente. */
require('dotenv').config();
const {crearPool}=require('../src/config/database');
async function inspeccionar(){
  const pool=crearPool();
  try {
    const [actual]=await pool.query('SELECT DATABASE() AS nombre');
    const esquema=actual[0]?.nombre;
    if(!esquema) throw new Error('La conexión no tiene una base de datos seleccionada.');
    const [columnas]=await pool.execute(`SELECT TABLE_NAME,COLUMN_NAME,DATA_TYPE,COLUMN_TYPE,
      IS_NULLABLE,COLUMN_DEFAULT,COLUMN_KEY,EXTRA
      FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=? ORDER BY TABLE_NAME,ORDINAL_POSITION`,[esquema]);
    const [relaciones]=await pool.execute(`SELECT TABLE_NAME,COLUMN_NAME,CONSTRAINT_NAME,
      REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
      WHERE TABLE_SCHEMA=? AND REFERENCED_TABLE_NAME IS NOT NULL
      ORDER BY TABLE_NAME,CONSTRAINT_NAME,ORDINAL_POSITION`,[esquema]);
    const [tablas]=await pool.execute(`SELECT TABLE_NAME,TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_SCHEMA=? ORDER BY TABLE_NAME`,[esquema]);
    console.log(JSON.stringify({esquema,tablas,columnas,relaciones},null,2));
  }finally{await pool.end();}
}
if(require.main===module) inspeccionar().catch(err=>{
  console.error('No fue posible consultar el esquema:',err.code||err.message);
  process.exitCode=1;
});
module.exports={inspeccionar};

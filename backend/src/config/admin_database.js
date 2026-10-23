const mysql=require('mysql2/promise');
let pool;
function crearPoolAdmin(){
 if(!process.env.DB_ADMIN_USER||!process.env.DB_ADMIN_PASSWORD)throw new Error('Faltan DB_ADMIN_USER/DB_ADMIN_PASSWORD');
 if(!pool)pool=mysql.createPool({host:process.env.DB_HOST||'127.0.0.1',port:Number(process.env.DB_PORT||3308),
  user:process.env.DB_ADMIN_USER,password:process.env.DB_ADMIN_PASSWORD,
  database:process.env.DB_NAME||'sihaychamba',dateStrings:true,waitForConnections:true,connectTimeout:10000,connectionLimit:3});
 return pool;
}
module.exports={crearPoolAdmin};

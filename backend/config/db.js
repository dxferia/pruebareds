// Pool único de MySQL. Las credenciales se leen solo de backend/.env (nunca del código).
const path = require('node:path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

const faltantes = ['DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD'].filter((k) => process.env[k] === undefined);
if (faltantes.length) throw new Error(`Faltan variables en backend/.env: ${faltantes.join(', ')}`);

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  dateStrings: true, // DATE → 'YYYY-MM-DD' sin desfase de zona horaria (Flutter hace split('T')).
  connectTimeout: 10000,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// Ejecuta fn(conn) en una transacción. @actor_app alimenta los triggers de historial_gestion.
async function transaccion(actor, fn) {
  const conn = await pool.getConnection();
  try {
    await conn.query('SET @actor_app = ?', [actor]);
    await conn.beginTransaction();
    const resultado = await fn(conn);
    await conn.commit();
    return resultado;
  } catch (error) {
    await conn.rollback();
    throw error;
  } finally {
    await conn.query('SET @actor_app = NULL').catch(() => {});
    conn.release();
  }
}

module.exports = { pool, transaccion };

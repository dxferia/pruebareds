const mysql = require('mysql2/promise');

function crearPool() {
  return mysql.createPool({
    host: process.env.DB_HOST || '127.0.0.1',
    port: Number(process.env.DB_PORT || 3308),
    user: process.env.DB_USER || 'tc_backend',
    password: process.env.DB_PASSWORD || 'TcBackend#Cambiar2026!',
    database: process.env.DB_NAME || 'sihaychamba',
    dateStrings: true,
    connectTimeout: 10000,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
  });
}
module.exports = {crearPool};

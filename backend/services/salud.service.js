// Diagnóstico de solo lectura: conexión, base seleccionada y tablas requeridas. Nunca muestra credenciales.
// Uso directo: npm run db:check
const { pool } = require('../config/db');

const TABLAS = ['cuenta_acceso', 'categoria', 'metodo_pago', 'solicitud_publicacion', 'publicacion', 'solicitud_contacto',
  'historial_gestion', 'contacto_perfil', 'encuesta', 'pregunta_encuesta', 'respuesta_encuesta', 'detalle_respuesta_encuesta'];

const SUGERENCIAS = {
  ECONNREFUSED: 'MySQL no responde en DB_HOST:DB_PORT. ¿Está iniciado el servicio en 127.0.0.1:3308?',
  ETIMEDOUT: 'Tiempo agotado: revisa DB_HOST, DB_PORT, la red y el firewall.',
  ER_ACCESS_DENIED_ERROR: 'Usuario o contraseña rechazados: revisa DB_USER y DB_PASSWORD en backend/.env.',
  ER_BAD_DB_ERROR: 'La base DB_NAME no existe en ese servidor. Importa bd_sihaychamba.sql primero.',
};

async function estadoBd() {
  try {
    const [[info]] = await pool.query('SELECT DATABASE() AS base, VERSION() AS version');
    const [tablas] = await pool.execute('SELECT TABLE_NAME AS t FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()');
    const presentes = new Set(tablas.map((r) => r.t));
    return { conectada: true, base: info.base, version: info.version, tablas_faltantes: TABLAS.filter((t) => !presentes.has(t)) };
  } catch (error) {
    return { conectada: false, codigo: error.code || error.name, sugerencia: SUGERENCIAS[error.code] };
  }
}

if (require.main === module) {
  estadoBd().then((e) => {
    console.log(JSON.stringify(e, null, 2));
    if (!e.conectada || e.tablas_faltantes.length) process.exitCode = 1;
    if (e.tablas_faltantes?.length) console.error('Aplica las migraciones de sql/ que creen:', e.tablas_faltantes.join(', '));
    return pool.end();
  });
}

module.exports = { estadoBd };

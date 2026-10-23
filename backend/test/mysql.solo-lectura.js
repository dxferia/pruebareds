// Prueba de SOLO LECTURA contra el MySQL real configurado en backend/.env (npm run test:mysql).
// Ejecuta cada consulta SELECT de los servicios para confirmar que tablas, vistas y columnas existen en sihaychamba.
// No inserta, actualiza ni borra nada.
const test = require('node:test');
const assert = require('node:assert/strict');
const { pool } = require('../config/db');
const { estadoBd } = require('../services/salud.service');
const catalogo = require('../services/catalogo.service');
const solicitudes = require('../services/solicitudes.service');
const encuestas = require('../services/encuestas.service');
const admin = require('../services/admin.service');
const contactos = require('../services/contactos.service');

test.after(() => pool.end());

test('conexión y esquema sihaychamba', async () => {
  const bd = await estadoBd();
  assert.ok(bd.conectada, `Sin conexión: ${bd.codigo} ${bd.sugerencia || ''}`);
  assert.equal(bd.base, 'sihaychamba');
  assert.deepEqual(bd.tablas_faltantes, [], 'Aplica sql/001_perfiles_contacto.sql y sql/002_encuestas.sql');
});

test('procedimientos almacenados usados por la API', async () => {
  const [rows] = await pool.execute(`SELECT ROUTINE_NAME AS r FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE'`);
  const hay = new Set(rows.map((x) => x.r));
  for (const sp of ['sp_crear_solicitud_publicacion', 'sp_aprobar_solicitud_publicacion', 'sp_rechazar_solicitud_publicacion',
    'sp_crear_solicitud_contacto', 'sp_actualizar_publicacion', 'sp_cerrar_publicacion', 'sp_cambiar_estado_cuenta']) {
    assert.ok(hay.has(sp), `Falta ${sp}`);
  }
});

test('todas las consultas SELECT de los servicios son válidas contra el esquema real', async () => {
  assert.ok((await catalogo.categorias()).length > 0, 'categoria está vacía');
  await catalogo.publicaciones();
  await catalogo.publicacion('inexistente');
  await solicitudes.misPublicaciones('inexistente');
  await solicitudes.misContactos('inexistente');
  assert.equal(await contactos.porClave('0'.repeat(64)), null);
  await encuestas.listar();
  await admin.solicitudesPublicacion();
  await admin.solicitudesContacto();
  await admin.cuentas();
  await admin.historial();
});

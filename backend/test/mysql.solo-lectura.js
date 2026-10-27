// Prueba de SOLO LECTURA contra el MySQL real configurado en backend/.env (npm run test:mysql).
// Ejecuta cada consulta SELECT de los servicios para confirmar que tablas, vistas y columnas existen en sihaychamba.
// No inserta, actualiza ni borra nada.
const test = require('node:test');
const assert = require('node:assert/strict');
const { pool } = require('../config/db');
const { estadoBd } = require('../services/salud.service');
const catalogo = require('../services/catalogo.service');
const solicitudes = require('../services/solicitudes.service');
// Requiere la migración sql/004_publicacion_directa.sql.
const encuestas = require('../services/encuestas.service');
const admin = require('../services/admin.service');
const contactos = require('../services/contactos.service');

test.after(() => pool.end());

test('conexión y esquema sihaychamba', async () => {
  const bd = await estadoBd();
  assert.ok(bd.conectada, `Sin conexión: ${bd.codigo} ${bd.sugerencia || ''}`);
  assert.equal(bd.base, 'sihaychamba');
  assert.deepEqual(bd.tablas_faltantes, [], 'Ejecuta sql/extension_sihaychamba.sql');
});

test('procedimientos almacenados usados por la API', async () => {
  const [rows] = await pool.execute(`SELECT ROUTINE_NAME AS r FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE'`);
  const hay = new Set(rows.map((x) => x.r));
  for (const sp of ['sp_crear_publicacion', 'sp_crear_solicitud_contacto', 'sp_actualizar_publicacion', 'sp_cerrar_publicacion', 'sp_cambiar_estado_cuenta',
    'sp_crear_contacto', 'sp_actualizar_contacto', 'sp_registrar_respuesta_encuesta', 'sp_cambiar_estado_encuesta']) {
    assert.ok(hay.has(sp), `Falta ${sp}`);
  }
  for (const sp of ['sp_crear_solicitud_publicacion', 'sp_aprobar_solicitud_publicacion', 'sp_rechazar_solicitud_publicacion']) {
    assert.ok(!hay.has(sp), `${sp} debió retirarse (migración 004)`);
  }
});

test('migración 004: fecha_publicacion obligatoria, con valor por defecto e índice del catálogo', async () => {
  const [[col]] = await pool.execute(`SELECT IS_NULLABLE AS nulo, COLUMN_DEFAULT AS def, DATA_TYPE AS tipo FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'publicacion' AND COLUMN_NAME = 'fecha_publicacion'`);
  assert.ok(col, 'Falta publicacion.fecha_publicacion');
  assert.deepEqual([col.nulo, col.tipo, /current_timestamp/i.test(col.def)], ['NO', 'datetime', true]);
  const [idx] = await pool.execute(`SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publicacion' AND INDEX_NAME = 'idx_publicacion_recientes'`);
  assert.ok(idx.length, 'Falta idx_publicacion_recientes');
  const lista = await catalogo.publicaciones();
  const fechas = lista.map((p) => `${p.fecha_publicacion}|${p.id_publicacion}`);
  assert.deepEqual(fechas, [...fechas].sort().reverse(), 'el catálogo debe venir de la más reciente a la más antigua');
});

test('todas las consultas SELECT de los servicios son válidas contra el esquema real', async () => {
  assert.ok((await catalogo.categorias()).length > 0, 'categoria está vacía');
  await catalogo.publicaciones();
  await catalogo.publicacion('inexistente');
  await catalogo.mias('inexistente');
  await solicitudes.misContactos('inexistente');
  assert.equal(await contactos.porClave('0'.repeat(64)), null);
  await encuestas.listar();
  await admin.solicitudesContacto();
  await admin.cuentas();
  await admin.historial();
  await admin.contactos();
  await pool.execute('SELECT id_pregunta, total_respuestas, promedio, porcentaje_favorable FROM vw_resultados_encuesta LIMIT 1');
});

// Recorrido completo de la app Flutter contra la API (MySQL simulado: ver bd_simulada.js).
// Cada llamada reproduce las cabeceras y cuerpos que envía lib/services/api_service.dart.
const test = require('node:test');
const assert = require('node:assert/strict');
const bd = require('./bd_simulada').instalar();
const app = require('../app');

const ADMIN = 'k'.repeat(40);
let base, servidor;

async function api(metodo, ruta, { body, contacto, admin } = {}) {
  const headers = { Accept: 'application/json', 'Content-Type': 'application/json; charset=utf-8' };
  if (contacto) headers['X-Contact-Key'] = contacto;
  if (admin) headers['X-Admin-Key'] = admin;
  const res = await fetch(`${base}/api${ruta}`, { method: metodo, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: res.status, data: await res.json() }; // Flutter siempre decodifica JSON: nunca debe llegar un cuerpo vacío
}
const perfil = (nombre, telefono) => ({ nombre, correo: `${nombre.split(' ')[0].toLowerCase()}@correo.co`, telefono, medio_preferido: 'WHATSAPP' });
const solicitudFlutter = {
  titulo: 'Deshierbe de cultivo', id_categoria: 1, descripcion: 'Se requieren dos personas para deshierbe.',
  ubicacion: 'Sector La Escuela', cantidad: '2', disponible_desde: '2026-10-20', disponible_hasta: '2099-12-31', contacto_autorizado: '3001234567',
};

test.before(() => new Promise((ok) => { servidor = app.listen(0, () => { base = `http://127.0.0.1:${servidor.address().port}`; ok(); }); }));
test.after(() => servidor.close());

test('flujo completo habitante → Junta → contacto → encuesta', async (t) => {
  const s = {};

  await t.test('salud y catálogo', async () => {
    assert.equal((await api('GET', '/health')).status, 200);
    assert.deepEqual((await api('GET', '/categorias')).data.map((c) => c.nombre_categoria), ['Labores agrícolas', 'Carpintería']);
    assert.deepEqual((await api('GET', '/publicaciones')).data, []);
    assert.equal((await api('GET', '/publicaciones?categoria=abc')).status, 400);
  });

  await t.test('Mi contacto: registrar, consultar y actualizar', async () => {
    assert.equal((await api('POST', '/contactos', { body: { ...perfil('Ana Pérez', '1'), } })).status, 400);
    const r = await api('POST', '/contactos', { body: perfil('Ana Pérez', '+57 300 123 4567') });
    assert.equal(r.status, 201);
    assert.match(r.data.clave_edicion, /^[a-f0-9]{64}$/);
    assert.equal(r.data.estado, 'PENDIENTE');
    assert.ok(![...bd.t.perfil.keys()].includes(r.data.clave_edicion), 'en MySQL solo se guarda el hash');
    s.ana = r.data.clave_edicion;
    s.idAna = r.data.id_cuenta;
    const mi = await api('GET', '/contactos/mi', { contacto: s.ana });
    assert.equal(mi.data.correo, 'ana@correo.co');
    const put = await api('PUT', '/contactos/mi', { contacto: s.ana, body: { ...perfil('Ana María Pérez', '3009998877'), medio_preferido: 'CORREO' } });
    assert.equal(put.status, 200);
    assert.equal(bd.t.cuenta.get(s.idAna).nombre, 'Ana María Pérez');
    assert.equal((await api('GET', '/contactos/mi', { contacto: 'f'.repeat(64) })).status, 401);
    assert.equal((await api('GET', '/contactos/mi', { contacto: 'no-hex' })).status, 401);
  });

  await t.test('solicitud de publicación del habitante', async () => {
    assert.equal((await api('POST', '/solicitudes-publicacion', { body: solicitudFlutter })).status, 401);
    assert.equal((await api('POST', '/solicitudes-publicacion', { contacto: s.ana, body: { ...solicitudFlutter, disponible_hasta: '2026-10-01' } })).status, 400);
    assert.equal((await api('POST', '/solicitudes-publicacion', { contacto: s.ana, body: { ...solicitudFlutter, id_categoria: 99 } })).status, 409);
    const r = await api('POST', '/solicitudes-publicacion', { contacto: s.ana, body: solicitudFlutter });
    assert.equal(r.status, 201);
    s.solicitud = r.data.id_solicitud;
    const mias = await api('GET', '/solicitudes-publicacion/mias', { contacto: s.ana });
    assert.deepEqual(mias.data.map((x) => [x.id_solicitud, x.estado, x.nombre_categoria]), [[s.solicitud, 'PENDIENTE', 'Labores agrícolas']]);
  });

  await t.test('protección de /api/admin', async () => {
    delete process.env.ADMIN_API_KEY;
    assert.equal((await api('GET', '/admin/cuentas', { admin: 'x' })).status, 503);
    process.env.ADMIN_API_KEY = ADMIN;
    assert.equal((await api('GET', '/admin/cuentas')).status, 401);
    assert.equal((await api('GET', '/admin/cuentas', { admin: 'x'.repeat(40) })).status, 403);
    assert.equal((await api('GET', '/admin/cuentas', { admin: ADMIN })).status, 200);
  });

  await t.test('la Junta aprueba (tipo LABOR/SERVICIO) y la publicación queda vigente', async () => {
    const pendientes = await api('GET', '/admin/solicitudes-publicacion?estado=PENDIENTE', { admin: ADMIN });
    assert.equal(pendientes.data.length, 1);
    assert.equal((await api('POST', `/admin/solicitudes-publicacion/${s.solicitud}/aprobar`, { admin: ADMIN, body: {} })).status, 400);
    assert.equal((await api('POST', '/admin/solicitudes-publicacion/no-existe/aprobar', { admin: ADMIN, body: { tipo: 'LABOR' } })).status, 404);
    const ok = await api('POST', `/admin/solicitudes-publicacion/${s.solicitud}/aprobar`, { admin: ADMIN, body: { tipo: 'LABOR' } });
    assert.equal(ok.status, 200);
    s.pub = ok.data.id_publicacion;
    const otra = await api('POST', `/admin/solicitudes-publicacion/${s.solicitud}/aprobar`, { admin: ADMIN, body: { tipo: 'LABOR' } });
    assert.deepEqual([otra.status, otra.data.error], [409, 'Solo una solicitud PENDIENTE puede aprobarse.']);
    const lista = await api('GET', '/publicaciones?categoria=1');
    assert.deepEqual(Object.keys(lista.data[0]).filter((k) => ['id_publicacion', 'tipo', 'responsable', 'disponible_desde'].includes(k)).length, 4);
    assert.equal(lista.data[0].responsable, 'Ana María Pérez');
    assert.equal((await api('GET', `/publicaciones/${s.pub}`)).status, 200);
    assert.deepEqual((await api('GET', '/publicaciones?categoria=2')).data, []);
  });

  await t.test('solicitudes de contacto', async () => {
    const propia = await api('POST', '/solicitudes-contacto', { contacto: s.ana, body: { id_publicacion: s.pub, motivo: 'Quiero el trabajo', telefono_autorizado: '3001112233' } });
    assert.equal(propia.status, 409);
    s.luis = (await api('POST', '/contactos', { body: perfil('Luis Gómez', '3105556677') })).data.clave_edicion;
    const body = { id_publicacion: s.pub, motivo: 'Puedo ayudar el sábado', telefono_autorizado: '3105556677' };
    const r = await api('POST', '/solicitudes-contacto', { contacto: s.luis, body });
    assert.equal(r.status, 201);
    s.contacto = r.data.id_solicitud_contacto;
    assert.equal((await api('POST', '/solicitudes-contacto', { contacto: s.luis, body })).status, 409, 'sin duplicados pendientes');
    assert.equal((await api('POST', '/solicitudes-contacto', { contacto: s.luis, body: { ...body, id_publicacion: 'pub-x' } })).status, 404);
    const mias = await api('GET', '/solicitudes-contacto/mias', { contacto: s.luis });
    assert.deepEqual(mias.data.map((c) => [c.id_publicacion, c.estado, c.publicacion]), [[s.pub, 'PENDIENTE', 'Deshierbe de cultivo']]);
    assert.equal((await api('PATCH', `/admin/solicitudes-contacto/${s.contacto}`, { admin: ADMIN, body: { estado: 'APROBADA' } })).status, 200);
    assert.equal((await api('PATCH', `/admin/solicitudes-contacto/${s.contacto}`, { admin: ADMIN, body: { estado: 'RECHAZADA' } })).status, 409);
    assert.equal((await api('PATCH', '/admin/solicitudes-contacto/sc-x', { admin: ADMIN, body: { estado: 'APROBADA' } })).status, 404);
  });

  await t.test('cuentas: Flutter envía APPROVED/SUSPENDED y se traducen al ENUM de MySQL', async () => {
    const idLuis = [...bd.t.cuenta.values()].find((c) => c.nombre === 'Luis Gómez').id_cuenta;
    assert.equal((await api('PATCH', `/admin/cuentas/${idLuis}`, { admin: ADMIN, body: { estado: 'SUSPENDED' } })).data.estado, 'SUSPENDIDA');
    assert.equal((await api('PATCH', `/admin/cuentas/${idLuis}`, { admin: ADMIN, body: { estado: 'FOO' } })).status, 400);
    assert.equal((await api('PATCH', '/admin/cuentas/nadie', { admin: ADMIN, body: { estado: 'APPROVED' } })).status, 404);
    const bloqueada = await api('POST', '/solicitudes-publicacion', { contacto: s.luis, body: solicitudFlutter });
    assert.equal(bloqueada.status, 403);
    assert.equal((await api('GET', '/solicitudes-contacto/mias', { contacto: s.luis })).status, 200, 'puede seguir consultando');
  });

  await t.test('la Junta edita (PATCH parcial) y cierra la publicación', async () => {
    bd.t.publicacion.get(s.pub).id_metodo_pago = 7;
    const r = await api('PATCH', `/admin/publicaciones/${s.pub}`, { admin: ADMIN, body: { cantidad: '3', disponible_hasta: '2099-11-30' } });
    assert.equal(r.status, 200);
    assert.deepEqual([bd.t.publicacion.get(s.pub).cantidad, bd.t.publicacion.get(s.pub).id_metodo_pago], ['3', 7], 'conserva el método de pago');
    assert.equal((await api('PATCH', `/admin/publicaciones/${s.pub}`, { admin: ADMIN, body: { disponible_hasta: '2000-01-01' } })).status, 400);
    assert.equal((await api('PATCH', `/admin/publicaciones/${s.pub}`, { admin: ADMIN, body: {} })).status, 400);
    assert.equal((await api('POST', `/admin/publicaciones/${s.pub}/cerrar`, { admin: ADMIN })).status, 200);
    assert.equal((await api('POST', `/admin/publicaciones/${s.pub}/cerrar`, { admin: ADMIN })).status, 409);
    assert.deepEqual((await api('GET', '/publicaciones')).data, []);
    const eva = (await api('POST', '/contactos', { body: perfil('Eva Ruiz', '3200000000') })).data.clave_edicion;
    const cerrada = await api('POST', '/solicitudes-contacto', { contacto: eva, body: { id_publicacion: s.pub, motivo: 'Me interesa', telefono_autorizado: '3200000000' } });
    assert.deepEqual([cerrada.status, cerrada.data.error], [409, 'La publicación está cerrada.'], 'mensaje del trigger de MySQL');
  });

  await t.test('rechazo con motivo e historial', async () => {
    const id = (await api('POST', '/solicitudes-publicacion', { contacto: s.ana, body: { ...solicitudFlutter, titulo: 'Arreglo de cerca' } })).data.id_solicitud;
    assert.equal((await api('POST', `/admin/solicitudes-publicacion/${id}/rechazar`, { admin: ADMIN, body: { motivo: 'no' } })).status, 400);
    assert.equal((await api('POST', `/admin/solicitudes-publicacion/${id}/rechazar`, { admin: ADMIN, body: { motivo: 'Falta precisar la vereda' } })).status, 200);
    const mia = (await api('GET', '/solicitudes-publicacion/mias', { contacto: s.ana })).data.find((x) => x.id_solicitud === id);
    assert.deepEqual([mia.estado, mia.motivo_rechazo], ['RECHAZADA', 'Falta precisar la vereda']);
    const h = await api('GET', '/admin/historial', { admin: ADMIN });
    assert.ok(h.data.length && h.data.every((x) => !('antes' in x) && x.actor === 'Junta'));
  });

  await t.test('encuestas: anónima, vinculada (una vez) y validación', async () => {
    const lista = await api('GET', '/encuestas');
    const e = await api('GET', `/encuestas/${lista.data[0].id_encuesta}`);
    assert.deepEqual([e.data.preguntas.length, e.data.preguntas[0].obligatoria, e.data.preguntas[0].opciones_json], [2, true, []]);
    const respuestas = e.data.preguntas.map((p) => ({ id_pregunta: p.id_pregunta, valor: 4 }));
    const ruta = `/encuestas/${e.data.id_encuesta}/respuestas`;
    assert.equal((await api('POST', ruta, { body: { respuestas } })).status, 201);
    assert.equal((await api('POST', ruta, { body: { respuestas } })).status, 201, 'las anónimas no se limitan');
    assert.equal((await api('POST', ruta, { contacto: s.ana, body: { respuestas } })).status, 201);
    const dup = await api('POST', ruta, { contacto: s.ana, body: { respuestas } });
    assert.deepEqual([dup.status, dup.data.error], [409, 'Ya respondiste esta encuesta desde este contacto.']);
    assert.equal((await api('POST', ruta, { body: { respuestas: respuestas.slice(1) } })).status, 400);
    assert.equal((await api('POST', ruta, { body: { respuestas: [{ id_pregunta: 1, valor: 6 }, respuestas[1]] } })).status, 400);
    assert.equal((await api('GET', '/encuestas/otra')).status, 404);
    assert.equal(bd.t.respuestas[2].id_contacto, s.idAna);
  });

  await t.test('Junta: contactos, resultados calculados y cierre de encuesta', async () => {
    const c = await api('GET', '/admin/contactos', { admin: ADMIN });
    assert.ok(c.data.length >= 3 && c.data.every((x) => !('clave_edicion_hash' in x)));
    const r = await api('GET', '/admin/encuestas/travesias-usabilidad-v1/resultados', { admin: ADMIN });
    assert.deepEqual([r.data[0].total_respuestas, r.data[0].promedio, r.data[0].porcentaje_favorable], [3, 4, 100]);
    assert.equal((await api('GET', '/admin/encuestas/otra/resultados', { admin: ADMIN })).status, 404);
    assert.equal((await api('PATCH', '/admin/encuestas/travesias-usabilidad-v1', { admin: ADMIN, body: { estado: 'X' } })).status, 400);
    assert.equal((await api('PATCH', '/admin/encuestas/travesias-usabilidad-v1', { admin: ADMIN, body: { estado: 'CERRADA' } })).status, 200);
    assert.deepEqual((await api('GET', '/encuestas')).data, [], 'una encuesta cerrada deja de listarse');
    assert.equal((await api('POST', '/encuestas/travesias-usabilidad-v1/respuestas', { body: { respuestas: [] } })).status, 404);
  });

  await t.test('errores generales', async () => {
    const r = await fetch(`${base}/api/contactos`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{malo' });
    assert.deepEqual([r.status, (await r.json()).error], [400, 'El cuerpo JSON no es válido.']);
    assert.equal((await api('GET', '/no-existe')).status, 404);
  });

  await t.test('ninguna consulta SQL contiene datos del cliente (todo va por parámetros)', () => {
    const valores = ['Deshierbe', 'Ana María', 'Puedo ayudar', 'Falta precisar', s.solicitud, s.pub];
    for (const { sql } of bd.consultas) for (const v of valores) assert.ok(!sql.includes(v), `"${v}" apareció en: ${sql}`);
    assert.ok(bd.consultas.length > 50);
  });
});

// Recorrido completo de la app Flutter contra la API (MySQL simulado: ver bd_simulada.js).
// Cada llamada reproduce las cabeceras y cuerpos que envía lib/services/api_service.dart.
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
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
// Cuerpo que envía AppState.createPublication (el formulario «Publicar»).
const publicacionFlutter = (extra = {}) => ({
  titulo: 'Deshierbe de cultivo', id_categoria: 1, tipo: 'LABOR', descripcion: 'Se requieren dos personas para deshierbe.',
  ubicacion: 'Sector La Escuela', cantidad: '2', disponible_desde: '2026-10-20', disponible_hasta: '2099-12-31',
  clave_envio: crypto.randomUUID(), ...extra,
});
const ids = async (ruta = '/publicaciones') => (await api('GET', ruta)).data.map((p) => p.id_publicacion);

test.before(() => new Promise((ok) => { servidor = app.listen(0, () => { base = `http://127.0.0.1:${servidor.address().port}`; ok(); }); }));
test.after(() => servidor.close());

test('flujo completo: contacto → publicación inmediata → catálogo → contacto → Junta → encuesta', async (t) => {
  const s = {};

  await t.test('salud y catálogo', async () => {
    assert.equal((await api('GET', '/health')).status, 200);
    assert.deepEqual((await api('GET', '/categorias')).data.map((c) => c.nombre_categoria), ['Labores agrícolas', 'Carpintería']);
    assert.deepEqual((await api('GET', '/publicaciones')).data, []);
    assert.equal((await api('GET', '/publicaciones?categoria=abc')).status, 400);
  });

  await t.test('Prueba 1 · Mi contacto: registrar, consultar y actualizar', async () => {
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

  await t.test('Pruebas 2 y 3 · publicación inmediata con la cuenta aún PENDIENTE', async () => {
    assert.equal((await api('POST', '/publicaciones', { body: publicacionFlutter() })).status, 401, 'requiere Mi contacto');
    const r = await api('POST', '/publicaciones', { contacto: s.ana, body: publicacionFlutter() });
    assert.equal(r.status, 201);
    s.pub = r.data.id_publicacion;
    assert.equal(r.data.responsable, 'Ana María Pérez');
    assert.equal(r.data.fecha_publicacion, bd.t.reloj, 'devuelve la fecha asignada por MySQL');
    assert.equal(bd.t.publicacion.get(s.pub).id_solicitud_origen, null);
    assert.equal(bd.t.solicitud.size, 0, 'no se crea ninguna solicitud pendiente');
    assert.equal(bd.t.cuenta.get(s.idAna).estado, 'PENDIENTE', 'publicar no aprueba la cuenta');
    assert.deepEqual(await ids(), [s.pub], 'visible sin intervención de la Junta');
    assert.equal((await api('GET', `/publicaciones/${s.pub}`)).data.titulo, 'Deshierbe de cultivo');
  });

  await t.test('Pruebas 4 y 5 · la más reciente primero, también al volver a consultar', async () => {
    bd.t.reloj = '2026-10-26 10:00:00';
    const segunda = (await api('POST', '/publicaciones', { contacto: s.ana, body: publicacionFlutter({ titulo: 'Arreglo de cerca', id_categoria: 2, tipo: 'SERVICIO' }) })).data;
    assert.deepEqual(await ids(), [segunda.id_publicacion, s.pub]);
    // Misma fecha y hora: desempata id_publicacion DESC (orden estable entre consultas).
    bd.t.reloj = '2026-10-26 11:00:00';
    const claves = ['00000000-0000-4000-8000-00000000000a', '00000000-0000-4000-8000-00000000000b'];
    for (const clave_envio of claves) await api('POST', '/publicaciones', { contacto: s.ana, body: publicacionFlutter({ clave_envio }) });
    const esperado = [`pub-${claves[1]}`, `pub-${claves[0]}`, segunda.id_publicacion, s.pub];
    assert.deepEqual(await ids(), esperado);
    assert.deepEqual(await ids(), esperado, 'persistente al recargar');
    assert.deepEqual(await ids('/publicaciones?categoria=2'), [segunda.id_publicacion], 'el filtro conserva el orden');
    const mias = (await api('GET', '/publicaciones/mias', { contacto: s.ana })).data;
    assert.deepEqual(mias.map((p) => [p.id_publicacion, p.vigente]), esperado.map((id) => [id, 1]));
    assert.equal((await api('GET', '/publicaciones/mias')).status, 401);
    for (const id of claves) bd.t.publicacion.get(`pub-${id}`).activa = 0; // se retiran para no alterar las pruebas siguientes
  });

  await t.test('Prueba 6 · vigencia: cerradas y vencidas no aparecen', async () => {
    const vencida = (await api('POST', '/publicaciones', { contacto: s.ana, body: publicacionFlutter({ titulo: 'Poda de café' }) })).data.id_publicacion;
    assert.ok((await ids()).includes(vencida));
    bd.t.publicacion.get(vencida).disponible_hasta = '2000-01-01';
    assert.ok(!(await ids()).includes(vencida));
    assert.equal((await api('GET', `/publicaciones/${vencida}`)).status, 404);
    const mia = (await api('GET', '/publicaciones/mias', { contacto: s.ana })).data.find((p) => p.id_publicacion === vencida);
    assert.equal(mia.vigente, 0, 'sigue en el historial de la persona como vencida');
  });

  await t.test('Prueba 7 · reintentos del mismo envío no duplican', async () => {
    const cuerpo = publicacionFlutter({ titulo: 'Construcción de corral' });
    const antes = bd.t.publicacion.size;
    const respuestas = await Promise.all([1, 2, 3].map(() => api('POST', '/publicaciones', { contacto: s.ana, body: cuerpo })));
    assert.deepEqual(respuestas.map((r) => r.status).sort(), [200, 200, 201]);
    assert.equal(new Set(respuestas.map((r) => r.data.id_publicacion)).size, 1);
    assert.equal(bd.t.publicacion.size, antes + 1);
    assert.equal((await api('POST', '/publicaciones', { contacto: s.ana, body: { ...cuerpo, clave_envio: cuerpo.clave_envio.toUpperCase() } })).status, 200);
    s.luis = (await api('POST', '/contactos', { body: perfil('Luis Gómez', '3105556677') })).data.clave_edicion;
    const ajena = await api('POST', '/publicaciones', { contacto: s.luis, body: cuerpo });
    assert.equal(ajena.status, 409, 'la clave de otra persona no revela ni reutiliza su publicación');
    assert.equal(ajena.data.id_publicacion, undefined);
    assert.equal((await api('POST', '/publicaciones', { contacto: s.ana, body: { ...cuerpo, clave_envio: 'x' } })).status, 400);
    bd.t.publicacion.get(respuestas[0].data.id_publicacion).activa = 0;
  });

  await t.test('Prueba 8 · restricciones de datos', async () => {
    const antes = bd.t.publicacion.size;
    const casos = [
      [{ disponible_hasta: '2026-10-01' }, 400],
      [{ disponible_desde: '2026-02-30' }, 400],
      [{ disponible_desde: '2000-01-01', disponible_hasta: '2000-01-02' }, 409],
      [{ id_categoria: 99 }, 409],
      [{ id_categoria: '1' }, 400],
      [{ tipo: undefined }, 400],
      [{ tipo: 'OTRO' }, 400],
      [{ titulo: 'abc' }, 400],
      [{ descripcion: 'corta' }, 400],
    ];
    for (const [cambio, status] of casos) {
      const r = await api('POST', '/publicaciones', { contacto: s.ana, body: publicacionFlutter(cambio) });
      assert.equal(r.status, status, JSON.stringify(cambio));
      assert.equal(typeof r.data.error, 'string');
    }
    assert.equal((await api('POST', '/publicaciones', { contacto: s.ana, body: publicacionFlutter({ id_categoria: 99 }) })).data.error, 'La categoría no existe.');
    assert.equal((await api('POST', '/publicaciones', { contacto: 'a'.repeat(64), body: publicacionFlutter() })).status, 401, 'responsable no válido');
    assert.equal(bd.t.publicacion.size, antes);
  });

  await t.test('las rutas de aprobación ya no existen', async () => {
    assert.equal((await api('POST', '/solicitudes-publicacion', { contacto: s.ana, body: publicacionFlutter() })).status, 404);
    assert.equal((await api('GET', '/solicitudes-publicacion/mias', { contacto: s.ana })).status, 404);
    process.env.ADMIN_API_KEY = ADMIN;
    assert.equal((await api('GET', '/admin/solicitudes-publicacion', { admin: ADMIN })).status, 404);
    assert.equal((await api('POST', `/admin/solicitudes-publicacion/x/aprobar`, { admin: ADMIN, body: { tipo: 'LABOR' } })).status, 404);
    assert.ok(!bd.consultas.some(({ sql }) => /solicitud_publicacion|sp_aprobar|sp_rechazar/.test(sql)), 'nada consulta el flujo anterior');
  });

  await t.test('protección de /api/admin (X-Admin-Key)', async () => {
    delete process.env.ADMIN_API_KEY;
    assert.equal((await api('GET', '/admin/cuentas', { admin: 'x' })).status, 503);
    process.env.ADMIN_API_KEY = ADMIN;
    assert.equal((await api('GET', '/admin/cuentas')).status, 401);
    assert.equal((await api('GET', '/admin/cuentas', { admin: 'x'.repeat(40) })).status, 403);
    assert.equal((await api('GET', '/admin/cuentas', { admin: ADMIN })).status, 200);
    process.env.ADMIN_API_KEY = ` ${ADMIN}\r`; // .env editado en Windows o con espacios
    assert.equal((await api('GET', '/admin/cuentas', { admin: ADMIN })).status, 200);
    process.env.ADMIN_API_KEY = ADMIN;
  });

  await t.test('CORS: Flutter Web (localhost, otro puerto) puede enviar X-Admin-Key', async () => {
    const r = await fetch(`${base}/api/admin/cuentas`, { method: 'OPTIONS', headers: { Origin: 'http://localhost:53124',
      'Access-Control-Request-Method': 'GET', 'Access-Control-Request-Headers': 'content-type,x-admin-key' } });
    assert.equal(r.status, 204);
    assert.equal(r.headers.get('access-control-allow-origin'), 'http://localhost:53124');
    assert.match(r.headers.get('access-control-allow-headers'), /x-admin-key/i);
  });

  await t.test('Prueba 10 · solicitudes de contacto sobre una publicación directa', async () => {
    const propia = await api('POST', '/solicitudes-contacto', { contacto: s.ana, body: { id_publicacion: s.pub, motivo: 'Quiero el trabajo', telefono_autorizado: '3001112233' } });
    assert.equal(propia.status, 409);
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

  await t.test('Prueba 9 · gestión de cuentas: suspendida no publica, PENDIENTE sí', async () => {
    const idLuis = [...bd.t.cuenta.values()].find((c) => c.nombre === 'Luis Gómez').id_cuenta;
    assert.equal((await api('PATCH', `/admin/cuentas/${idLuis}`, { admin: ADMIN, body: { estado: 'SUSPENDED' } })).data.estado, 'SUSPENDIDA');
    assert.equal((await api('PATCH', `/admin/cuentas/${idLuis}`, { admin: ADMIN, body: { estado: 'FOO' } })).status, 400);
    assert.equal((await api('PATCH', '/admin/cuentas/nadie', { admin: ADMIN, body: { estado: 'APPROVED' } })).status, 404);
    assert.equal((await api('POST', '/publicaciones', { contacto: s.luis, body: publicacionFlutter() })).status, 403);
    assert.equal((await api('GET', '/solicitudes-contacto/mias', { contacto: s.luis })).status, 200, 'puede seguir consultando');
    assert.deepEqual((await api('GET', '/admin/cuentas', { admin: ADMIN })).data.map((c) => c.estado).sort(), ['PENDIENTE', 'PENDIENTE', 'SUSPENDIDA']);
  });

  await t.test('Prueba 10 · la Junta edita (PATCH parcial) y cierra la publicación', async () => {
    bd.t.publicacion.get(s.pub).id_metodo_pago = 7;
    const r = await api('PATCH', `/admin/publicaciones/${s.pub}`, { admin: ADMIN, body: { cantidad: '3', disponible_hasta: '2099-11-30' } });
    assert.equal(r.status, 200);
    assert.deepEqual([bd.t.publicacion.get(s.pub).cantidad, bd.t.publicacion.get(s.pub).id_metodo_pago], ['3', 7], 'conserva el método de pago');
    assert.equal((await api('PATCH', `/admin/publicaciones/${s.pub}`, { admin: ADMIN, body: { disponible_hasta: '2000-01-01' } })).status, 400);
    assert.equal((await api('PATCH', `/admin/publicaciones/${s.pub}`, { admin: ADMIN, body: {} })).status, 400);
    assert.equal((await api('POST', `/admin/publicaciones/${s.pub}/cerrar`, { admin: ADMIN })).status, 200);
    assert.equal((await api('POST', `/admin/publicaciones/${s.pub}/cerrar`, { admin: ADMIN })).status, 409);
    assert.ok(!(await ids()).includes(s.pub));
    const eva = (await api('POST', '/contactos', { body: perfil('Eva Ruiz', '3200000000') })).data.clave_edicion;
    const cerrada = await api('POST', '/solicitudes-contacto', { contacto: eva, body: { id_publicacion: s.pub, motivo: 'Me interesa', telefono_autorizado: '3200000000' } });
    assert.deepEqual([cerrada.status, cerrada.data.error], [409, 'La publicación está cerrada.'], 'mensaje del trigger de MySQL');
  });

  await t.test('Prueba 10 · auditoría: cada publicación queda en el historial', async () => {
    const h = await api('GET', '/admin/historial', { admin: ADMIN });
    assert.ok(h.data.length && h.data.every((x) => !('antes' in x)));
    assert.ok(h.data.some((x) => x.accion === 'CREAR_PUBLICACION' && x.elemento_afectado === `publicacion:${s.pub}` && x.actor === s.idAna));
  });

  await t.test('Prueba 10 · encuestas: anónima, vinculada (una vez) y validación', async () => {
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
    const valores = ['Deshierbe', 'Ana María', 'Puedo ayudar', 'Arreglo de cerca', s.pub];
    for (const { sql } of bd.consultas) for (const v of valores) assert.ok(!sql.includes(v), `"${v}" apareció en: ${sql}`);
    assert.ok(bd.consultas.length > 50);
  });
});

// Simulación en memoria de sihaychamba para probar rutas, controladores y servicios sin MySQL.
// Reemplaza config/db.js en require.cache. Además verifica que TODA consulta esté parametrizada:
// el número de "?" debe coincidir con los parámetros y ningún valor del cliente puede aparecer en el SQL.
const path = require('node:path');

const err45000 = (msg) => Object.assign(new Error(msg), { sqlState: '45000', sqlMessage: msg });
const hoy = () => new Date().toISOString().slice(0, 10);

function crearBd() {
  const t = {
    categoria: [{ id_categoria: 1, nombre_categoria: 'Labores agrícolas' }, { id_categoria: 2, nombre_categoria: 'Carpintería' }],
    cuenta: new Map([['acc-001', { id_cuenta: 'acc-001', nombre: 'María P.', estado: 'PENDIENTE' }]]),
    perfil: new Map(), // hash → perfil
    solicitud: new Map(),
    publicacion: new Map(),
    contacto: new Map(),
    respuestas: [],
    historial: [],
    encuesta: { id_encuesta: 'travesias-usabilidad-v1', titulo: 'Encuesta de usabilidad', descripcion: 'Prueba', version_encuesta: 1 },
    preguntas: [1, 2].map((n) => ({ id_pregunta: n, numero: n, texto: `P${n}`, tipo: 'ESCALA', obligatoria: 1, opciones_json: null })),
  };
  const consultas = [];
  const vigente = (p) => p.activa && p.disponible_hasta >= hoy();
  const vista = (p) => ({ ...p, nombre_categoria: t.categoria.find((c) => c.id_categoria === p.id_categoria).nombre_categoria,
    responsable: t.cuenta.get(p.id_responsable).nombre, nombre_metodo_pago: null });

  async function ejecutar(sql, p = [], actor) {
    const marcas = (sql.match(/\?/g) || []).length;
    if (marcas !== p.length) throw new Error(`Consulta no parametrizada (${marcas} ? / ${p.length} params): ${sql}`);
    consultas.push({ sql, p, actor });
    const s = sql.replace(/\s+/g, ' ');
    const has = (x) => s.includes(x);

    if (has('SET @actor_app')) return [[]];
    if (has('SELECT DATABASE()')) return [[{ base: 'sihaychamba', version: 'sim' }]];
    if (has('information_schema.TABLES')) return [['cuenta_acceso', 'categoria', 'metodo_pago', 'solicitud_publicacion', 'publicacion',
      'solicitud_contacto', 'historial_gestion', 'contacto_perfil', 'encuesta', 'pregunta_encuesta', 'respuesta_encuesta',
      'detalle_respuesta_encuesta'].map((x) => ({ t: x }))];
    // Contactos
    if (has('FROM contacto_perfil p JOIN')) { const r = t.perfil.get(p[0]); return [r ? [{ ...r, ...t.cuenta.get(r.id_cuenta) }] : []]; }
    if (has('INSERT INTO cuenta_acceso')) { t.cuenta.set(p[0], { id_cuenta: p[0], nombre: p[1], estado: 'PENDIENTE' }); return [{ affectedRows: 1 }]; }
    if (has('INSERT INTO contacto_perfil')) { t.perfil.set(p[4], { id_cuenta: p[0], correo: p[1], telefono: p[2], medio_preferido: p[3] }); return [{ affectedRows: 1 }]; }
    if (has('UPDATE cuenta_acceso SET nombre')) { t.cuenta.get(p[1]).nombre = p[0]; return [{ affectedRows: 1 }]; }
    if (has('UPDATE contacto_perfil')) { for (const r of t.perfil.values()) if (r.id_cuenta === p[3]) Object.assign(r, { correo: p[0], telefono: p[1], medio_preferido: p[2] }); return [{ affectedRows: 1 }]; }
    // Catálogo
    if (has('FROM categoria')) return [t.categoria];
    if (has('FROM vw_publicaciones_vigentes')) {
      let rows = [...t.publicacion.values()].filter(vigente).map(vista);
      if (has('WHERE id_categoria')) rows = rows.filter((r) => r.id_categoria === p[0]);
      if (has('WHERE id_publicacion')) rows = rows.filter((r) => r.id_publicacion === p[0]);
      return [rows];
    }
    // Solicitudes de publicación
    if (has('CALL sp_crear_solicitud_publicacion')) {
      if (!t.categoria.some((c) => c.id_categoria === p[2])) throw Object.assign(new Error('fk'), { code: 'ER_NO_REFERENCED_ROW_2' });
      const [id_solicitud, id_solicitante, id_categoria, titulo, descripcion, cantidad, ubicacion, disponible_desde, disponible_hasta, contacto_autorizado] = p;
      t.solicitud.set(id_solicitud, { id_solicitud, id_solicitante, id_categoria, titulo, descripcion, cantidad, ubicacion, disponible_desde,
        disponible_hasta, contacto_autorizado, fecha_solicitud: `${hoy()} 10:00:00`, estado: 'PENDIENTE', motivo_rechazo: null });
      return [{ affectedRows: 1 }];
    }
    if (has('FROM vw_solicitudes_publicacion')) {
      let rows = [...t.solicitud.values()].map((r) => ({ ...r, solicitante: t.cuenta.get(r.id_solicitante).nombre,
        nombre_categoria: t.categoria.find((c) => c.id_categoria === r.id_categoria).nombre_categoria }));
      if (has('WHERE id_solicitante')) rows = rows.filter((r) => r.id_solicitante === p[0]);
      if (has('WHERE estado')) rows = rows.filter((r) => r.estado === p[0]);
      return [rows];
    }
    if (has('FROM solicitud_publicacion WHERE id_solicitud')) { const r = t.solicitud.get(p[0]); return [r ? [r] : []]; }
    if (has('CALL sp_aprobar_solicitud_publicacion')) {
      const s = t.solicitud.get(p[0]);
      if (s.estado !== 'PENDIENTE') throw err45000('Solo una solicitud PENDIENTE puede aprobarse.');
      s.estado = 'APROBADA';
      t.publicacion.set(p[1], { id_publicacion: p[1], id_categoria: s.id_categoria, id_responsable: p[2], id_metodo_pago: p[3], titulo: s.titulo,
        descripcion: s.descripcion, ubicacion: s.ubicacion, disponible_desde: s.disponible_desde, disponible_hasta: s.disponible_hasta,
        cantidad: s.cantidad, tipo: p[4], activa: 1 });
      t.historial.push({ fecha: `${hoy()} 10:00:00`, actor: p[5], accion: 'CREAR_PUBLICACION', elemento_afectado: `publicacion:${p[1]}` });
      return [{ affectedRows: 1 }];
    }
    if (has('CALL sp_rechazar_solicitud_publicacion')) {
      const s = t.solicitud.get(p[0]);
      if (s.estado !== 'PENDIENTE') throw err45000('La solicitud no existe o ya fue procesada.');
      Object.assign(s, { estado: 'RECHAZADA', motivo_rechazo: p[1] });
      return [{ affectedRows: 1 }];
    }
    // Solicitudes de contacto
    if (has('SELECT id_responsable, (SELECT COUNT(*)')) {
      const pub = t.publicacion.get(p[2]);
      const pendientes = [...t.contacto.values()].filter((c) => c.id_publicacion === p[0] && c.id_remitente === p[1] && c.estado === 'PENDIENTE').length;
      return [pub ? [{ id_responsable: pub.id_responsable, pendientes }] : []];
    }
    if (has('CALL sp_crear_solicitud_contacto')) {
      const pub = t.publicacion.get(p[1]);
      if (!pub.activa) throw err45000('La publicación está cerrada.');
      t.contacto.set(p[0], { id_solicitud_contacto: p[0], id_publicacion: p[1], id_remitente: p[2], id_responsable: pub.id_responsable,
        motivo: p[3], telefono_autorizado: p[4], fecha_solicitud: `${hoy()} 11:00:00`, estado: 'PENDIENTE' });
      return [{ affectedRows: 1 }];
    }
    if (has('FROM vw_solicitudes_contacto')) {
      let rows = [...t.contacto.values()].map((c) => ({ ...c, publicacion: t.publicacion.get(c.id_publicacion).titulo }));
      if (has('WHERE id_remitente')) rows = rows.filter((r) => r.id_remitente === p[0]);
      return [rows];
    }
    if (has('UPDATE solicitud_contacto SET estado')) {
      const c = t.contacto.get(p[1]);
      if (!c || c.estado !== 'PENDIENTE') return [{ affectedRows: 0 }];
      c.estado = p[0];
      return [{ affectedRows: 1 }];
    }
    if (has('FROM solicitud_contacto WHERE id_solicitud_contacto')) return [t.contacto.has(p[0]) ? [{ 1: 1 }] : []];
    // Publicaciones (Junta)
    if (has('FROM publicacion WHERE id_publicacion')) { const r = t.publicacion.get(p[0]); return [r ? [r] : []]; }
    if (has('CALL sp_actualizar_publicacion')) {
      const [id, descripcion, cantidad, ubicacion, disponible_desde, disponible_hasta, id_metodo_pago] = p;
      Object.assign(t.publicacion.get(id), { descripcion, cantidad, ubicacion, disponible_desde, disponible_hasta, id_metodo_pago });
      return [{ affectedRows: 1 }];
    }
    if (has('CALL sp_cerrar_publicacion')) { t.publicacion.get(p[0]).activa = 0; return [{ affectedRows: 1 }]; }
    // Cuentas e historial
    if (has('SELECT id_cuenta, nombre, estado FROM cuenta_acceso')) return [[...t.cuenta.values()]];
    if (has('SELECT 1 FROM cuenta_acceso')) return [t.cuenta.has(p[0]) ? [{ 1: 1 }] : []];
    if (has('CALL sp_cambiar_estado_cuenta')) { t.cuenta.get(p[0]).estado = p[1]; return [{ affectedRows: 1 }]; }
    if (has('FROM vw_historial_gestion')) return [t.historial];
    // Encuestas
    if (has('FROM encuesta')) return [has('WHERE id_encuesta') && p[0] !== t.encuesta.id_encuesta ? [] : [t.encuesta]];
    if (has('FROM pregunta_encuesta')) return [t.preguntas];
    if (has('INSERT INTO respuesta_encuesta')) {
      if (p[1] && t.respuestas.some((r) => r.id_encuesta === p[0] && r.id_contacto === p[1])) throw Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
      t.respuestas.push({ id_encuesta: p[0], id_contacto: p[1], detalles: [] });
      return [{ insertId: t.respuestas.length }];
    }
    if (has('INSERT INTO detalle_respuesta_encuesta')) { t.respuestas[p[0] - 1].detalles.push({ id_pregunta: p[1], valor: JSON.parse(p[2]) }); return [{ affectedRows: 1 }]; }
    throw new Error(`Consulta no prevista por la simulación: ${s}`);
  }

  const pool = { execute: (sql, p) => ejecutar(sql, p), query: (sql, p) => ejecutar(sql, p) };
  const transaccion = async (actor, fn) => fn({ execute: (sql, p) => ejecutar(sql, p, actor) });
  return { t, consultas, pool, transaccion };
}

// Instala la simulación ANTES de cargar app.js.
function instalar() {
  const bd = crearBd();
  const ruta = path.join(__dirname, '..', 'config', 'db.js');
  require.cache[ruta] = { id: ruta, filename: ruta, loaded: true, exports: { pool: bd.pool, transaccion: bd.transaccion } };
  return bd;
}

module.exports = { instalar };

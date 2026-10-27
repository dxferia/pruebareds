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
    reloj: '2026-10-26 09:00:00', // fecha_publicacion que asigna el DEFAULT CURRENT_TIMESTAMP simulado
    encuesta: { id_encuesta: 'travesias-usabilidad-v1', titulo: 'Encuesta de usabilidad', descripcion: 'Prueba', version_encuesta: 1 },
    preguntas: [1, 2].map((n) => ({ id_pregunta: n, numero: n, texto: `P${n}`, tipo: 'ESCALA', obligatoria: 1, opciones_json: null })),
  };
  const consultas = [];
  const vigente = (p) => p.activa && p.disponible_hasta >= hoy();
  const vista = (p) => ({ ...p, nombre_categoria: t.categoria.find((c) => c.id_categoria === p.id_categoria).nombre_categoria,
    responsable: t.cuenta.get(p.id_responsable).nombre, nombre_metodo_pago: null });
  // Solo se ordena si la consulta lo pide: así la prueba detecta un ORDER BY olvidado.
  const recientes = (s, rows) => (s.includes('ORDER BY fecha_publicacion DESC, id_publicacion DESC')
    ? rows.sort((a, b) => b.fecha_publicacion.localeCompare(a.fecha_publicacion) || b.id_publicacion.localeCompare(a.id_publicacion)) : rows);

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
    if (has('CALL sp_crear_contacto')) {
      t.cuenta.set(p[0], { id_cuenta: p[0], nombre: p[1], estado: 'PENDIENTE' });
      t.perfil.set(p[5], { id_cuenta: p[0], correo: p[2], telefono: p[3], medio_preferido: p[4] });
      return [{ affectedRows: 1 }];
    }
    if (has('CALL sp_actualizar_contacto')) {
      t.cuenta.get(p[0]).nombre = p[1];
      for (const r of t.perfil.values()) if (r.id_cuenta === p[0]) Object.assign(r, { correo: p[2], telefono: p[3], medio_preferido: p[4] });
      return [{ affectedRows: 1 }];
    }
    if (has('FROM vw_contactos_perfil')) return [[...t.perfil.values()].map((r) => ({ ...r, ...t.cuenta.get(r.id_cuenta) }))];
    // Catálogo
    if (has('FROM categoria')) return [t.categoria];
    if (has('FROM vw_publicaciones_vigentes')) {
      let rows = [...t.publicacion.values()].filter(vigente).map(vista);
      if (has('WHERE id_categoria')) rows = rows.filter((r) => r.id_categoria === p[0]);
      if (has('WHERE id_publicacion')) rows = rows.filter((r) => r.id_publicacion === p[0]);
      return [recientes(s, rows)];
    }
    // Publicación directa: mismas validaciones y orden que sp_crear_publicacion (004_publicacion_directa.sql).
    if (has('CALL sp_crear_publicacion')) {
      const [id_publicacion, id_responsable, id_categoria, id_metodo_pago, titulo, descripcion, ubicacion, disponible_desde, disponible_hasta, cantidad, tipo] = p;
      if (!['LABOR', 'SERVICIO'].includes(tipo)) throw err45000('El tipo debe ser LABOR o SERVICIO.');
      if (disponible_hasta < disponible_desde) throw err45000('La fecha final no puede ser anterior a la inicial.');
      if (disponible_hasta < hoy()) throw err45000('La fecha final ya pasó: la publicación no sería visible.');
      if (!t.categoria.some((c) => c.id_categoria === id_categoria)) throw err45000('La categoría no existe.');
      const cuenta = [...t.perfil.values()].some((r) => r.id_cuenta === id_responsable) && t.cuenta.get(id_responsable);
      if (!cuenta) throw err45000('El responsable no existe o no ha registrado Mi contacto.');
      if (['RECHAZADA', 'SUSPENDIDA'].includes(cuenta.estado)) throw err45000('La cuenta del responsable no puede publicar. Comunícate con la Junta.');
      if (t.publicacion.has(id_publicacion)) throw Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
      t.publicacion.set(id_publicacion, { id_publicacion, id_solicitud_origen: null, id_categoria, id_responsable, id_metodo_pago, titulo,
        descripcion, ubicacion, disponible_desde, disponible_hasta, cantidad, tipo, activa: 1, fecha_publicacion: t.reloj });
      t.historial.push({ fecha: t.reloj, actor: id_responsable, accion: 'CREAR_PUBLICACION', elemento_afectado: `publicacion:${id_publicacion}` });
      return [{ affectedRows: 1 }];
    }
    if (has('FROM publicacion p JOIN categoria c') && has('WHERE p.id_responsable')) {
      return [recientes(s, [...t.publicacion.values()].filter((r) => r.id_responsable === p[0])
        .map((r) => ({ ...vista(r), vigente: vigente(r) ? 1 : 0 })))];
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
    const encuestaVigente = t.encuesta.estado !== 'CERRADA';
    if (has('FROM vw_encuestas_vigentes')) return [!encuestaVigente || (has('WHERE id_encuesta') && p[0] !== t.encuesta.id_encuesta) ? [] : [t.encuesta]];
    if (has('SELECT 1 FROM encuesta')) return [p[0] === t.encuesta.id_encuesta ? [{ 1: 1 }] : []];
    if (has('CALL sp_cambiar_estado_encuesta')) { t.encuesta.estado = p[1]; return [{ affectedRows: 1 }]; }
    if (has('FROM vw_resultados_encuesta')) return [t.preguntas.map((q) => {
      const v = t.respuestas.flatMap((r) => r.detalles).filter((d) => d.id_pregunta === q.id_pregunta).map((d) => d.valor);
      return { ...q, total_respuestas: v.length, promedio: v.length ? v.reduce((a, b) => a + b, 0) / v.length : null,
        porcentaje_favorable: v.length ? (100 * v.filter((x) => x >= 4).length) / v.length : null };
    })];
    if (has('CALL sp_registrar_respuesta_encuesta')) {
      if (p[1] && t.respuestas.some((r) => r.id_encuesta === p[0] && r.id_contacto === p[1])) throw Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
      t.respuestas.push({ id_encuesta: p[0], id_contacto: p[1], detalles: JSON.parse(p[2]) });
      return [[[{ id_respuesta: t.respuestas.length }], { affectedRows: 0 }]];
    }
    if (has('FROM pregunta_encuesta')) return [t.preguntas];
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

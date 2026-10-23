// Encuestas (migración 002). Una respuesta por contacto y encuesta; las anónimas no tienen límite.
const { pool, transaccion } = require('../config/db');
const { HttpError, requerir } = require('../utils/validacion');

const ACTIVA = `estado = 'ACTIVA' AND (disponible_desde IS NULL OR disponible_desde <= NOW())
  AND (disponible_hasta IS NULL OR disponible_hasta >= NOW())`;
const PREGUNTAS = 'SELECT id_pregunta, numero, texto, tipo, obligatoria, opciones_json FROM pregunta_encuesta WHERE id_encuesta = ? ORDER BY numero';

const comoOpciones = (v) => {
  if (Array.isArray(v)) return v;
  try { const r = JSON.parse(v); return Array.isArray(r) ? r : []; } catch { return []; }
};

async function listar() {
  const [rows] = await pool.execute(`SELECT id_encuesta, titulo, descripcion, version_encuesta FROM encuesta WHERE ${ACTIVA} ORDER BY titulo`);
  return rows;
}

async function detalle(id) {
  const [rows] = await pool.execute(`SELECT id_encuesta, titulo, descripcion, version_encuesta FROM encuesta WHERE id_encuesta = ? AND ${ACTIVA}`, [id]);
  if (!rows.length) throw new HttpError(404, 'La encuesta no está disponible.');
  const [preguntas] = await pool.execute(PREGUNTAS, [id]);
  return { ...rows[0], preguntas: preguntas.map((p) => ({ ...p, obligatoria: Boolean(p.obligatoria), opciones_json: comoOpciones(p.opciones_json) })) };
}

// Valida cada respuesta contra el tipo de su pregunta (ESCALA 1-5, TEXTO, UNICA, MULTIPLE).
function validarRespuestas(preguntas, respuestas) {
  requerir(Array.isArray(respuestas), 'Las respuestas deben enviarse como una lista.');
  const mapa = new Map(preguntas.map((p) => [Number(p.id_pregunta), p]));
  const vistas = new Set();
  const normalizadas = respuestas.map((item) => {
    const id = item?.id_pregunta;
    requerir(Number.isInteger(id) && mapa.has(id), 'La pregunta indicada no pertenece a la encuesta.');
    requerir(!vistas.has(id), 'Hay una pregunta repetida.');
    vistas.add(id);
    const p = mapa.get(id);
    const v = item.valor;
    const opciones = comoOpciones(p.opciones_json);
    if (p.tipo === 'ESCALA') requerir(Number.isInteger(v) && v >= 1 && v <= 5, 'Selecciona un valor de 1 a 5.');
    else if (p.tipo === 'TEXTO') requerir(typeof v === 'string' && v.trim().length > 0 && v.trim().length <= 2000, 'La respuesta de texto no es válida.');
    else if (p.tipo === 'UNICA') requerir(typeof v === 'string' && opciones.includes(v), 'Selecciona una opción válida.');
    else if (p.tipo === 'MULTIPLE') requerir(Array.isArray(v) && v.length > 0 && new Set(v).size === v.length && v.every((x) => opciones.includes(x)), 'Selecciona opciones válidas.');
    else throw new HttpError(500, 'Tipo de pregunta no soportado.');
    return { id_pregunta: id, valor: typeof v === 'string' ? v.trim() : v };
  });
  const falta = preguntas.find((p) => Boolean(p.obligatoria) && !vistas.has(Number(p.id_pregunta)));
  requerir(!falta, `Falta responder la pregunta ${falta?.numero}.`);
  return normalizadas;
}

async function responder(idEncuesta, idCuenta, respuestas) {
  try {
    return await transaccion(idCuenta || 'anonimo', async (conn) => {
      const [rows] = await conn.execute(`SELECT id_encuesta FROM encuesta WHERE id_encuesta = ? AND ${ACTIVA}`, [idEncuesta]);
      if (!rows.length) throw new HttpError(404, 'La encuesta no está disponible.');
      const [preguntas] = await conn.execute(PREGUNTAS, [idEncuesta]);
      if (!preguntas.length) throw new HttpError(409, 'Esta encuesta todavía no tiene preguntas.');
      const normalizadas = validarRespuestas(preguntas, respuestas);
      const [r] = await conn.execute('INSERT INTO respuesta_encuesta (id_encuesta, id_contacto) VALUES (?, ?)', [idEncuesta, idCuenta]);
      for (const n of normalizadas) {
        await conn.execute('INSERT INTO detalle_respuesta_encuesta (id_respuesta, id_pregunta, valor_json) VALUES (?, ?, ?)',
          [r.insertId, n.id_pregunta, JSON.stringify(n.valor)]);
      }
      return { id_respuesta: r.insertId, guardado: true };
    });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') throw new HttpError(409, 'Ya respondiste esta encuesta desde este contacto.');
    throw error;
  }
}

module.exports = { listar, detalle, responder, validarRespuestas };

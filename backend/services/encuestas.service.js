// Encuestas (sql/extension_sihaychamba.sql). Lectura desde vw_encuestas_vigentes; escritura con
// sp_registrar_respuesta_encuesta. Una respuesta por contacto y encuesta; las anónimas no tienen límite.
const { pool } = require('../config/db');
const { HttpError, requerir } = require('../utils/validacion');

const PREGUNTAS = 'SELECT id_pregunta, numero, texto, tipo, obligatoria, opciones_json FROM pregunta_encuesta WHERE id_encuesta = ? ORDER BY numero';

const comoOpciones = (v) => {
  if (Array.isArray(v)) return v;
  try { const r = JSON.parse(v); return Array.isArray(r) ? r : []; } catch { return []; }
};

async function listar() {
  const [rows] = await pool.execute(`SELECT id_encuesta, titulo, descripcion, version_encuesta, total_preguntas
    FROM vw_encuestas_vigentes ORDER BY titulo`);
  return rows;
}

async function vigenteConPreguntas(id) {
  const [rows] = await pool.execute(`SELECT id_encuesta, titulo, descripcion, version_encuesta
    FROM vw_encuestas_vigentes WHERE id_encuesta = ?`, [id]);
  if (!rows.length) throw new HttpError(404, 'La encuesta no está disponible.');
  const [preguntas] = await pool.execute(PREGUNTAS, [id]);
  return { encuesta: rows[0], preguntas };
}

async function detalle(id) {
  const { encuesta, preguntas } = await vigenteConPreguntas(id);
  return { ...encuesta, preguntas: preguntas.map((p) => ({ ...p, obligatoria: Boolean(p.obligatoria), opciones_json: comoOpciones(p.opciones_json) })) };
}

// Valida cada respuesta contra el tipo de su pregunta (ESCALA 1-5, TEXTO, UNICA, MULTIPLE).
// MySQL repite la validación en trg_detalle_validar_bi; aquí se hace primero para dar mensajes claros.
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
  const { preguntas } = await vigenteConPreguntas(idEncuesta);
  if (!preguntas.length) throw new HttpError(409, 'Esta encuesta todavía no tiene preguntas.');
  const normalizadas = validarRespuestas(preguntas, respuestas);
  try {
    const [resultados] = await pool.query('CALL sp_registrar_respuesta_encuesta(?,?,?)',
      [idEncuesta, idCuenta, JSON.stringify(normalizadas)]);
    return { id_respuesta: resultados[0][0].id_respuesta, guardado: true };
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') throw new HttpError(409, 'Ya respondiste esta encuesta desde este contacto.');
    throw error;
  }
}

module.exports = { listar, detalle, responder, validarRespuestas };

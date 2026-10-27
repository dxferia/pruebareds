const crypto = require('node:crypto');
const { pool } = require('../config/db');
const { HttpError } = require('../utils/validacion');

const COLUMNAS = `id_publicacion, titulo, descripcion, ubicacion, disponible_desde, disponible_hasta, cantidad, tipo,
  id_categoria, nombre_categoria, responsable, nombre_metodo_pago, fecha_publicacion`;
// La vista no garantiza orden: la más reciente primero; id_publicacion desempata la misma fecha.
const RECIENTES = 'ORDER BY fecha_publicacion DESC, id_publicacion DESC';

async function categorias() {
  const [rows] = await pool.execute('SELECT id_categoria, nombre_categoria FROM categoria ORDER BY nombre_categoria');
  return rows;
}

// Solo publicaciones vigentes (activa y no vencida), según vw_publicaciones_vigentes. Sin caché.
async function publicaciones(idCategoria) {
  const filtro = idCategoria ? ' WHERE id_categoria = ?' : '';
  const [rows] = await pool.execute(`SELECT ${COLUMNAS} FROM vw_publicaciones_vigentes${filtro} ${RECIENTES}`,
    idCategoria ? [idCategoria] : []);
  return rows;
}

async function publicacion(id) {
  const [rows] = await pool.execute(`SELECT ${COLUMNAS} FROM vw_publicaciones_vigentes WHERE id_publicacion = ?`, [id]);
  return rows[0] || null;
}

// Publicación directa (sp_crear_publicacion): queda visible en el catálogo sin aprobación de la Junta.
// clave = UUID que la app conserva entre reintentos del mismo envío; deriva el id, así que un
// reintento choca con la PK (ER_DUP_ENTRY) y devuelve la publicación ya creada en vez de duplicarla.
async function crear(idCuenta, d, clave) {
  const id = `pub-${clave || crypto.randomUUID()}`;
  try {
    await pool.query('CALL sp_crear_publicacion(?,?,?,?,?,?,?,?,?,?,?)', [id, idCuenta, d.id_categoria, null, d.titulo,
      d.descripcion, d.ubicacion, d.disponible_desde, d.disponible_hasta, d.cantidad, d.tipo]);
  } catch (error) {
    if (error.code !== 'ER_DUP_ENTRY') throw error;
    const [rows] = await pool.execute('SELECT id_responsable FROM publicacion WHERE id_publicacion = ?', [id]);
    if (rows[0]?.id_responsable !== idCuenta) throw new HttpError(409, 'Ya existe un registro con estos datos.');
    const previa = await publicacion(id);
    if (!previa) throw new HttpError(409, 'Esta publicación ya se registró y dejó de estar vigente.');
    return { creada: false, publicacion: previa };
  }
  return { creada: true, publicacion: await publicacion(id) };
}

// Publicaciones de la persona (vigentes, cerradas o vencidas) para "Mis solicitudes".
async function mias(idCuenta) {
  const [rows] = await pool.execute(`SELECT p.id_publicacion, p.titulo, p.descripcion, p.ubicacion, p.disponible_desde,
    p.disponible_hasta, p.cantidad, p.tipo, p.id_categoria, c.nombre_categoria, p.fecha_publicacion,
    (p.activa AND p.disponible_hasta >= CURRENT_DATE) AS vigente
    FROM publicacion p JOIN categoria c ON c.id_categoria = p.id_categoria
    WHERE p.id_responsable = ? ${RECIENTES}`, [idCuenta]);
  return rows;
}

module.exports = { categorias, publicaciones, publicacion, crear, mias };

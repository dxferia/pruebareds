const { pool } = require('../config/db');

const COLUMNAS = `id_publicacion, titulo, descripcion, ubicacion, disponible_desde, disponible_hasta, cantidad, tipo,
  id_categoria, nombre_categoria, responsable, nombre_metodo_pago`;

async function categorias() {
  const [rows] = await pool.execute('SELECT id_categoria, nombre_categoria FROM categoria ORDER BY nombre_categoria');
  return rows;
}

// Solo publicaciones vigentes (activa y no vencida), según vw_publicaciones_vigentes.
async function publicaciones(idCategoria) {
  const filtro = idCategoria ? ' WHERE id_categoria = ?' : '';
  const [rows] = await pool.execute(`SELECT ${COLUMNAS} FROM vw_publicaciones_vigentes${filtro} ORDER BY disponible_hasta, titulo`,
    idCategoria ? [idCategoria] : []);
  return rows;
}

async function publicacion(id) {
  const [rows] = await pool.execute(`SELECT ${COLUMNAS} FROM vw_publicaciones_vigentes WHERE id_publicacion = ?`, [id]);
  return rows[0] || null;
}

module.exports = { categorias, publicaciones, publicacion };

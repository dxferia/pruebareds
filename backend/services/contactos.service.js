// Perfil "Mi contacto": cuenta_acceso + contacto_perfil. Escrituras con sp_crear_contacto / sp_actualizar_contacto.
const crypto = require('node:crypto');
const { pool } = require('../config/db');

const hash = (clave) => crypto.createHash('sha256').update(clave).digest('hex');

async function porClave(clave) {
  const [rows] = await pool.execute(`SELECT c.id_cuenta, c.nombre, c.estado, p.correo, p.telefono, p.medio_preferido
    FROM contacto_perfil p JOIN cuenta_acceso c ON c.id_cuenta = p.id_cuenta
    WHERE p.clave_edicion_hash = ?`, [hash(clave)]);
  return rows[0] || null;
}

// La cuenta nace PENDIENTE para que la Junta la valide en "Accesos veredales".
// La clave de edición solo se devuelve una vez; en MySQL se guarda su SHA-256.
async function crear(datos) {
  const id = `con-${crypto.randomUUID()}`;
  const clave = crypto.randomBytes(32).toString('hex');
  await pool.query('CALL sp_crear_contacto(?,?,?,?,?,?)',
    [id, datos.nombre, datos.correo, datos.telefono, datos.medio_preferido, hash(clave)]);
  return { id_cuenta: id, ...datos, estado: 'PENDIENTE', clave_edicion: clave };
}

async function actualizar(cuenta, datos) {
  await pool.query('CALL sp_actualizar_contacto(?,?,?,?,?)',
    [cuenta.id_cuenta, datos.nombre, datos.correo, datos.telefono, datos.medio_preferido]);
  return { id_cuenta: cuenta.id_cuenta, ...datos, estado: cuenta.estado };
}

module.exports = { porClave, crear, actualizar };

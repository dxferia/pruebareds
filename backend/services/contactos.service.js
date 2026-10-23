// Perfil "Mi contacto": cuenta_acceso (nombre, estado) + contacto_perfil (migración 001).
const crypto = require('node:crypto');
const { pool, transaccion } = require('../config/db');

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
  await transaccion(id, async (conn) => {
    await conn.execute("INSERT INTO cuenta_acceso (id_cuenta, nombre, estado) VALUES (?, ?, 'PENDIENTE')", [id, datos.nombre]);
    await conn.execute(`INSERT INTO contacto_perfil (id_cuenta, correo, telefono, medio_preferido, clave_edicion_hash)
      VALUES (?, ?, ?, ?, ?)`, [id, datos.correo, datos.telefono, datos.medio_preferido, hash(clave)]);
  });
  return { id_cuenta: id, ...datos, estado: 'PENDIENTE', clave_edicion: clave };
}

async function actualizar(cuenta, datos) {
  await transaccion(cuenta.id_cuenta, async (conn) => {
    await conn.execute('UPDATE cuenta_acceso SET nombre = ? WHERE id_cuenta = ?', [datos.nombre, cuenta.id_cuenta]);
    await conn.execute('UPDATE contacto_perfil SET correo = ?, telefono = ?, medio_preferido = ? WHERE id_cuenta = ?',
      [datos.correo, datos.telefono, datos.medio_preferido, cuenta.id_cuenta]);
  });
  return { id_cuenta: cuenta.id_cuenta, ...datos, estado: cuenta.estado };
}

module.exports = { porClave, crear, actualizar };

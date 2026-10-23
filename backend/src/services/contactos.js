const crypto = require('node:crypto');
const {HttpError,requerir,limpio,correoValido,telefonoValido} = require('../utils/errors');
const hash = key => crypto.createHash('sha256').update(key).digest('hex');
function validar(data) {
  const nombre=limpio(data.nombre,150), correo=limpio(data.correo,254).toLowerCase();
  const telefono=limpio(data.telefono,30), medio=limpio(data.medio_preferido,20).toUpperCase();
  requerir(nombre.length>=2 && nombre.length<=150,'Ingresa tu nombre completo.');
  requerir(correoValido(correo),'El correo no es válido.');
  requerir(telefonoValido(telefono),'El teléfono no es válido.');
  requerir(['LLAMADA','WHATSAPP','CORREO'].includes(medio),'El medio de contacto no es válido.');
  return {nombre,correo,telefono,medio_preferido:medio};
}
function extraerClave(req){
  const clave=req.get('X-Contact-Key');
  if (!clave || !/^[a-f0-9]{64}$/.test(clave)) throw new HttpError(403,'Registra Mi contacto en este dispositivo para continuar.');
  return clave;
}
async function perfilPorClave(db,clave) {
  const [rows]=await db.execute(`SELECT c.id_cuenta,c.nombre,p.correo,p.telefono,p.medio_preferido
    FROM contacto_perfil p JOIN cuenta_acceso c ON c.id_cuenta=p.id_cuenta
    WHERE p.clave_edicion_hash=?`,[hash(clave)]);
  if (!rows.length) throw new HttpError(403,'No se reconoce el contacto de este dispositivo.');
  return rows[0];
}
async function crearPerfil(db,data) {
  const v=validar(data);
  const id=`con-${crypto.randomUUID()}`,clave=crypto.randomBytes(32).toString('hex');
  const conn=await db.getConnection();
  try {
    await conn.beginTransaction();
    await conn.execute('INSERT INTO cuenta_acceso (id_cuenta,nombre,estado) VALUES (?,?,?)',[id,v.nombre,'PENDIENTE']);
    await conn.execute('INSERT INTO contacto_perfil (id_cuenta,correo,telefono,medio_preferido,clave_edicion_hash) VALUES (?,?,?,?,?)',[id,v.correo,v.telefono,v.medio_preferido,hash(clave)]);
    await conn.commit();
    return {id_cuenta:id,...v,clave_edicion:clave};
  } catch(e){await conn.rollback();throw e;} finally {conn.release();}
}
async function actualizarPerfil(db,clave,data){
  const v=validar(data);
  const actual=await perfilPorClave(db,clave);
  const conn=await db.getConnection();
  try {
    await conn.beginTransaction();
    await conn.execute('UPDATE cuenta_acceso SET nombre=? WHERE id_cuenta=?',[v.nombre,actual.id_cuenta]);
    await conn.execute('UPDATE contacto_perfil SET correo=?,telefono=?,medio_preferido=? WHERE id_cuenta=?',[v.correo,v.telefono,v.medio_preferido,actual.id_cuenta]);
    await conn.commit();
    return {id_cuenta:actual.id_cuenta,...v};
  } catch(e){await conn.rollback();throw e;} finally {conn.release();}
}
module.exports={validar,extraerClave,perfilPorClave,crearPerfil,actualizarPerfil};

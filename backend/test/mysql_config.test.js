const test=require('node:test');
const assert=require('node:assert/strict');
const {sugerencia}=require('../scripts/verificar_mysql');
const {crearPool}=require('../src/config/database');

test('Mensajes seguros de configuración para problemas de conexión',()=>{
  assert.match(sugerencia('ER_ACCESS_DENIED_ERROR'),/contraseña local/);
  assert.match(sugerencia('ER_BAD_DB_ERROR'),new RegExp(process.env.DB_NAME||'travesias_conecta'));
  assert.match(sugerencia('ETIMEDOUT'),/firewall/);
});
test('La conexión está centralizada en crearPool',()=>{
  assert.equal(typeof crearPool,'function');
});

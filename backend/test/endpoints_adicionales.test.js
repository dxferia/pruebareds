const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const adminDb=require('../src/config/admin_database');
const clave='b'.repeat(64);
const hash=crypto.createHash('sha256').update(clave).digest('hex');
let estado='PENDIENTE';
let ultimoUpdate=null;
const adminFake={
  execute:async(sql,params=[])=>{
    if(sql.includes('FROM vw_solicitudes_publicacion WHERE'))return [[{id_solicitud:params[0],estado:'PENDIENTE'}]];
    if(sql.includes('FROM vw_solicitudes_contacto WHERE'))return [[{id_solicitud_contacto:params[0],estado}]];
    if(sql.includes('FROM vw_solicitudes_contacto ORDER BY'))return [[{id_solicitud_contacto:'sc-1',estado}]];
    if(sql.startsWith('UPDATE solicitud_contacto')){
      ultimoUpdate={sql,params};
      if(estado!=='PENDIENTE')return [{affectedRows:0}];
      estado=params[0];return [{affectedRows:1}];
    }
    if(sql.includes('FROM solicitud_contacto WHERE'))return [[{estado}]];
    if(sql.includes('FROM publicacion WHERE'))return [[{id_publicacion:params[0],tipo:'LABOR'}]];
    if(sql.includes('FROM publicacion p JOIN'))return [[{id_publicacion:'pub-1',tipo:'SERVICIO'}]];
    if(sql.includes('FROM metodo_pago'))return [[]];
    throw Error('SQL inesperada en prueba admin: '+sql);
  }
};
adminDb.crearPoolAdmin=()=>adminFake;
const {crearApp}=require('../src/app');
const db={
  execute:async(sql,params=[])=>{
    if(sql.includes('FROM categoria WHERE'))return [[{id_categoria:params[0],nombre_categoria:'Carpintería'}]];
    if(sql.includes('FROM vw_publicaciones_vigentes WHERE'))return [[{id_publicacion:params[0],titulo:'Trabajo local'}]];
    if(sql.includes('FROM contacto_perfil p JOIN'))return params[0]===hash?[[{id_cuenta:'con-1',nombre:'Ana',telefono:'3000000000'}]]:[[]];
    if(sql.includes('FROM vw_solicitudes_publicacion WHERE'))return [[{id_solicitud:params[0],estado:'PENDIENTE'}]];
    if(sql.includes('FROM vw_solicitudes_contacto WHERE'))return [[{id_solicitud_contacto:params[0],estado:'PENDIENTE'}]];
    throw Error('SQL inesperada en prueba pública: '+sql);
  }
};
test('Rutas adicionales usan consultas parametrizadas, autorización y estados',async()=>{
  const anterior=process.env.ADMIN_API_KEY;
  process.env.ADMIN_API_KEY='k'.repeat(40);
  estado='PENDIENTE';ultimoUpdate=null;
  const server=crearApp(db).listen(0,'127.0.0.1');
  await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api`;
  const headers={};
  const solicitar=(path,op={})=>fetch(base+path,{...op,headers:{...headers,...(op.headers||{})}});
  try{
    let r=await fetch(base+'/categorias/1');assert.equal(r.status,200);
    r=await solicitar('/categorias/abc');assert.equal(r.status,422);
    r=await solicitar('/categorias/1');assert.equal(r.status,200);assert.equal((await r.json()).nombre_categoria,'Carpintería');
    r=await solicitar('/publicaciones/pub-1');assert.equal(r.status,200);assert.equal((await r.json()).id_publicacion,'pub-1');
    r=await solicitar('/solicitudes-publicacion/sol-1');assert.equal(r.status,403);
    r=await solicitar('/solicitudes-publicacion/sol-1',{headers:{'X-Contact-Key':clave}});
    assert.equal(r.status,200);assert.equal((await r.json()).id_solicitud,'sol-1');
    r=await solicitar('/solicitudes-contacto/sc-1',{headers:{'X-Contact-Key':clave}});
    assert.equal(r.status,200);
    r=await solicitar('/admin/publicaciones');assert.equal(r.status,403);
    r=await solicitar('/admin/publicaciones',{headers:{'X-Admin-Key':'k'.repeat(40)}});
    assert.equal(r.status,200);assert.equal((await r.json())[0].tipo,'SERVICIO');
    r=await solicitar('/admin/publicaciones/pub-1',{headers:{'X-Admin-Key':'k'.repeat(40)}});
    assert.equal(r.status,200);
    r=await solicitar('/admin/solicitudes-publicacion/sol-1',{headers:{'X-Admin-Key':'k'.repeat(40)}});
    assert.equal(r.status,200);
    r=await solicitar('/admin/solicitudes-contacto',{headers:{'X-Admin-Key':'k'.repeat(40)}});
    assert.equal(r.status,200);
    r=await solicitar('/admin/solicitudes-contacto/sc-1',{headers:{'X-Admin-Key':'k'.repeat(40)}});
    assert.equal(r.status,200);
    r=await solicitar('/admin/metodos-pago',{headers:{'X-Admin-Key':'k'.repeat(40)}});
    assert.equal(r.status,200);
    r=await solicitar('/admin/solicitudes-contacto/sc-1',{method:'PATCH',headers:{'X-Admin-Key':'k'.repeat(40),'Content-Type':'application/json'},body:JSON.stringify({estado:'PENDIENTE'})});
    assert.equal(r.status,422);
    r=await solicitar('/admin/solicitudes-contacto/sc-1',{method:'PATCH',headers:{'X-Admin-Key':'k'.repeat(40),'Content-Type':'application/json'},body:JSON.stringify({estado:'APROBADA'})});
    assert.equal(r.status,200);assert.equal((await r.json()).estado,'APROBADA');
    assert.deepEqual(ultimoUpdate.params,['APROBADA','sc-1']);
    r=await solicitar('/admin/solicitudes-contacto/sc-1',{method:'PATCH',headers:{'X-Admin-Key':'k'.repeat(40),'Content-Type':'application/json'},body:JSON.stringify({estado:'RECHAZADA'})});
    assert.equal(r.status,409);
  }finally{
    await new Promise(resolve=>server.close(resolve));
    if(anterior===undefined)delete process.env.ADMIN_API_KEY;else process.env.ADMIN_API_KEY=anterior;
  }
});

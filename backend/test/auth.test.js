const test=require('node:test');
const assert=require('node:assert/strict');
const {crearApp}=require('../src/app');

test('La API permite consultar contenido público sin credenciales ni Servicio A',async()=>{
  const db={execute:async(sql)=>{
    if(sql.includes('FROM categoria'))return [[{id_categoria:1,nombre_categoria:'Carpintería'}]];
    if(sql.includes('FROM vw_publicaciones_vigentes'))return [[]];
    if(sql.includes('FROM encuesta WHERE'))return [[]];
    throw Error('Consulta de prueba inesperada: '+sql);
  }};
  const server=crearApp(db).listen(0,'127.0.0.1');
  await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api`;
  try {
    let res=await fetch(base+'/health');assert.equal(res.status,200);
    res=await fetch(base+'/categorias');assert.equal(res.status,200);
    assert.equal((await res.json())[0].nombre_categoria,'Carpintería');
    res=await fetch(base+'/publicaciones');assert.equal(res.status,200);
    res=await fetch(base+'/encuestas');assert.equal(res.status,200);
    res=await fetch(base+'/auth/session');assert.equal(res.status,404);
  } finally {await new Promise(resolve=>server.close(resolve));}
});

test('La Junta sigue protegida aunque se quite el login',async()=>{
  const previous=process.env.ADMIN_API_KEY;
  process.env.ADMIN_API_KEY='A'.repeat(40);
  const server=crearApp({}).listen(0,'127.0.0.1');
  await new Promise(resolve=>server.once('listening',resolve));
  const base=`http://127.0.0.1:${server.address().port}/api/admin/cuentas`;
  try {
    let res=await fetch(base);assert.equal(res.status,403);
    res=await fetch(base,{headers:{'X-Admin-Key':'incorrecta'}});
    assert.equal(res.status,403);
  } finally {
    await new Promise(resolve=>server.close(resolve));
    if(previous===undefined)delete process.env.ADMIN_API_KEY;
    else process.env.ADMIN_API_KEY=previous;
  }
});

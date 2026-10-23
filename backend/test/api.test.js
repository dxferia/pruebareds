const test=require('node:test');
const assert=require('node:assert/strict');
const {crearApp}=require('../src/app');
const {validar}=require('../src/services/contactos');
const {validarRespuestas}=require('../src/services/encuestas');

test('Se validan correo, teléfono y nombre antes de guardar',()=>{
  assert.equal(validar({nombre:'Ana Pérez',correo:'ANA@CORREO.COM',telefono:'+57 300 123 4567',medio_preferido:'WHATSAPP'}).correo,'ana@correo.com');
  assert.throws(()=>validar({nombre:'',correo:'a@b.c',telefono:'1',medio_preferido:'CORREO'}),/nombre/);
});
test('Las preguntas escala requieren valores de 1 a 5 y se comprueban obligatoriedad y duplicados',()=>{
  const preguntas=[{id_pregunta:11,numero:1,tipo:'ESCALA',obligatoria:1,opciones_json:null}];
  assert.deepEqual(validarRespuestas(preguntas,[{id_pregunta:11,valor:4}]),[{id_pregunta:11,valor:4}]);
  assert.throws(()=>validarRespuestas(preguntas,[]),/Falta responder/);
  assert.throws(()=>validarRespuestas(preguntas,[{id_pregunta:11,valor:6}]),/1 a 5/);
});
test('Preguntas única, múltiple y texto respetan opciones válidas',()=>{
  const p=[{id_pregunta:1,numero:1,tipo:'UNICA',obligatoria:1,opciones_json:['A','B']},
    {id_pregunta:2,numero:2,tipo:'MULTIPLE',obligatoria:1,opciones_json:['X','Y']},
    {id_pregunta:3,numero:3,tipo:'TEXTO',obligatoria:1,opciones_json:null}];
  assert.equal(validarRespuestas(p,[{id_pregunta:1,valor:'A'},{id_pregunta:2,valor:['X']},{id_pregunta:3,valor:'sí'}]).length,3);
  assert.throws(()=>validarRespuestas(p,[{id_pregunta:1,valor:'C'}]),/opción válida/);
});

test('La API pública sin login valida categorías, encuestas y respuestas',async()=>{
  const db={
    execute:async(sql,params=[])=>{
      if(sql.includes('FROM categoria'))return [[{id_categoria:1,nombre_categoria:'Carpintería'}]];
      if(sql.includes('FROM vw_publicaciones_vigentes'))return [[]];
      if(sql.includes('FROM encuesta WHERE'))return [[{id_encuesta:'travesias-usabilidad-v1',titulo:'Encuesta de usabilidad',descripcion:'Prueba',version_encuesta:1}]];
      if(sql.includes('FROM pregunta_encuesta'))return [[{id_pregunta:1,numero:1,tipo:'ESCALA',texto:'Pregunta',obligatoria:1,opciones_json:null}]];
      throw new Error(`Consulta imprevista: ${sql}`);
    },
    getConnection:async()=>({
      beginTransaction:async()=>{},commit:async()=>{},rollback:async()=>{},release:()=>{},
      execute:async(sql,params=[])=>{
        if(sql.includes('FROM encuesta WHERE'))return [[{id_encuesta:'travesias-usabilidad-v1'}]];
        if(sql.includes('FROM pregunta_encuesta'))return [[{id_pregunta:1,numero:1,tipo:'ESCALA',obligatoria:1,opciones_json:null}]];
        if(sql.startsWith('INSERT INTO respuesta_encuesta'))return [{insertId:23}];
        if(sql.startsWith('INSERT INTO detalle_respuesta_encuesta'))return [{affectedRows:1}];
        throw new Error('Consulta inesperada: '+sql);
      }
    })
  };
  const server=crearApp(db).listen(0,'127.0.0.1');
  await new Promise(r=>server.once('listening',r));
  const base=`http://127.0.0.1:${server.address().port}`;
  const apiFetch=(url,opts={})=>fetch(url,opts);
  try{
    let r=await apiFetch(base+'/api/health');assert.equal(r.status,200);assert.equal((await r.json()).estado,'ok');
    r=await fetch(base+'/api/auth/session');assert.equal(r.status,404);
    r=await apiFetch(base+'/api/categorias');assert.equal((await r.json())[0].nombre_categoria,'Carpintería');
    r=await apiFetch(base+'/api/publicaciones');assert.deepEqual(await r.json(),[]);
    r=await apiFetch(base+'/api/encuestas');assert.equal((await r.json())[0].titulo,'Encuesta de usabilidad');
    r=await apiFetch(base+'/api/encuestas/travesias-usabilidad-v1');assert.equal((await r.json()).preguntas.length,1);
    r=await apiFetch(base+'/api/encuestas/travesias-usabilidad-v1/respuestas',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({respuestas:[]})});assert.equal(r.status,422);
    r=await apiFetch(base+'/api/encuestas/travesias-usabilidad-v1/respuestas',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({respuestas:[{id_pregunta:1,valor:5}]})});
    assert.equal(r.status,201);assert.equal((await r.json()).guardado,true);
    r=await apiFetch(base+'/api/admin/cuentas');assert.equal(r.status,503);
  }finally{await new Promise(resolve=>server.close(resolve));}
});

test('Contacto local sin contraseña y solicitudes por procedimientos almacenados',async()=>{
  let id=null,nombre=null,correo=null,telefono=null,medio=null,hashGuardado=null;
  const llamadas=[];
  const conexion={
    beginTransaction:async()=>{},commit:async()=>{},rollback:async()=>{},release:()=>{},
    execute:async(sql,args)=>{
      llamadas.push(sql);
      if(sql.startsWith('INSERT INTO cuenta_acceso')){[id,nombre]=args;return [{affectedRows:1}];}
      if(sql.startsWith('INSERT INTO contacto_perfil')){[,correo,telefono,medio,hashGuardado]=args;return [{affectedRows:1}];}
      if(sql.startsWith('UPDATE cuenta_acceso')){nombre=args[0];return [{affectedRows:1}];}
      if(sql.startsWith('UPDATE contacto_perfil')){[correo,telefono,medio]=args;return [{affectedRows:1}];}
      return [[]];
    }
  };
  const db={
    getConnection:async()=>conexion,
    execute:async(sql,args)=>{
      if(sql.includes('FROM contacto_perfil')) return hashGuardado===args[0]?[[{id_cuenta:id,nombre,correo,telefono,medio_preferido:medio}]]:[[]];
      if(sql.includes('FROM vw_solicitudes_publicacion'))return [[]];
      if(sql.includes('FROM vw_solicitudes_contacto'))return [[]];
      throw Error('SQL inesperada: '+sql);
    },
    query:async(sql,args)=>{llamadas.push(sql);return [[]];}
  };
  const server=crearApp(db).listen(0,'127.0.0.1');
  await new Promise(r=>server.once('listening',r));
  const base=`http://127.0.0.1:${server.address().port}/api`;
  const headers={'Content-Type':'application/json'};
  const d={nombre:'Ana Pérez',correo:'ana@example.com',telefono:'3001234567',medio_preferido:'WHATSAPP'};
  try {
    let r=await fetch(base+'/contactos/mi',{headers});assert.equal(r.status,403);
    r=await fetch(base+'/contactos',{method:'POST',headers,body:JSON.stringify({...d,nombre:''})});assert.equal(r.status,422);
    r=await fetch(base+'/contactos',{method:'POST',headers,body:JSON.stringify(d)});
    assert.equal(r.status,201);const guardado=await r.json();assert.match(guardado.clave_edicion,/^[a-f0-9]{64}$/);
    assert.ok(id.startsWith('con-'));assert.equal(hashGuardado.length,64);assert.notEqual(hashGuardado,guardado.clave_edicion);
    const autenticado={...headers,'X-Contact-Key':guardado.clave_edicion};
    r=await fetch(base+'/contactos/mi',{headers:autenticado});assert.equal(r.status,200);assert.equal((await r.json()).nombre,'Ana Pérez');
    r=await fetch(base+'/contactos/mi',{method:'PUT',headers:autenticado,body:JSON.stringify({...d,nombre:'Ana María Pérez'})});
    assert.equal(r.status,200);assert.equal((await r.json()).nombre,'Ana María Pérez');
    r=await fetch(base+'/solicitudes-publicacion',{method:'POST',headers:autenticado,body:JSON.stringify({
      id_categoria:1,titulo:'Carpintería local',descripcion:'Reparar muebles de madera con materiales propios',
      ubicacion:'Florencia, Caquetá',disponible_desde:'2026-10-20',disponible_hasta:'2026-10-31',contacto_autorizado:'WhatsApp'
    })});assert.equal(r.status,201);assert.equal((await r.json()).estado,'PENDIENTE');
    assert.ok(llamadas.some(x=>x.includes('CALL sp_crear_solicitud_publicacion')));
    r=await fetch(base+'/solicitudes-contacto',{method:'POST',headers:autenticado,body:JSON.stringify({id_publicacion:'pub-1',motivo:'Me interesa conocer las condiciones del trabajo'})});
    assert.equal(r.status,201);assert.ok(llamadas.some(x=>x.includes('CALL sp_crear_solicitud_contacto')));
    r=await fetch(base+'/solicitudes-contacto/mias',{headers:autenticado});assert.equal(r.status,200);
  }finally{await new Promise(resolve=>server.close(resolve));}
});

const {asyncRoute,HttpError,idValido,requerir}=require('../utils/errors');
const {validarRespuestas,comoOpciones}=require('../services/encuestas');
const {perfilPorClave}=require('../services/contactos');
const sqlActiva=`estado='ACTIVA' AND (disponible_desde IS NULL OR disponible_desde<=NOW()) AND (disponible_hasta IS NULL OR disponible_hasta>=NOW())`;
module.exports = db => ({
  listar:asyncRoute(async(req,res)=>{
    const [rows]=await db.execute(`SELECT id_encuesta,titulo,descripcion,version_encuesta FROM encuesta WHERE ${sqlActiva} ORDER BY titulo`);res.json(rows);
  }),
  detalle:asyncRoute(async(req,res)=>{
    const {id}=req.params;requerir(idValido(id),'Encuesta inválida.');
    const [rows]=await db.execute(`SELECT id_encuesta,titulo,descripcion,version_encuesta FROM encuesta WHERE id_encuesta=? AND ${sqlActiva}`,[id]);
    if(!rows.length) throw new HttpError(404,'La encuesta no está disponible.');
    const [preguntas]=await db.execute('SELECT id_pregunta,numero,texto,tipo,obligatoria,opciones_json FROM pregunta_encuesta WHERE id_encuesta=? ORDER BY numero',[id]);
    res.json({...rows[0],preguntas:preguntas.map(p=>({...p,obligatoria:Boolean(p.obligatoria),opciones_json:comoOpciones(p.opciones_json)}))});
  }),
  responder:asyncRoute(async(req,res)=>{
    const {id}=req.params;requerir(idValido(id),'Encuesta inválida.');
    const conn=await db.getConnection();
    try {
      await conn.beginTransaction();
      const [rows]=await conn.execute(`SELECT id_encuesta FROM encuesta WHERE id_encuesta=? AND ${sqlActiva} FOR UPDATE`,[id]);
      if(!rows.length) throw new HttpError(404,'La encuesta no está disponible.');
      const [preguntas]=await conn.execute('SELECT id_pregunta,numero,tipo,obligatoria,opciones_json FROM pregunta_encuesta WHERE id_encuesta=? ORDER BY numero',[id]);
      if(!preguntas.length) throw new HttpError(422,'Esta encuesta todavía no tiene preguntas.');
      const normalizadas=validarRespuestas(preguntas,req.body?.respuestas);
      let idContacto=null;
      const clave=req.get('X-Contact-Key');
      if(clave){
        requerir(/^[a-f0-9]{64}$/.test(clave),'Identificador de contacto inválido.');
        const perfil=await perfilPorClave(conn,clave);idContacto=perfil.id_cuenta;
      }
      const [result]=await conn.execute('INSERT INTO respuesta_encuesta (id_encuesta,id_contacto) VALUES (?,?)',[id,idContacto]);
      for(const r of normalizadas) await conn.execute('INSERT INTO detalle_respuesta_encuesta (id_respuesta,id_pregunta,valor_json) VALUES (?,?,?)',[result.insertId,r.id_pregunta,JSON.stringify(r.valor)]);
      await conn.commit();res.status(201).json({id_respuesta:result.insertId,guardado:true});
    }catch(error){await conn.rollback();throw error;}finally{conn.release();}
  })
});

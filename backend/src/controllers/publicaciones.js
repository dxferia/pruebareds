const crypto = require('node:crypto');
const {asyncRoute,requerir,limpio,idValido,fechaValida,HttpError}=require('../utils/errors');
const {extraerClave,perfilPorClave}=require('../services/contactos');
module.exports = db => ({
 categorias:asyncRoute(async(req,res)=>{const [r]=await db.execute('SELECT id_categoria,nombre_categoria FROM categoria ORDER BY nombre_categoria');res.json(r);}),
 categoriaDetalle:asyncRoute(async(req,res)=>{
   const n=Number(req.params.id);
   requerir(Number.isSafeInteger(n)&&n>0&&n<=4294967295,'Categoría inválida.');
   const [rows]=await db.execute('SELECT id_categoria,nombre_categoria FROM categoria WHERE id_categoria=?',[n]);
   if(!rows.length)throw new HttpError(404,'La categoría no existe.');
   res.json(rows[0]);
 }),
 publicacionDetalle:asyncRoute(async(req,res)=>{
   requerir(idValido(req.params.id),'Publicación inválida.');
   const [rows]=await db.execute(`SELECT id_publicacion,titulo,descripcion,ubicacion,disponible_desde,disponible_hasta,cantidad,tipo,id_categoria,nombre_categoria,responsable,nombre_metodo_pago
     FROM vw_publicaciones_vigentes WHERE id_publicacion=?`,[req.params.id]);
   if(!rows.length)throw new HttpError(404,'La publicación no está disponible.');
   res.json(rows[0]);
 }),
 miSolicitudDetalle:asyncRoute(async(req,res)=>{
   requerir(idValido(req.params.id),'Solicitud inválida.');
   const persona=await perfilPorClave(db,extraerClave(req));
   const [rows]=await db.execute(`SELECT id_solicitud,titulo,descripcion,cantidad,ubicacion,disponible_desde,disponible_hasta,
     contacto_autorizado,fecha_solicitud,estado,motivo_rechazo,nombre_categoria
     FROM vw_solicitudes_publicacion WHERE id_solicitud=? AND id_solicitante=?`,[req.params.id,persona.id_cuenta]);
   if(!rows.length)throw new HttpError(404,'La solicitud no existe o no te pertenece.');
   res.json(rows[0]);
 }),
 miContactoDetalle:asyncRoute(async(req,res)=>{
   requerir(idValido(req.params.id),'Solicitud de contacto inválida.');
   const persona=await perfilPorClave(db,extraerClave(req));
   const [rows]=await db.execute(`SELECT id_solicitud_contacto,id_publicacion,publicacion,motivo,telefono_autorizado,fecha_solicitud,estado
     FROM vw_solicitudes_contacto WHERE id_solicitud_contacto=? AND id_remitente=?`,[req.params.id,persona.id_cuenta]);
   if(!rows.length)throw new HttpError(404,'La solicitud no existe o no te pertenece.');
   res.json(rows[0]);
 }),
 publicaciones:asyncRoute(async(req,res)=>{
   const categoria=req.query.categoria;
   if(categoria!==undefined) requerir(/^\d+$/.test(String(categoria)),'Categoría inválida');
   const sql='SELECT id_publicacion,titulo,descripcion,ubicacion,disponible_desde,disponible_hasta,cantidad,tipo,id_categoria,nombre_categoria,responsable,nombre_metodo_pago FROM vw_publicaciones_vigentes';
   const [r]=await db.execute(sql+(categoria?' WHERE id_categoria=?':'')+' ORDER BY disponible_hasta,titulo',categoria?[Number(categoria)]:[]);res.json(r);
 }),
 crearSolicitud:asyncRoute(async(req,res)=>{
   const persona=await perfilPorClave(db,extraerClave(req));const d=req.body||{};
   requerir(Number.isInteger(d.id_categoria) && d.id_categoria>0,'Selecciona una categoría.');
   const titulo=limpio(d.titulo,255),descripcion=limpio(d.descripcion,10000),ubicacion=limpio(d.ubicacion,255);
   const desde=d.disponible_desde,hasta=d.disponible_hasta,contacto=limpio(d.contacto_autorizado,255);
   requerir(titulo.length>=5&&titulo.length<=255,'El título debe tener al menos cinco caracteres.');
   requerir(descripcion.length>=10&&descripcion.length<=10000,'Agrega una descripción más detallada.');
   requerir(ubicacion.length>=3&&ubicacion.length<=255,'Ingresa la ubicación.');
   requerir(fechaValida(desde)&&fechaValida(hasta)&&hasta>=desde,'El rango de fechas no es válido.');
   requerir(contacto.length>0&&contacto.length<=255,'Indica cómo pueden contactarte.');
   const id=`sol-${crypto.randomUUID()}`;
   await db.query('CALL sp_crear_solicitud_publicacion(?,?,?,?,?,?,?,?,?,?)',[id,persona.id_cuenta,d.id_categoria,titulo,descripcion,limpio(d.cantidad,100)||null,ubicacion,desde,hasta,contacto]);
   res.status(201).json({id_solicitud:id,estado:'PENDIENTE'});
 }),
 misSolicitudes:asyncRoute(async(req,res)=>{
   const persona=await perfilPorClave(db,extraerClave(req));
   const [rows]=await db.execute('SELECT id_solicitud,titulo,descripcion,ubicacion,disponible_desde,disponible_hasta,fecha_solicitud,cantidad,estado,motivo_rechazo,nombre_categoria FROM vw_solicitudes_publicacion WHERE id_solicitante=? ORDER BY fecha_solicitud DESC',[persona.id_cuenta]);
   res.json(rows);
 }),
 crearContacto:asyncRoute(async(req,res)=>{
   const persona=await perfilPorClave(db,extraerClave(req)),d=req.body||{};
   requerir(idValido(d.id_publicacion),'Publicación no válida.');
   const motivo=limpio(d.motivo,2000),telefono=limpio(d.telefono_autorizado||persona.telefono,30);
   requerir(motivo.length>=5&&motivo.length<=2000,'Explica brevemente el motivo del contacto.');
   requerir(telefono.length>=7&&telefono.length<=30,'Ingresa un teléfono válido.');
   const id=`sc-${crypto.randomUUID()}`;
   await db.query('CALL sp_crear_solicitud_contacto(?,?,?,?,?)',[id,d.id_publicacion,persona.id_cuenta,motivo,telefono]);
   res.status(201).json({id_solicitud_contacto:id,estado:'PENDIENTE'});
 }),
 misContactos:asyncRoute(async(req,res)=>{
   const persona=await perfilPorClave(db,extraerClave(req));
   const [rows]=await db.execute(`SELECT id_solicitud_contacto,id_publicacion,publicacion,motivo,telefono_autorizado,fecha_solicitud,estado
     FROM vw_solicitudes_contacto WHERE id_remitente=? ORDER BY fecha_solicitud DESC`,[persona.id_cuenta]);res.json(rows);
 })
});

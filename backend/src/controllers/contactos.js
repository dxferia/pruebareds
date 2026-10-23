const {asyncRoute}=require('../utils/errors');
const {crearPerfil,perfilPorClave,extraerClave,actualizarPerfil}=require('../services/contactos');
module.exports = db => ({
  crear:asyncRoute(async(req,res)=>res.status(201).json(await crearPerfil(db,req.body||{}))),
  mi:asyncRoute(async(req,res)=>res.json(await perfilPorClave(db,extraerClave(req)))),
  actualizar:asyncRoute(async(req,res)=>res.json(await actualizarPerfil(db,extraerClave(req),req.body||{}))),
});

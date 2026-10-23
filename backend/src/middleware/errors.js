const {HttpError} = require('../utils/errors');
function noEncontrado(req,res){res.status(404).json({error:'Ruta no encontrada'});}
function manejarErrores(error,req,res,next){
  if (res.headersSent) return next(error);
  if (error instanceof HttpError) return res.status(error.status).json({error:error.message});
  if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({error:'Ya existe un registro para estos datos.'});
  if (error.code === 'ER_NO_REFERENCED_ROW_2') return res.status(422).json({error:'La referencia indicada no existe.'});
  if (error.sqlState === '45000') return res.status(422).json({error:'La operación no cumple las reglas de la base de datos.'});
  console.error('Error de API:',error.code || error.name || 'UNKNOWN');
  res.status(500).json({error:'No fue posible completar la operación.'});
}
module.exports={noEncontrado,manejarErrores};

const crypto=require('node:crypto');
const {HttpError}=require('../utils/errors');
function adminSeguro(req,res,next){
  const esperado=process.env.ADMIN_API_KEY||'';
  if(esperado.length<32) return next(new HttpError(503,'La administración no está configurada.'));
  const actual=req.get('X-Admin-Key')||'';
  const a=Buffer.from(esperado), b=Buffer.from(actual);
  if(a.length!==b.length||!crypto.timingSafeEqual(a,b))return next(new HttpError(403,'Acceso administrativo denegado.'));
  next();
}
module.exports={adminSeguro};

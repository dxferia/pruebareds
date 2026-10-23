class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
const asyncRoute = fn => (req,res,next) => Promise.resolve().then(() => fn(req,res,next)).catch(next);
const requerir = (test, mensaje='Datos inválidos') => {
  if (!test) throw new HttpError(422, mensaje);
};
const limpio = (v,max) => typeof v === 'string' ? v.trim().slice(0,max+1) : '';
const correoValido = v => typeof v === 'string' && v.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
const telefonoValido = v => typeof v === 'string' && /^\+?[0-9()\s-]{7,30}$/.test(v);
const idValido = v => typeof v === 'string' && /^[a-zA-Z0-9_-]{1,64}$/.test(v);
const fechaValida = s => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s)) && new Date(`${s}T00:00:00Z`).toISOString().startsWith(s);
module.exports = {HttpError,asyncRoute,requerir,limpio,correoValido,telefonoValido,idValido,fechaValida};

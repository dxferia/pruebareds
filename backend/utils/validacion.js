class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const requerir = (condicion, mensaje = 'Datos inválidos.') => {
  if (!condicion) throw new HttpError(400, mensaje);
};

// Texto recortado entre min y max caracteres; min = 0 lo hace opcional (devuelve null si viene vacío).
function texto(valor, max, mensaje, min = 1) {
  const s = typeof valor === 'string' || typeof valor === 'number' ? String(valor).trim() : '';
  requerir(s.length >= min && s.length <= max, mensaje);
  return s || null;
}

const idValido = (v) => typeof v === 'string' && /^[a-zA-Z0-9_-]{1,64}$/.test(v);
const correoValido = (v) => typeof v === 'string' && v.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);
const telefonoValido = (v) => typeof v === 'string' && /^\+?[0-9()\s-]{7,30}$/.test(v);
const fechaValida = (s) => typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s)
  && !Number.isNaN(Date.parse(s)) && new Date(`${s}T00:00:00Z`).toISOString().startsWith(s);
const enteroPositivo = (v) => Number.isSafeInteger(v) && v > 0 && v <= 4294967295;

function id(valor, mensaje = 'Identificador inválido.') {
  requerir(idValido(valor), mensaje);
  return valor;
}

function rangoFechas(desde, hasta) {
  requerir(fechaValida(desde) && fechaValida(hasta) && hasta >= desde, 'El rango de fechas no es válido.');
}

module.exports = { HttpError, requerir, texto, id, idValido, correoValido, telefonoValido, fechaValida, enteroPositivo, rangoFechas };

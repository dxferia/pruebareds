const {HttpError,requerir}=require('../utils/errors');
const comoOpciones = value => {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {try {const r=JSON.parse(value);return Array.isArray(r)?r:[];} catch{return [];}}
  return [];
};
function validarRespuestas(preguntas,respuestas){
  requerir(Array.isArray(respuestas),'Las respuestas deben enviarse como una lista.');
  requerir(respuestas.length<=preguntas.length,'Se enviaron más respuestas que preguntas.');
  const mapa=new Map(preguntas.map(p=>[Number(p.id_pregunta),p]));
  const vistas=new Set();const normalizadas=[];
  for(const item of respuestas){
    const id=item?.id_pregunta;
    requerir(Number.isInteger(id)&&mapa.has(id),'La pregunta indicada no pertenece a la encuesta.');
    requerir(!vistas.has(id),'Hay una pregunta repetida.');vistas.add(id);
    const p=mapa.get(id);const v=item.valor;const opciones=comoOpciones(p.opciones_json);
    if(p.tipo==='ESCALA') requerir(Number.isInteger(v)&&v>=1&&v<=5,'Selecciona un valor de 1 a 5.');
    else if(p.tipo==='TEXTO') requerir(typeof v==='string'&&v.trim().length>0&&v.trim().length<=2000,'La respuesta de texto no es válida.');
    else if(p.tipo==='UNICA') requerir(typeof v==='string'&&opciones.includes(v),'Selecciona una opción válida.');
    else if(p.tipo==='MULTIPLE') requerir(Array.isArray(v)&&v.length>0&&v.length<=opciones.length&&new Set(v).size===v.length&&v.every(x=>typeof x==='string'&&opciones.includes(x)),'Selecciona opciones válidas.');
    else throw new HttpError(500,'Tipo de pregunta no soportado.');
    normalizadas.push({id_pregunta:id,valor:typeof v==='string'?v.trim():v});
  }
  for(const p of preguntas) if(Boolean(p.obligatoria)&&!vistas.has(Number(p.id_pregunta))) throw new HttpError(422,`Falta responder la pregunta ${p.numero}.`);
  return normalizadas;
}
module.exports={validarRespuestas,comoOpciones};

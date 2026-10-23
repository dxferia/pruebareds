class Encuesta {
  final String id,titulo,descripcion;
  final int version;
  final List<Pregunta> preguntas;
  const Encuesta({required this.id,required this.titulo,required this.descripcion,
    required this.version,this.preguntas=const []});
  factory Encuesta.fromJson(Map<String,dynamic> j) => Encuesta(
    id:j['id_encuesta'].toString(),titulo:j['titulo'].toString(),
    descripcion:j['descripcion'].toString(),version:(j['version_encuesta'] as num).toInt(),
    preguntas:((j['preguntas'] as List?) ?? []).map((e)=>Pregunta.fromJson(Map<String,dynamic>.from(e as Map))).toList(),
  );
}
class Pregunta {
  final int id, numero;
  final String texto,tipo;
  final bool obligatoria;
  final List<String> opciones;
  const Pregunta({required this.id,required this.numero,required this.texto,
    required this.tipo,required this.obligatoria,required this.opciones});
  factory Pregunta.fromJson(Map<String,dynamic> j) => Pregunta(
    id:(j['id_pregunta'] as num).toInt(),numero:(j['numero'] as num).toInt(),
    texto:j['texto'].toString(),tipo:j['tipo'].toString(),obligatoria:j['obligatoria']==true || j['obligatoria']==1,
    opciones:((j['opciones_json'] as List?)??[]).map((e)=>e.toString()).toList());
}

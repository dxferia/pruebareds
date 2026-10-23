class Publicacion {
  final String id, titulo, descripcion, ubicacion, desde, hasta, tipo, categoria, responsable;
  final String? cantidad, metodoPago;
  const Publicacion({required this.id,required this.titulo,required this.descripcion,
    required this.ubicacion,required this.desde,required this.hasta,required this.tipo,
    required this.categoria,required this.responsable,this.cantidad,this.metodoPago});
  factory Publicacion.fromJson(Map<String,dynamic> j) => Publicacion(
    id:j['id_publicacion'].toString(),titulo:j['titulo'].toString(),
    descripcion:j['descripcion'].toString(),ubicacion:j['ubicacion'].toString(),
    desde:j['disponible_desde'].toString().split('T').first,
    hasta:j['disponible_hasta'].toString().split('T').first,
    tipo:j['tipo'].toString(),categoria:j['nombre_categoria'].toString(),
    responsable:j['responsable'].toString(),
    cantidad:j['cantidad']?.toString(),metodoPago:j['nombre_metodo_pago']?.toString(),
  );
}

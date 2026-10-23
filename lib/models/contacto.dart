class Contacto {
  final String id, nombre, correo, telefono, medioPreferido;
  const Contacto({required this.id,required this.nombre,required this.correo,
    required this.telefono,required this.medioPreferido});
  factory Contacto.fromJson(Map<String,dynamic> j) => Contacto(
    id:j['id_cuenta'].toString(),nombre:j['nombre'].toString(),
    correo:j['correo'].toString(),telefono:j['telefono'].toString(),
    medioPreferido:j['medio_preferido'].toString());
}

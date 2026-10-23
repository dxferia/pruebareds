class Solicitud {
  final String titulo, estado, fecha;
  final String? detalle;
  const Solicitud({required this.titulo,required this.estado,required this.fecha,this.detalle});
  factory Solicitud.publicacion(Map<String,dynamic> j)=>Solicitud(
    titulo:j['titulo']?.toString()??'',estado:j['estado']?.toString()??'',
    fecha:j['disponible_desde']?.toString().split('T').first??'',detalle:j['motivo_rechazo']?.toString());
  factory Solicitud.contacto(Map<String,dynamic> j)=>Solicitud(
    titulo:j['publicacion']?.toString()??'',estado:j['estado']?.toString()??'',
    fecha:j['fecha_solicitud']?.toString().split('T').first??'',detalle:j['motivo']?.toString());
}

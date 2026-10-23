class Categoria {
  final int id;
  final String nombre;
  const Categoria({required this.id, required this.nombre});
  factory Categoria.fromJson(Map<String,dynamic> json) => Categoria(
    id: (json['id_categoria'] as num).toInt(),
    nombre: json['nombre_categoria']?.toString() ?? '',
  );
}

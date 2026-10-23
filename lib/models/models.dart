enum RequestStatus { pending, approved, rejected, suspended, active, expired }

class JobPost {
  JobPost({
    required this.id,
    required this.title,
    required this.category,
    required this.location,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.people,
    this.status = RequestStatus.active,
    this.kind = 'Labor',
  });

  final String id;
  String title;
  String category;
  String location;
  String description;
  DateTime startDate;
  DateTime endDate;
  int people;
  RequestStatus status;
  String kind;
}

class ContactRequest {
  ContactRequest({
    required this.id,
    required this.jobId,
    required this.reason,
    required this.phone,
    required this.createdAt,
    this.status = RequestStatus.pending,
  });

  final String id;
  final String jobId;
  String reason;
  String phone;
  DateTime createdAt;
  RequestStatus status;
}

class PublicationRequest {
  PublicationRequest({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.people,
    required this.createdAt,
    this.status = RequestStatus.pending,
    this.rejectionReason,
  });

  final String id;
  String title;
  String category;
  String description;
  String location;
  DateTime startDate;
  DateTime endDate;
  int people;
  DateTime createdAt;
  RequestStatus status;
  String? rejectionReason;
}

class CommunityAccess {
  CommunityAccess({required this.id,required this.name, required this.status});

  final String id;
  final String name;
  RequestStatus status;
}

class HistoryEntry {
  HistoryEntry({required this.date, required this.title, required this.actor});

  final DateTime date;
  final String title;
  final String actor;
}


// Mappers for the physical model travesias_conecta (no demo records in production).
RequestStatus estadoDesdeSql(Object? e) => switch (e?.toString().toUpperCase()) {
  'PENDIENTE' => RequestStatus.pending,
  'APROBADA' => RequestStatus.approved,
  'RECHAZADA' => RequestStatus.rejected,
  'SUSPENDIDA' => RequestStatus.suspended,
  'CERRADA' => RequestStatus.expired,
  _ => RequestStatus.active,
};
DateTime fechaDesdeSql(Object? valor) => DateTime.tryParse(valor?.toString() ?? '') ?? DateTime(2000);
int cantidadDesdeSql(Object? v) => int.tryParse(v?.toString() ?? '') ?? 0;

extension JobPostApi on JobPost {
  static JobPost fromJson(Map<String,dynamic> d) => JobPost(
    id:d['id_publicacion'].toString(), title:d['titulo'].toString(),
    category:d['nombre_categoria'].toString(),
    location:d['ubicacion'].toString(), description:d['descripcion'].toString(),
    startDate:fechaDesdeSql(d['disponible_desde']), endDate:fechaDesdeSql(d['disponible_hasta']),
    people:cantidadDesdeSql(d['cantidad']), kind:d['tipo']=='SERVICIO'?'Servicio':'Labor',
    status:d['activa']==0?RequestStatus.expired:RequestStatus.active,
  );
}

extension PublicationRequestApi on PublicationRequest {
  static PublicationRequest fromJson(Map<String,dynamic> d) => PublicationRequest(
    id:d['id_solicitud'].toString(),title:d['titulo'].toString(),
    category:d['nombre_categoria'].toString(),description:d['descripcion'].toString(),
    location:d['ubicacion'].toString(), startDate:fechaDesdeSql(d['disponible_desde']),
    endDate:fechaDesdeSql(d['disponible_hasta']),people:cantidadDesdeSql(d['cantidad']),
    createdAt:fechaDesdeSql(d['fecha_solicitud']), status:estadoDesdeSql(d['estado']),
    rejectionReason:d['motivo_rechazo']?.toString(),
  );
}

extension ContactRequestApi on ContactRequest {
  static ContactRequest fromJson(Map<String,dynamic> d) => ContactRequest(
    id:d['id_solicitud_contacto'].toString(),jobId:d['id_publicacion'].toString(),
    reason:d['motivo']?.toString()??'',phone:d['telefono_autorizado']?.toString()??'',
    createdAt:fechaDesdeSql(d['fecha_solicitud']),status:estadoDesdeSql(d['estado']),
  );
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';

// Central presentation state; no mock records and no database queries in widgets.
class AppState extends ChangeNotifier {
  AppState({ApiService? cliente, bool autoLoad = false}) : api = cliente ?? ApiService() {
    if (autoLoad) unawaited(refresh());
  }
  final ApiService api;
  final List<JobPost> jobs = [];
  final List<ContactRequest> contactRequests = [];
  final List<PublicationRequest> publicationRequests = [];
  final List<CommunityAccess> accesses = [];
  final List<HistoryEntry> history = [];
  final Map<String, int> categoryIds = {};
  String search = '';
  String selectedCategory = 'Todas';
  bool simulateOffline = false;
  bool loading = true;
  String? error;
  bool get isJunta => api.adminKey != null;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final categorias = await api.categorias();
      categoryIds
        ..clear()
        ..addEntries(categorias.map((c) => MapEntry(c.nombre, c.id)));
      final publicaciones = await api.publicaciones();
      jobs
        ..clear()
        ..addAll(publicaciones.map((p) => JobPost(
            id: p.id,
            title: p.titulo,
            category: p.categoria,
            location: p.ubicacion,
            description: p.descripcion,
            startDate: fechaDesdeSql(p.desde),
            endDate: fechaDesdeSql(p.hasta),
            people: cantidadDesdeSql(p.cantidad),
            kind: p.tipo == 'SERVICIO' ? 'Servicio' : 'Labor')));
      await loadMine();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMine() async {
    try {
      if (!await api.tieneContacto) {
        publicationRequests.clear();
        contactRequests.clear();
        notifyListeners();
        return;
      }
      final publicaciones = await api.misSolicitudesPublicacionJson();
      publicationRequests
        ..clear()
        ..addAll(publicaciones.map(PublicationRequestApi.fromJson));
      final contactos = await api.misSolicitudesContactoJson();
      contactRequests
        ..clear()
        ..addAll(contactos.map(ContactRequestApi.fromJson));
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> activarJunta(String clave) async {
    api.adminKey = clave;
    try {
      await refreshJunta();
    } catch (_) {
      api.adminKey = null;
      rethrow;
    }
  }

  Future<void> refreshJunta() async {
    if (!isJunta) return;
    final solicitudes = await api.adminListado('solicitudes-publicacion');
    publicationRequests
      ..clear()
      ..addAll(solicitudes.map(PublicationRequestApi.fromJson));
    final cuentas = await api.adminListado('cuentas');
    accesses
      ..clear()
      ..addAll(cuentas.map((c) => CommunityAccess(
          id: c['id_cuenta'].toString(), name: c['nombre'].toString(), status: estadoDesdeSql(c['estado']))));
    final bitacora = await api.adminListado('historial');
    history
      ..clear()
      ..addAll(bitacora.map((h) =>
          HistoryEntry(date: fechaDesdeSql(h['fecha']), title: h['accion'].toString(), actor: h['actor'].toString())));
    notifyListeners();
  }

  void salirJunta() {
    api.adminKey = null;
    accesses.clear();
    history.clear();
    unawaited(loadMine());
    notifyListeners();
  }

  List<JobPost> get filteredJobs => jobs.where((j) {
        final cat = selectedCategory == 'Todas' || j.category == selectedCategory;
        final q = search.trim().toLowerCase();
        return cat &&
            (q.isEmpty ||
                j.title.toLowerCase().contains(q) ||
                j.category.toLowerCase().contains(q) ||
                j.location.toLowerCase().contains(q));
      }).toList();
  JobPost byJobId(String id) => jobs.firstWhere((j) => j.id == id);
  PublicationRequest byPublicationId(String id) => publicationRequests.firstWhere((p) => p.id == id);
  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void setCategory(String value) {
    selectedCategory = value;
    notifyListeners();
  }

  Future<ContactRequest> createContactRequest(
      {required String jobId, required String reason, required String phone}) async {
    await api.solicitarContacto(jobId, reason, phone);
    await loadMine();
    return contactRequests.firstWhere((r) => r.jobId == jobId,
        orElse: () => ContactRequest(id: '', jobId: jobId, reason: reason, phone: phone, createdAt: DateTime.now()));
  }

  Future<void> createPublication(
      {required String title,
      required String category,
      required String description,
      required String location,
      required DateTime start,
      required DateTime end,
      required int people}) async {
    final id = categoryIds[category];
    if (id == null) throw const ErrorApi('Categoría no disponible en MySQL.');
    final contacto = await api.miContacto();
    if (contacto == null) throw const ErrorApi('Completa Mi contacto para publicar.');
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await api.crearSolicitudPublicacion({
      'titulo': title,
      'id_categoria': id,
      'descripcion': description,
      'ubicacion': location,
      'cantidad': people.toString(),
      'disponible_desde': fmt(start),
      'disponible_hasta': fmt(end),
      'contacto_autorizado': contacto.medioPreferido == 'CORREO' ? contacto.correo : contacto.telefono
    });
    await loadMine();
  }

  Future<void> updatePublicationStatus(String id, RequestStatus status, {String? reason, String? tipo}) async {
    await api.adminDecision(id, status == RequestStatus.approved, motivo: reason, tipo: tipo);
    await refresh();
    await refreshJunta();
  }

  Future<void> updateJob(JobPost job, {required int people, required DateTime start, required DateTime end}) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await api.adminModificarPublicacion(job.id, {
      'descripcion': job.description,
      'cantidad': people.toString(),
      'ubicacion': job.location,
      'disponible_desde': fmt(start),
      'disponible_hasta': fmt(end)
    });
    await refresh();
  }

  Future<void> closeJob(JobPost job) async {
    await api.adminCerrarPublicacion(job.id);
    await refresh();
  }

  Future<void> updateAccess(CommunityAccess access, RequestStatus status) async {
    await api.adminAcceso(access.id, status.name.toUpperCase());
    await refreshJunta();
  }

  void toggleOffline(bool value) {
    simulateOffline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    api.cerrar();
    super.dispose();
  }
}

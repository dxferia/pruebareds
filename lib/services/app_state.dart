import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_service.dart';

String _fecha(DateTime d) => d.toIso8601String().split('T').first; // AAAA-MM-DD para MySQL

// Central presentation state; no mock records and no database queries in widgets.
class AppState extends ChangeNotifier {
  AppState({ApiService? cliente, bool autoLoad = false}) : api = cliente ?? ApiService() {
    if (autoLoad) unawaited(refresh());
  }
  final ApiService api;
  final List<JobPost> jobs = [];
  final List<ContactRequest> contactRequests = [];
  final List<JobPost> myPublications = [];
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
      await _cargarPublicaciones();
      await loadMine();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Catálogo en el orden del backend (fecha_publicacion DESC). Se reemplaza solo al recibir la respuesta.
  Future<void> _cargarPublicaciones() async {
    final publicaciones = await api.publicaciones();
    jobs
      ..clear()
      ..addAll(publicaciones);
  }

  Future<void> loadMine() async {
    try {
      if (!await api.tieneContacto) {
        myPublications.clear();
        contactRequests.clear();
        notifyListeners();
        return;
      }
      final publicaciones = await api.misPublicaciones();
      myPublications
        ..clear()
        ..addAll(publicaciones);
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
    api.adminKey = clave.trim(); // al copiar la clave de .env suelen venir espacios o saltos de línea
    try {
      await refreshJunta();
    } catch (_) {
      api.adminKey = null;
      rethrow;
    }
  }

  Future<void> refreshJunta() async {
    if (!isJunta) return;
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

  // Publica directamente (sin aprobación de la Junta). Solo modifica el catálogo cuando el backend confirma
  // el guardado; la misma claveEnvio en un reintento devuelve la publicación ya creada en vez de duplicarla.
  Future<JobPost> createPublication(
      {required String title,
      required String category,
      required String kind,
      required String description,
      required String location,
      required DateTime start,
      required DateTime end,
      required int people,
      required String claveEnvio}) async {
    final id = categoryIds[category];
    if (id == null) throw const ErrorApi('Categoría no disponible en MySQL.');
    final nueva = await api.crearPublicacion({
      'titulo': title,
      'id_categoria': id,
      'tipo': kind,
      'descripcion': description,
      'ubicacion': location,
      'cantidad': people.toString(),
      'disponible_desde': _fecha(start),
      'disponible_hasta': _fecha(end),
      'clave_envio': claveEnvio,
    });
    try {
      await _cargarPublicaciones(); // lista definitiva y ordenada del backend
    } catch (_) {
      jobs.removeWhere((j) => j.id == nueva.id); // sin red: se muestra el registro confirmado, sin duplicarlo
      jobs.insert(0, nueva);
    }
    // Si los filtros activos ocultarían la nueva publicación, se limpian para que aparezca primero.
    if (!filteredJobs.any((j) => j.id == nueva.id)) {
      search = '';
      selectedCategory = 'Todas';
    }
    notifyListeners();
    unawaited(loadMine());
    return nueva;
  }

  Future<void> updateJob(JobPost job, {required int people, required DateTime start, required DateTime end}) async {
    await api.adminModificarPublicacion(job.id, {
      'descripcion': job.description,
      'cantidad': people.toString(),
      'ubicacion': job.location,
      'disponible_desde': _fecha(start),
      'disponible_hasta': _fecha(end)
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

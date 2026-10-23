import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/categoria.dart';
import '../models/contacto.dart';
import '../models/encuesta.dart';
import '../models/publicacion.dart';
import '../models/solicitud.dart';
import '../utils/config.dart';

class ErrorApi implements Exception {
  final String mensaje;
  const ErrorApi(this.mensaje);
  @override
  String toString() => mensaje;
}

class ApiService {
  ApiService({http.Client? client}) : _cliente = client ?? http.Client();
  final http.Client _cliente;
  String? adminKey;
  // Prueba sin login: la clave del contacto pertenece al navegador/dispositivo.
  // No confiere permisos de Junta y no sustituye autenticación de producción.
  static const String _almacenamiento = 'travesias_clave_contacto_sin_login_v1';
  Future<String?> _clave() async => (await SharedPreferences.getInstance()).getString(_almacenamiento);
  Future<bool> get tieneContacto async => (await _clave()) != null;
  Future<dynamic> _request(String metodo, String ruta,
      {Map<String, dynamic>? body, bool identificado = false, bool administrador = false}) async {
    final url = Uri.parse('${Configuracion.apiUrl}/api$ruta');
    final headers = <String, String>{'Accept': 'application/json', 'Content-Type': 'application/json; charset=utf-8'};
    if (administrador) {
      if (adminKey == null || adminKey!.isEmpty) throw const ErrorApi('Se requiere autorización de la Junta.');
      headers['X-Admin-Key'] = adminKey!;
    }
    if (identificado) {
      final clave = await _clave();
      if (clave == null) throw const ErrorApi('Primero completa la sección Mi contacto.');
      headers['X-Contact-Key'] = clave;
    }
    try {
      late http.Response res;
      if (metodo == 'GET') {
        res = await _cliente.get(url, headers: headers).timeout(const Duration(seconds: 15));
      } else if (metodo == 'POST') {
        res = await _cliente
            .post(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15));
      } else if (metodo == 'PATCH') {
        res = await _cliente
            .patch(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15));
      } else {
        res = await _cliente
            .put(url, headers: headers, body: jsonEncode(body ?? {}))
            .timeout(const Duration(seconds: 15));
      }
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        throw const ErrorApi('El servidor devolvió una respuesta inesperada.');
      }
      if (res.statusCode == 401) {
        throw const ErrorApi('Esta operación requiere autorización del servidor.');
      }
      if (res.statusCode == 403) {
        throw const ErrorApi('No tienes permiso para realizar esta operación.');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ErrorApi(data is Map && data['error'] is String
            ? data['error'] as String
            : 'Error del servidor (${res.statusCode}).');
      }
      return data;
    } on TimeoutException {
      throw const ErrorApi('Tiempo de espera agotado. Verifica la conexión.');
    } on http.ClientException {
      throw const ErrorApi('No se pudo conectar con el servidor.');
    }
  }

  Future<List<Categoria>> categorias() async => ((await _request('GET', '/categorias')) as List)
      .map((j) => Categoria.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList();
  Future<List<Publicacion>> publicaciones({int? categoriaId}) async =>
      ((await _request('GET', '/publicaciones${categoriaId == null ? '' : '?categoria=$categoriaId'}')) as List)
          .map((j) => Publicacion.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
  Future<Contacto?> miContacto() async {
    if (!await tieneContacto) return null;
    return Contacto.fromJson(
        Map<String, dynamic>.from(await _request('GET', '/contactos/mi', identificado: true) as Map));
  }

  Future<Contacto> guardarContacto(Map<String, dynamic> datos) async {
    final existe = await tieneContacto;
    final result = Map<String, dynamic>.from(await _request(
        existe ? 'PUT' : 'POST', existe ? '/contactos/mi' : '/contactos',
        body: datos, identificado: existe) as Map);
    if (!existe) {
      final clave = result.remove('clave_edicion')?.toString();
      if (clave == null) throw const ErrorApi('El servidor no devolvió el identificador del contacto.');
      await (await SharedPreferences.getInstance()).setString(_almacenamiento, clave);
    }
    return Contacto.fromJson(result);
  }

  Future<void> crearSolicitudPublicacion(Map<String, dynamic> d) async {
    await _request('POST', '/solicitudes-publicacion', body: d, identificado: true);
  }

  Future<void> solicitarContacto(String id, String motivo, String telefono) async {
    await _request('POST', '/solicitudes-contacto',
        body: {'id_publicacion': id, 'motivo': motivo, 'telefono_autorizado': telefono}, identificado: true);
  }

  Future<List<Map<String, dynamic>>> misSolicitudesPublicacionJson() async =>
      ((await _request('GET', '/solicitudes-publicacion/mias', identificado: true)) as List)
          .map((j) => Map<String, dynamic>.from(j as Map))
          .toList();
  Future<List<Map<String, dynamic>>> misSolicitudesContactoJson() async =>
      ((await _request('GET', '/solicitudes-contacto/mias', identificado: true)) as List)
          .map((j) => Map<String, dynamic>.from(j as Map))
          .toList();
  Future<List<Solicitud>> misSolicitudesPublicacion() async =>
      ((await _request('GET', '/solicitudes-publicacion/mias', identificado: true)) as List)
          .map((j) => Solicitud.publicacion(Map<String, dynamic>.from(j as Map)))
          .toList();
  Future<List<Solicitud>> misSolicitudesContacto() async =>
      ((await _request('GET', '/solicitudes-contacto/mias', identificado: true)) as List)
          .map((j) => Solicitud.contacto(Map<String, dynamic>.from(j as Map)))
          .toList();
  Future<List<Encuesta>> encuestas() async => ((await _request('GET', '/encuestas')) as List)
      .map((j) => Encuesta.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList();
  Future<Encuesta> encuesta(String id) async =>
      Encuesta.fromJson(Map<String, dynamic>.from(await _request('GET', '/encuestas/$id') as Map));
  Future<void> enviarEncuesta(String id, Map<int, dynamic> respuestas) async {
    // Si hay perfil local, se vincula por su clave; sin perfil, se guarda como anónima.
    final vincular = await tieneContacto;
    await _request('POST', '/encuestas/$id/respuestas',
        body: {
          'respuestas': respuestas.entries.map((e) => {'id_pregunta': e.key, 'valor': e.value}).toList()
        },
        identificado: vincular);
  }

  Future<List<Map<String, dynamic>>> adminListado(String tipo) async =>
      ((await _request('GET', '/admin/$tipo', administrador: true)) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<void> adminAcceso(String id, String estado) async =>
      _request('PATCH', '/admin/cuentas/$id', body: {'estado': estado}, administrador: true);
  Future<void> adminDecision(String id, bool aprobar, {String? motivo, String? tipo}) async {
    if (aprobar && tipo != 'LABOR' && tipo != 'SERVICIO')
      throw const ErrorApi('Selecciona el tipo de publicación: Labor o Servicio.');
    await _request('POST', '/admin/solicitudes-publicacion/$id/${aprobar ? 'aprobar' : 'rechazar'}',
        body: aprobar ? {'tipo': tipo} : {'motivo': motivo}, administrador: true);
  }

  Future<void> adminModificarPublicacion(String id, Map<String, dynamic> datos) async =>
      _request('PATCH', '/admin/publicaciones/$id', body: datos, administrador: true);
  Future<void> adminCerrarPublicacion(String id) async =>
      _request('POST', '/admin/publicaciones/$id/cerrar', administrador: true);
  void cerrar() => _cliente.close();
}

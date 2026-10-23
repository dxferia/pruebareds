import 'package:flutter/foundation.dart';

/// Backend REST configurable para la prueba sin inicio de sesión.
abstract final class Configuracion {
  static const _apiDefinida = String.fromEnvironment('API_BASE_URL');
  static String get apiUrl {
    if (_apiDefinida.isNotEmpty) {
      return _apiDefinida.replaceFirst(RegExp(r'/$'), '');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}

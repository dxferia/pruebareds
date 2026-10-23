> **DOCUMENTO HISTÓRICO:** refleja una entrega previa SIN login. El estado vigente, las rutas, pruebas y requisitos están en `README.md` y `docs/AUTENTICACION_EXTERNA.md`.

# Resumen técnico de integración y verificación

## Archivos recuperados o conservados

- Estructura original de plataformas Flutter: `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/`.
- Código y recursos del módulo de encuesta: tres logos en `assets/logos`, tokens de color, tema Material 3, Montserrat/Roboto de `estilos_travesias.dart`, cinco afirmaciones y escala original trasladadas a `sql/migraciones/002_encuestas.sql`, interfaz de progreso y selección de 1 a 5.
- Base SQL original: siete entidades, relaciones, vistas, funciones, triggers y procedimientos; **copia sanitizada de tres contraseñas de ejemplo**.
- Separación REST entre Flutter y Express; paquetes Node `express`, `cors`, `mysql2` y `dotenv`.

## Archivos sustituidos

- `lib/main.dart`: antes contenía una pantalla de viajes y lógica de sesión web; ahora tiene inicio directo y navegación responsive.
- `test/widget_test.dart`: reemplaza el ejemplo del contador por una comprobación simple de apertura sin pantalla de login.
- `pubspec.yaml`: nombre y dependencias adaptados, logos registrados.
- Android `AndroidManifest.xml`: etiqueta visible y permiso INTERNET para el backend.

## Archivos nuevos

- `lib/models/*.dart`, `lib/screens/*.dart`, `lib/services/api_service.dart`, `lib/widgets/*.dart`, `lib/utils/config.dart`.
- `backend/server.js`, `backend/src/*`, `backend/test/api.test.js`, `backend/package.json`, `backend/.env.example`, Docker opcional.
- Migraciones SQL `001_perfiles_contacto.sql`, `002_encuestas.sql`, `003_permisos_backend.sql`.
- `README.md`, este informe y el contrato REST actualizado.

## Funciones originales no trasladadas

Las consultas y el registro de viajes de `Servicio dos.zip` requieren tablas (`viaje`, `ciudad`) que **no existen** en el modelo físico entregado para Travesías Conecta. No se inventaron estas tablas ni se introdujeron claves foráneas artificiales: en esta reestructuración se reemplazan por el catálogo, las solicitudes y las encuestas reales del modelo solicitado.

No se agregó un panel de administración: exigiría controles de autorización ausentes en los archivos recibidos. Las aprobaciones seguirán disponibles como procedimientos de MySQL para operadores autorizados.

## Verificación efectuada

- `node --check`: sintaxis JavaScript sin errores.
- `npm test` con Node 22.16 y bibliotecas procedentes del proyecto original: **5 pruebas aprobadas, 0 fallidas**, incluyendo solicitud HTTP real a Express con una **base de datos simulada**.
- Solo validación estática de las migraciones; **no** se aplicaron en MySQL ni se probaron sobre tablas reales, al no disponer aquí de un servidor MySQL.
- **Flutter/Dart no estaban instalados** en el entorno de preparación: no se compilaron pantallas ni se ejecutaron `flutter analyze`, `flutter test` o `flutter run`.

## Verificación pendiente en el computador del estudiante

1. Revisa y configura las contraseñas de MySQL y el archivo `.env` privado.
2. Importa esquema y migraciones de forma secuencial en una base de desarrollo.
3. Ejecuta `npm install`, `npm test`, `npm start` y consulta `/api/categorias`, `/api/publicaciones`, `/api/encuestas`.
4. Ejecuta `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run -d chrome --web-port 8080`.
5. Guarda un contacto y confirma con SQL que se creó un `id_cuenta` y su perfil vinculado.
6. Crea una solicitud de publicación, apruébala **desde MySQL con operador autorizado** si necesitas ver publicaciones reales, y comprueba el catálogo.
7. Envía una solicitud de contacto para una publicación vigente; valida el trigger de fechas/estado.
8. Contesta la encuesta; comprueba `respuesta_encuesta` y sus cinco registros en `detalle_respuesta_encuesta`.
9. Simula pérdida de conexión y verifica los mensajes de error sin cierre de la aplicación.
10. Configura HTTPS, límites de solicitudes y política de privacidad antes de usar datos personales reales en producción.

**No se afirma que el sistema completo esté probado de extremo a extremo.**

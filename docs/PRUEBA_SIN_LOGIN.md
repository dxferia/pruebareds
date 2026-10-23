# Modificaciones de esta edición de prueba

## Cambios implementados

- Flutter ahora inicia directamente `HomeScreen` (`lib/main.dart` y `lib/widgets/travesias_app.dart`), sin `AuthService`, candado, callback de token ni redirección de login externo.
- `AppState` carga datos mediante `ApiService` sin depender de una sesión (`lib/services/app_state.dart`).
- `ApiService` envía solicitudes REST sin `Authorization: Bearer`; mantiene `X-Contact-Key` solo para operaciones personales, y `X-Admin-Key` solo para Junta.
- `MoreScreen` elimina "Cerrar sesión" y "Volver al panel externo". El menú administrativo permanece.
- Express no ejecuta `authExterna()` ni exige `AUTH_VALIDATE_URL`; `/api/auth/session` desaparece. Se mantienen rutas `/api/admin/*` bajo `adminSeguro` y las validaciones de `X-Contact-Key`.
- Tests adaptados a acceso público; el test widget comprueba que se presenta la pantalla principal sin login.
- Los cinco ítems y diseño del módulo Encuestas se conservaron; la pantalla indica que no es necesario iniciar sesión.
- El SQL `servicio_chamba` fue copiado del último texto compartido y se añadieron versiones compatibles de las tres migraciones al esquema nombrado. No se ejecutó SQL contra tu servidor.

## Riesgos y limitaciones

**SOLO PARA PRUEBAS LOCALES.** Los endpoints comunitarios son anónimos: quien tenga acceso al servidor puede crear contactos o solicitudes. Las claves de contacto permiten administrar ese perfil, pero no demuestran identidad de una persona. En una red no confiable se requiere volver a implementar autenticación y autorización vinculadas al usuario. No se debe publicar la clave de Junta ni la contraseña MySQL en Flutter, el repositorio o GitHub. `ADMIN_API_KEY` nunca debe configurarse como texto fijo en el cliente Flutter.

No se convirtió `servicio_chamba` en `travesias_conecta` ni se modificó el host/puerto del pool. Los valores del `.env.example` reflejan el esquema SQL que aportaste. Los scripts SQL de ambas variantes se proporcionan para facilitar la integración con la base correcta, sin migrar datos automáticamente.

## Comprobaciones

- Verificación estática de referencias Dart y de que los módulos de login no se usan.
- `node --check` sobre los archivos JavaScript del backend.
- Tests Node.js requieren `npm install`; en el entorno de edición no hay acceso al registro de npm para instalar dependencias.
- Flutter SDK y servidor MySQL remoto no están disponibles en el entorno de edición, por lo que no se afirma una compilación Flutter ni una conexión real a MySQL.

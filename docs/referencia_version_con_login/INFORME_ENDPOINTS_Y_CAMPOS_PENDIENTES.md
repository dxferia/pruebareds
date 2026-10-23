# IMPLEMENTACIÓN Y AUDITORÍA — endpoints Travesías Conecta

**Fecha:** 22 de octubre de 2026. **Paquete base:** `Travesias_Conecta_Conexion_MySQL_3309_Actualizado.zip`.

## 1. Alcance y contradicción confirmada

La instrucción nueva solicita **`servicio_chamba`**, pero la aplicación que se recibió es **Travesías Conecta** y sus únicos scripts MySQL (`sql/modelo_fisico_original.sql` y tres migraciones) crean **`travesias_conecta`**. El backend también señala `travesias_conecta` en la configuración existente. No se adjuntó el DDL de `servicio_chamba`; el archivo de ejemplo de gestión de viajes no contiene SQL definitorio de ese esquema. No es posible asegurar columnas, PK/FK ni crear endpoints específicos para `servicio_chamba` sin inspeccionarlo en el servidor de base de datos autorizado.

**Por lo tanto:** se conserva exactamente la conexión y el inicio del servidor de la versión proporcionada; no se sustituye `DB_NAME`, ni host/puerto/usuario/contraseña, ni los pools, ni la configuración Express y CORS, ni el listener. Se completan rutas justificadas por el **esquema documentado** de Travesías Conecta. Si `servicio_chamba` es de otro proyecto, hay que proporcionar su SQL o salida de `schema:inspect` de ese entorno y el backend correspondiente para implementarle rutas sin inventar columnas.

## 2. Inventario de tablas realmente documentadas

| Tabla | PK | Función y relaciones | Eliminación |
|---|---|---|---|
| `cuenta_acceso` | `id_cuenta` | solicitudes, publicaciones y contactos; estados | No: FK RESTRICT |
| `categoria` | `id_categoria` | catálogo de labores | No: FK |
| `solicitud_publicacion` | `id_solicitud` | petición por responsable con categoría | No: historial/aprobaciones |
| `publicacion` | `id_publicacion` | publicaciones aprobadas y de la Junta | Cierre lógico (`activa=FALSE`) |
| `metodo_pago` | `id_metodo_pago` | catálogo opcional sin valores iniciales | No: FK |
| `solicitud_contacto` | `id_solicitud_contacto` | solicitud entre remitente y responsable | No: historial/estado |
| `historial_gestion` | `sin clave primaria` | auditoría por trigger | No: auditoría |
| `contacto_perfil` | `id_cuenta` | datos de contacto vinculados a cuenta | No: FK y datos personales |
| `encuesta` | `id_encuesta` | catálogo y vigencia | No: FK |
| `pregunta_encuesta` | `id_pregunta` | preguntas ordenadas, tipo y obligatoriedad | No: FK |
| `respuesta_encuesta` | `id_respuesta` | encabezado de respuestas | No: FK |
| `detalle_respuesta_encuesta` | `id_detalle` | valores JSON de respuestas | No: FK |

Relaciones comprobadas estáticamente: `cuenta_acceso` 1:N `solicitud_publicacion`; `categoria` 1:N `solicitud_publicacion` y `publicacion`; `solicitud_publicacion` 1:0..1 `publicacion`; `cuenta_acceso` 1:N `publicacion`; `publicacion` 1:N `solicitud_contacto`; `cuenta_acceso` enlaza remitente/responsable; `contacto_perfil` referencia `cuenta_acceso`; `encuesta` 1:N `pregunta_encuesta` y `respuesta_encuesta`; `respuesta_encuesta` 1:N `detalle_respuesta_encuesta`. Muchos `ON DELETE RESTRICT` impiden un DELETE general seguro; por eso no se crearon rutas de borrado masivo ni eliminación física de historial o respuestas.

**Tablas de `servicio_chamba`:** desconocidas sin el DDL o una consulta real autorizada; no se afirma que coincidan con las anteriores.

## 3. Estructura del proyecto y archivos

- `backend/server.js`: inicio Express y prueba SQL al arrancar (**sin modificar**).
- `backend/src/config/database.js`, `admin_database.js`: pool principal y pool administrativo (**sin modificar**).
- `backend/src/app.js`: CORS, JSON, salud, autenticación y errores (**sin modificar**).
- `backend/src/routes/api.js`: **modificado**, incorpora 11 rutas nuevas sin duplicar las existentes.
- `backend/src/controllers/publicaciones.js`: **modificado**, detalle público de categorías/publicaciones y detalle propio de solicitudes filtrado por cuenta de contacto.
- `backend/src/controllers/admin.js`: **modificado**, listados y detalle, decisiones de solicitudes de contacto con transición atómica `PENDIENTE` → `APROBADA`/`RECHAZADA`.
- `backend/scripts/inspeccionar_esquema.js`: **nuevo**, lee `INFORMATION_SCHEMA` del esquema configurado en la conexión existente (no escribe datos ni cambia parámetros).
- `backend/package.json`: **modificado** solo para registrar `npm run schema:inspect`.
- `backend/test/endpoints_adicionales.test.js`: **nuevo**, comprobación de rutas, permisos y SQL simulado.
- `lib/services/api_service.dart`, `lib/services/app_state.dart`, `lib/screens/review_request_screen.dart`: **modificados** para pedir a la Junta elegir `LABOR` o `SERVICIO` antes de aprobar.
- `docs/ARCHIVOS_PROTEGIDOS_SHA256.json`: huellas de cinco archivos que permanecieron byte a byte iguales.
- Todo lo demás: conservado.

## 4. Endpoints HTTP registrados

Incluye 2 rutas de `src/app.js` y 31 registradas en `src/routes/api.js`; total **33 rutas** (22 existentes, 11 nuevas).

| Método | Ruta | Dominio | Estado |
|---|---|---|---|
| GET | `/api/health` | salud | Existente, sin token |
| GET | `/api/auth/session` | autenticación | Existente, con Bearer |
| GET | `/api/categorias` | publicaciones/solicitudes | Existente |
| GET | `/api/categorias/:id` | publicaciones/solicitudes | **Nuevo** |
| GET | `/api/publicaciones` | publicaciones/solicitudes | Existente |
| GET | `/api/publicaciones/:id` | publicaciones/solicitudes | **Nuevo** |
| POST | `/api/solicitudes-publicacion` | publicaciones/solicitudes | Existente |
| GET | `/api/solicitudes-publicacion/mias` | publicaciones/solicitudes | Existente |
| GET | `/api/solicitudes-publicacion/:id` | publicaciones/solicitudes | **Nuevo** |
| POST | `/api/solicitudes-contacto` | publicaciones/solicitudes | Existente |
| GET | `/api/solicitudes-contacto/mias` | publicaciones/solicitudes | Existente |
| GET | `/api/solicitudes-contacto/:id` | publicaciones/solicitudes | **Nuevo** |
| POST | `/api/contactos` | contactos | Existente |
| GET | `/api/contactos/mi` | contactos | Existente |
| PUT | `/api/contactos/mi` | contactos | Existente |
| GET | `/api/encuestas` | encuestas | Existente |
| GET | `/api/encuestas/:id` | encuestas | Existente |
| POST | `/api/encuestas/:id/respuestas` | encuestas | Existente |
| GET | `/api/admin/solicitudes-publicacion` | administración | Existente |
| GET | `/api/admin/solicitudes-publicacion/:id` | administración | **Nuevo** |
| GET | `/api/admin/solicitudes-contacto` | administración | **Nuevo** |
| GET | `/api/admin/solicitudes-contacto/:id` | administración | **Nuevo** |
| PATCH | `/api/admin/solicitudes-contacto/:id` | administración | **Nuevo** |
| GET | `/api/admin/publicaciones` | administración | **Nuevo** |
| GET | `/api/admin/publicaciones/:id` | administración | **Nuevo** |
| GET | `/api/admin/metodos-pago` | administración | **Nuevo** |
| GET | `/api/admin/cuentas` | administración | Existente |
| GET | `/api/admin/historial` | administración | Existente |
| POST | `/api/admin/solicitudes-publicacion/:id/aprobar` | administración | Existente |
| POST | `/api/admin/solicitudes-publicacion/:id/rechazar` | administración | Existente |
| PATCH | `/api/admin/cuentas/:id` | administración | Existente |
| PATCH | `/api/admin/publicaciones/:id` | administración | Existente |
| POST | `/api/admin/publicaciones/:id/cerrar` | administración | Existente |

Todas las rutas `/api` salvo `/api/health` pasan por la validación externa. Las rutas `/api/admin/*` requieren además el control administrativo preexistente. **No se relajaron permisos** para incorporar nuevos endpoints.

## 5. Consultas SQL agregadas

| Recurso | Operación parametrizada | Tabla o vista |
|---|---|---|
| `categorias/:id` | `SELECT ... WHERE id_categoria=?` | `categoria` |
| `publicaciones/:id` | `SELECT ... WHERE id_publicacion=?` | `vw_publicaciones_vigentes` |
| `solicitudes-publicacion/:id` | `SELECT ... WHERE id_solicitud=? AND id_solicitante=?` | `vw_solicitudes_publicacion` |
| `solicitudes-contacto/:id` | `SELECT ... WHERE id_solicitud_contacto=? AND id_remitente=?` | `vw_solicitudes_contacto` |
| `/admin/solicitudes-publicacion/:id` | `SELECT ... WHERE id_solicitud=?` | `vw_solicitudes_publicacion` |
| `/admin/solicitudes-contacto` | `SELECT ... ORDER BY fecha_solicitud DESC LIMIT 200` | `vw_solicitudes_contacto` |
| `/admin/solicitudes-contacto/:id` | `SELECT ... WHERE id_solicitud_contacto=?` | `vw_solicitudes_contacto` |
| `/admin/solicitudes-contacto/:id` (PATCH) | `UPDATE ... SET estado=? WHERE id_solicitud_contacto=? AND estado='PENDIENTE'` | `solicitud_contacto` + trigger de historial |
| `/admin/publicaciones` | `SELECT ... JOIN categoria ... LIMIT 200` | `publicacion`, `categoria` |
| `/admin/publicaciones/:id` | `SELECT ... WHERE id_publicacion=?` | `publicacion` |
| `/admin/metodos-pago` | `SELECT ... ORDER BY nombre_metodo_pago` | `metodo_pago` |

**Códigos:** `200` consulta/cambio correcto; `401` sesión inválida; `403` contacto/administrador sin permiso; `404` registro inexistente o ajeno al remitente; `409` solicitud ya procesada; `422` ID o estado inválido; `500` errores internos seguros; `503` proveedor de identidad no configurado.

La actualización administrativa de `solicitud_contacto` realiza un solo `UPDATE` condicionado. El trigger `trg_contacto_auditar_au` del esquema original registra el historial. No modifica relaciones ni elimina datos.

## 6. Campos incompletos, variables y responsables

| Campo o archivo | Estado actual | Para qué sirve | Información que falta | Quién puede proporcionarla | Cómo verificarlo |
|---|---|---|---|---|---|
| `DB_NAME` / SQL | `travesias_conecta` en la base disponible; se pide `servicio_chamba` | Determina las tablas disponibles | Confirmar cuál proyecto/base debe recibir los endpoints | Responsable del proyecto | `npm run schema:inspect` y comparar DDL |
| `DB_HOST` / `DB_PORT` | `172.27.30.205:3309` declarados, no verificados | Destino del servidor MySQL | Acceso a la misma red/VPN y prueba TCP real | Administrador de red | `Test-NetConnection 172.27.30.205 -Port 3309` |
| `DB_PASSWORD` | Se rellena solo en `.env` local; no se incluye en ZIP | Autenticación MySQL | Ningún dato adicional si ya tienes tu clave local; comprobarla | Propietario autorizado de MySQL | `npm run db:check`, sin compartir contraseña |
| `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD` | Configuración local, a veces `root` | Operaciones sensibles | Usuario con permisos mínimos adecuado, cuando se vaya a desplegar | DBA | `SHOW GRANTS FOR CURRENT_USER()` |
| `AUTH_VALIDATE_URL` | Vacía en ejemplo | Confirmar token del Servicio A | URL real, método, cabeceras, respuesta JSON y vigencia | Equipo del Servicio A | Pruebas de sesión válida/inválida |
| `AUTH_LOGIN_URL` (Flutter `--dart-define`) | No confirmada | Redirigir al inicio de sesión externo | URL pública real del login | Equipo del Servicio A | Probar redirección y retorno |
| `ADMIN_API_KEY` | Marcador de ejemplo, no es una clave real | Proteger administración actualmente | Secreto generado localmente; autorización por rol verificable en el futuro | Administrador | Llamadas admin con/sin autorización |
| Identidad SSO ↔ `contacto_perfil` | Claves locales por navegador; no vinculadas de forma comprobable al SSO en MySQL | Control de propiedad real del perfil | Decidir cómo enlazar la identidad validada y migrar perfiles existentes | Equipo de identidad + DBA | Dos usuarios con claves distintas no pueden acceder mutuamente |
| `metodo_pago` | No hay nombres iniciales en SQL | Mostrar métodos de pago disponibles | Valores oficiales si se desean usar en publicaciones | Junta | `SELECT * FROM metodo_pago` |
| `solicitud_publicacion` | No contiene columna `tipo` | Clasificar publicación al aprobar | Decisión por cada solicitud, no inferible por categoría | Junta | Ventana de aprobación Flutter corregida |
| `CORS_ORIGIN` | Orígenes locales de desarrollo | Habilitar navegador autorizado | URL del despliegue futuro | DevOps | Prueba desde origen autorizado/no autorizado |
| Esquema remoto / migraciones | Scripts disponibles, aplicación real sin verificar | Guardar contactos y encuestas | Verificar que tablas, vistas y SP se han instalado | DBA | `npm run db:check`; `npm run schema:inspect` |
| Eliminación de registros | FK `RESTRICT` y auditoría | Protección de integridad | Política de retención/borrado y privacidad | Responsable funcional | Revisar reglas antes de agregar DELETE |

**Completado sin datos externos:** rutas nuevas derivadas del SQL, validación de IDs y estados, elección explícita del tipo Labor/Servicio, introspección read-only, pruebas HTTP simuladas. **No se inventaron** usuarios, publicaciones, métodos de pago, claves ni endpoints del Servicio A.

## 7. Prioridades y preguntas que faltan

**Bloqueantes:** confirmar si el objetivo es `servicio_chamba` y aportar su DDL (o el código/ZIP real de ese proyecto); verificar disponibilidad del servidor MySQL en la red. **Alta:** `AUTH_VALIDATE_URL` y contrato del Servicio A; identidad SSO vinculada al perfil; habilitación del administrador. **Media:** política de estados y borrado, métodos de pago oficiales y configuración de despliegue. **Baja:** limpieza de código y pruebas de widgets.

**Preguntas realmente necesarias** para completar `servicio_chamba`: ¿el ZIP real es otro proyecto distinto de Travesías Conecta? Si es el mismo, ¿qué archivo SQL contiene el esquema exacto de `servicio_chamba`? ¿Quién facilita el endpoint de validación del Servicio A y su contrato? No se necesita que envíes contraseñas ni tokens al chat.

## 8. Pruebas y limitaciones reales

- **11/11 pruebas Node.js aprobadas** en esta sesión con DB simulada, autenticación simulada y Servicio A simulado. Se incluyen comprobaciones de 200/401/403/409/422 y del valor parametrizado para estado.
- **Sintaxis JavaScript** comprobada con `node --check` sobre archivos del backend.
- **Archivos protegidos** comparados por SHA256 con el ZIP base, sin modificaciones.
- **No probado:** sesión con el Servicio A real, conexión TCP o SQL real a MySQL `172.27.30.205:3309`, `servicio_chamba`, migraciones en MySQL, compilación Flutter de la modificación visual (SDK Flutter no disponible aquí).
- **No se ejecutaron consultas de producción** ni operaciones de escritura sobre datos reales.

### Para verificar en Windows

En la raíz del proyecto Flutter (carpeta donde está `pubspec.yaml`):

```powershell
$env:Path = "C:\Users\USER\Documents\Flutter\flutter\bin;$env:Path"
flutter pub get
flutter analyze
```

En otra terminal, desde `backend/`:

```powershell
npm install
npm test
Test-NetConnection 172.27.30.205 -Port 3309
npm run schema:inspect
npm run db:check
npm start
```

`npm run schema:inspect` **no cambia `DB_NAME`** ni modifica registros. Muestra las tablas, las columnas y las FK del esquema al que apunta tu `.env`. El comando requiere que la conexión actual a MySQL funcione. Evita compartir capturas con secretos.

**Estado:** API documentada de Travesías Conecta ampliada; integración real con servidor/Servicio A pendiente; implementación específica de `servicio_chamba` **pendiente de su esquema auténtico**.

# Backend SiHayChamba (Travesías Conecta)

API REST en **Node.js + Express 5 + MySQL** (`mysql2/promise`) sobre la base **`sihaychamba`**.
Mantiene el contrato que ya consume la app Flutter (`lib/services/api_service.dart`).

## Estructura

```text
backend/
├── config/db.js                 Pool único (mysql2/promise) + helper de transacciones con @actor_app
├── controllers/                 Validación de entrada y respuesta HTTP
│   ├── admin.controller.js  catalogo.controller.js  contactos.controller.js
│   └── encuestas.controller.js  salud.controller.js  solicitudes.controller.js
├── middleware/
│   ├── auth.js                  X-Admin-Key (Junta) y X-Contact-Key (Mi contacto)
│   ├── cors.js                  Orígenes de Flutter Web
│   └── errores.js               404 y manejador central (traduce errores MySQL sin filtrar detalles)
├── routes/                      index.js + una ruta por módulo
├── services/                    SQL parametrizado y reglas de negocio (uno por módulo)
├── utils/validacion.js          HttpError y validadores reutilizables
├── public/index.html            Página de estado (consulta /api/health)
├── sql/                         Migraciones 001 y 002 (tablas que el modelo base no trae)
├── test/                        api.test.js (MySQL simulado) y mysql.solo-lectura.js (MySQL real)
├── app.js  .env  .env.example  .gitignore  package.json  package-lock.json  Dockerfile
```

## Endpoints

Base: `http://localhost:3000/api`. Las respuestas exitosas devuelven el JSON directamente y los errores devuelven `{"error": "mensaje"}`.

| Módulo | Método y ruta | Permiso | Tablas / objetos MySQL |
|---|---|---|---|
| Salud | `GET /health` | público | `information_schema` |
| Catálogo | `GET /categorias` | público | `categoria` |
| | `GET /publicaciones?categoria=ID` | público | `vw_publicaciones_vigentes` |
| | `GET /publicaciones/:id` | público | `vw_publicaciones_vigentes` |
| Mi contacto | `POST /contactos` → 201 + `clave_edicion` | público | `cuenta_acceso`, `contacto_perfil` |
| | `GET /contactos/mi` | X-Contact-Key | `contacto_perfil` ⋈ `cuenta_acceso` |
| | `PUT /contactos/mi` | X-Contact-Key | `cuenta_acceso`, `contacto_perfil` |
| Solicitudes | `POST /solicitudes-publicacion` | X-Contact-Key, cuenta no suspendida | `sp_crear_solicitud_publicacion` |
| | `GET /solicitudes-publicacion/mias` | X-Contact-Key | `vw_solicitudes_publicacion` |
| | `POST /solicitudes-contacto` | X-Contact-Key, cuenta no suspendida | `publicacion`, `sp_crear_solicitud_contacto` (+ trigger) |
| | `GET /solicitudes-contacto/mias` | X-Contact-Key | `vw_solicitudes_contacto` |
| Encuestas | `GET /encuestas` | público | `encuesta` |
| | `GET /encuestas/:id` | público | `encuesta`, `pregunta_encuesta` |
| | `POST /encuestas/:id/respuestas` | público; X-Contact-Key opcional (una por contacto) | `respuesta_encuesta`, `detalle_respuesta_encuesta` |
| Junta | `GET /admin/solicitudes-publicacion?estado=` | X-Admin-Key | `vw_solicitudes_publicacion` |
| | `POST /admin/solicitudes-publicacion/:id/aprobar` `{tipo: LABOR\|SERVICIO}` | X-Admin-Key | `sp_aprobar_solicitud_publicacion` |
| | `POST /admin/solicitudes-publicacion/:id/rechazar` `{motivo}` | X-Admin-Key | `sp_rechazar_solicitud_publicacion` |
| | `GET /admin/solicitudes-contacto` | X-Admin-Key | `vw_solicitudes_contacto` |
| | `PATCH /admin/solicitudes-contacto/:id` `{estado: APROBADA\|RECHAZADA}` | X-Admin-Key | `solicitud_contacto` |
| | `PATCH /admin/publicaciones/:id` (parcial) | X-Admin-Key | `sp_actualizar_publicacion` |
| | `POST /admin/publicaciones/:id/cerrar` | X-Admin-Key | `sp_cerrar_publicacion` |
| | `GET /admin/cuentas` | X-Admin-Key | `cuenta_acceso` |
| | `PATCH /admin/cuentas/:id` `{estado}` (español o inglés) | X-Admin-Key | `sp_cambiar_estado_cuenta` |
| | `GET /admin/historial` | X-Admin-Key | `vw_historial_gestion` |

Códigos de estado: 400 datos inválidos · 401 falta clave o no se reconoce · 403 clave de la Junta incorrecta o cuenta suspendida · 404 no existe · 409 conflicto (regla de negocio de MySQL, duplicado o ya procesado) · 503 MySQL no disponible, migración faltante o `ADMIN_API_KEY` sin configurar.

## Variables de entorno (`backend/.env`)

| Variable | Propósito |
|---|---|
| `PORT` | Puerto de la API. `3000`, que es el valor que usa Flutter por defecto. Si falta, el servidor usa `8082`. |
| `DB_HOST`, `DB_PORT` | Servidor MySQL: `127.0.0.1:3308` (es el equipo donde corre Node, no el del navegador). |
| `DB_NAME` | `sihaychamba` |
| `DB_USER`, `DB_PASSWORD` | Credenciales locales. Solo van en `.env`, que no se versiona. |
| `ADMIN_API_KEY` | Clave de la Junta, de al menos 32 caracteres. Mientras esté vacía, `/api/admin` responde 503. |
| `CORS_ORIGIN` | Orígenes de Flutter Web, separados por comas. |

## Puesta en marcha (Windows, PowerShell)

1. **Base de datos.** En MySQL Workbench, conectado a `127.0.0.1:3308`, verifica con `SHOW DATABASES LIKE 'sihaychamba'; USE sihaychamba; SHOW TABLES;` que existan las 7 tablas de `bd_sihaychamba.sql`. Después, haz una copia de seguridad y ejecuta en este orden `sql/001_perfiles_contacto.sql` y `sql/002_encuestas.sql`. Ambos usan `CREATE TABLE IF NOT EXISTS` y no modifican las tablas existentes.
2. **Dependencias.** Ejecuta `cd backend` y luego `npm install`.
3. **Clave de la Junta.** Ejecuta `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` y pega el resultado en `ADMIN_API_KEY=` dentro de `.env`.
4. **Comprobaciones.**
   - `npm run db:check`: verifica la conexión, el nombre de la base y las 12 tablas.
   - `npm test`: prueba la API completa con MySQL simulado.
   - `npm run test:mysql`: ejecuta todas las consultas SELECT contra tu MySQL real, en modo de solo lectura.
5. **Servidor.** Ejecuta `npm start`, abre `http://localhost:3000/` (página de estado) y comprueba `http://localhost:3000/api/categorias`.
6. **Flutter.** En otra terminal, ejecuta `flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000`.

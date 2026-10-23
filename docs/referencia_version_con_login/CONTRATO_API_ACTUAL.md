# Contrato REST actual — Travesías Conecta (con login externo)

Todos los endpoints comienzan en `/api` y envían/reciben JSON. **Excepción:** `GET /api/health` no requiere autenticación; todas las demás rutas exigen `Authorization: Bearer <token-validado-por-Servicio-A>`. `GET /api/auth/session` devuelve `{"autenticado":true,"usuario":"<identidad-verificada>"}` cuando el token fue confirmado por el Servicio A. El cliente debe enviar el Bearer además de `X-Contact-Key` en las operaciones del perfil y del secreto administrativo en las de Junta. Errores: `{"error":"Descripción clara"}`. La clave local `X-Contact-Key` solo se entrega a las rutas que requieren conocer al remitente; nunca se envía por parámetro URL.

## Guardar datos de contacto

```http
POST /api/contactos
Content-Type: application/json
```

```json
{"nombre":"Ana Pérez","correo":"ana@ejemplo.com","telefono":"+57 300 123 4567","medio_preferido":"WHATSAPP"}
```

Respuesta `201`: el objeto incluye `id_cuenta`, los cuatro datos y `clave_edicion` generada **una sola vez**. El cliente la guarda localmente sin mostrarla públicamente. `GET /api/contactos/mi` y `PUT /api/contactos/mi` requieren `X-Contact-Key: <clave_recibida>`.

## Consultar y solicitar publicaciones

```http
GET /api/categorias
GET /api/publicaciones
GET /api/publicaciones?categoria=1
```

El script original no incluye publicaciones iniciales; la respuesta puede ser `[]` sin significar que haya fallado la API.

```http
POST /api/solicitudes-publicacion
X-Contact-Key: <clave_recibida>
Content-Type: application/json
```

```json
{"id_categoria":1,"titulo":"Servicio de carpintería","descripcion":"Se solicita reparación de muebles de madera.","cantidad":"2 muebles","ubicacion":"Florencia, Caquetá","disponible_desde":"2026-10-20","disponible_hasta":"2026-10-30","contacto_autorizado":"WhatsApp"}
```

Devuelve `201` y estado `PENDIENTE`, no una publicación aprobada. El catálogo se alimenta exclusivamente de registros vigentes de la vista SQL.

```http
POST /api/solicitudes-contacto
X-Contact-Key: <clave_recibida>
Content-Type: application/json
```

```json
{"id_publicacion":"id-real-de-la-publicacion","motivo":"Quiero conocer las condiciones del trabajo."}
```

`telefono_autorizado` se obtiene del perfil almacenado y el responsable se toma dentro de `sp_crear_solicitud_contacto` desde la publicación real.

## Listar encuestas

```http
GET /api/encuestas
GET /api/encuestas/travesias-usabilidad-v1
```

El detalle retorna `preguntas` en orden con `id_pregunta`, `numero`, `texto`, `tipo`, `obligatoria`, `opciones_json`. La UI presenta exactamente las cinco afirmaciones del módulo recibido que se cargan en `002_encuestas.sql`. Para otras encuestas: tipos `ESCALA` (1–5), `TEXTO`, `UNICA` y `MULTIPLE` (opciones definidas en JSON).

## Responder

```http
POST /api/encuestas/travesias-usabilidad-v1/respuestas
Content-Type: application/json
```

```json
{"respuestas":[
 {"id_pregunta":1,"valor":5},
 {"id_pregunta":2,"valor":4},
 {"id_pregunta":3,"valor":5},
 {"id_pregunta":4,"valor":4},
 {"id_pregunta":5,"valor":5}
]}
```

**Importante:** los `id_pregunta` autoincrementales mostrados son **solo ilustrativos**. Primero consulta el detalle de la encuesta y utiliza los IDs reales del servidor, ya que podrían ser otros.

Al responder, la API valida cada opción, escala y obligatoriedad antes de registrar transaccionalmente una cabecera en `respuesta_encuesta` y detalles en `detalle_respuesta_encuesta`. Si se incluye `X-Contact-Key`, la respuesta queda vinculada al perfil local; de lo contrario es anónima. La clave única limita una respuesta vinculada por versión/identificador de encuesta. `201 {"id_respuesta": ..., "guardado": true}` significa persistencia confirmada por el servidor.

## Seguridad y administración

Las rutas `/api/admin/*` requieren sesión externa validada **y** clave `X-Admin-Key` válida. No basta con enviar un usuario o token por la URL. Los errores HTTP 401 invalidan la sesión del frontend; HTTP 403 expresa falta de permiso. Sin `AUTH_VALIDATE_URL` el servidor no habilita rutas privadas. Más detalles en `docs/AUTENTICACION_EXTERNA.md`.


Los procedimientos `sp_aprobar_solicitud_publicacion`, `sp_rechazar_solicitud_publicacion`, `sp_crear_publicacion_junta`, `sp_actualizar_publicacion`, `sp_cerrar_publicacion` y `sp_cambiar_estado_cuenta` **NO** tienen rutas públicas y el rol backend pierde permiso para ejecutarlos en `003_permisos_backend.sql`. La administración debe realizarse desde un proceso separado con autorización y auditoría propias. No exponer vistas de historial ni detalles de encuestas en rutas públicas.

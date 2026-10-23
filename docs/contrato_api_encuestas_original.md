# Contrato HTTP del módulo de encuestas

**Ruta:** `POST /api/v1/encuestas/usabilidad`  
**Autenticación:** `Authorization: Bearer <token-del-login-central>`  
**Tipo:** `application/json`

## Solicitud

```json
{
  "subproyecto_id": "turismo",
  "version_encuesta": 1,
  "respuestas": {
    "respuesta_1": 5,
    "respuesta_2": 4,
    "respuesta_3": 5,
    "respuesta_4": 4,
    "respuesta_5": 5
  }
}
```

El ID `turismo` es **un ejemplo**, no representa un ID real de Travesías.

El backend extrae `usuario_id` del token validado; **no** lo acepta como dato enviado por el cliente.
Verifica que el subproyecto exista y que el usuario esté autorizado a usarlo antes de insertar.

## Respuestas

- `201`: registro creado, `{"id": 17, "subproyecto_id": "turismo", "version_encuesta": 1, "guardado": true}`.
- `401`: sesión inválida.
- `403`: usuario sin acceso al subproyecto.
- `409`: ya existe una encuesta respondida por usuario/subproyecto/versión.
- `422`: validación de campos o puntuaciones fallida.
- `5xx`: error del servidor.

## Decisiones del módulo

- La escala Likert es 1 a 5; hay exactamente cinco afirmaciones en el formulario.
- Una respuesta por combinación `(usuario_id, subproyecto_id, version_encuesta)`.
- Se puede volver a evaluar al publicar una **nueva versión** de la encuesta.
- Los resultados se pueden consultar de forma agregada por subproyecto y versión.
- Se conserva únicamente el ID del usuario autenticado: no se guardan nombres, correos ni tokens.
- Los resultados sensibles deben mostrarse solo a roles autorizados y, preferiblemente, agregados.
- Una política de retención y un aviso de tratamiento de datos deben definirse según la política del proyecto.

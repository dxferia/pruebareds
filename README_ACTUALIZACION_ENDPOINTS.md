# Entrega: endpoints ampliados y evaluación de datos faltantes

**Empieza por:** `docs/INFORME_ENDPOINTS_Y_CAMPOS_PENDIENTES.md` (inventario completo de 33 endpoints, 12 tablas, rutas nuevas y pendientes).

Este paquete conserva la estructura del proyecto Flutter y backend anterior. Los archivos de conexión e inicio no se modificaron. `backend/.env` se configura solamente en tu equipo.

> **Importante:** el proyecto aportado utiliza `travesias_conecta`; tu último prompt menciona `servicio_chamba`, pero no adjunta su esquema. No he cambiado los valores de la conexión ni inventado la estructura de esa otra base.

## Verificación rápida

```powershell
cd backend
npm install
npm test
npm run schema:inspect
npm run db:check
```

`npm run schema:inspect` reutiliza la conexión actual y es de solo lectura. Para iniciar el backend, configura `.env` localmente y ejecuta `npm start`. Consulta el README principal para las instrucciones de Flutter sin login externo.

**Flutter:** la pantalla de aprobación ya solicita el tipo `LABOR` o `SERVICIO` en lugar de enviar siempre `LABOR`. No hay nuevos módulos de viajes.

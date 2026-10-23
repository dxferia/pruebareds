# Matriz de verificación contra la guía proporcionada

| Requisito exacto de la guía | Fuente | Implementación |
| --- | --- | --- |
| Flutter y Dart | p. 1 | `flutter/lib/`, `demo/lib/` |
| Verde Amazonia #007A33 | p. 2 | `TravesiasColores.primario`, AppBar, ElevatedButton, progreso |
| Rojo Institucional #E20613 | p. 2 | `TravesiasColores.alerta`, mensajes de error |
| Azul Sistemas #0085CA | p. 3 | `TravesiasColores.complementario`, icono secundario, TextButton |
| Gris Claro #F8F9FA | p. 3 | `scaffoldBackgroundColor` y zona del formulario |
| Gris Oscuro #212529 | p. 3 | tipografías y etiquetas |
| Montserrat para H1/H2/H3, peso 600/700 | p. 3 | `GoogleFonts.montserrat` en títulos |
| Roboto para cuerpo, 14-16px | p. 3 | `GoogleFonts.roboto` bodyMedium/bodyLarge |
| Roboto Medium para botones y etiquetas | p. 3 | `GoogleFonts.roboto` labelLarge y estilos de botones |
| Material Design 3 y ThemeData global | p. 3 | `temaTravesiasEncuesta()` en `demo/lib/main.dart`; integración documentada para cada app |
| ElevatedButton verde blanco radio 8px | p. 4 | botón Enviar, ElevatedButtonThemeData |
| OutlinedButton para cancelar/regresar | p. 4 | botón Regresar; OutlinedButtonThemeData |
| TextButton sin fondo ni borde | p. 4 | TextButtonThemeData azul para acciones menores |
| Card elevación 2-4, radio 12, padding 16 | p. 4 | _Tarjeta (Card con elevación 2 y radio 12); Padding(16) en formulario |
| Mantener relación de aspecto del logo | p. 5 | tres Image.asset con `BoxFit.contain` |
| Mostrar logotipo en zona visible | p. 5 | encabezado institucional antes del formulario |
| Figma obligatorio | p. 5 | `docs/CRITERIOS_DE_FIGMA.md` para construcción; **pendiente creación en espacio Figma oficial** |

**No aplican**: DataTables, fotos de perfil y NetworkImage; la pantalla de encuesta no los contiene.

**Parámetros de implementación adicionales**: ancho central 820px, padding externo 16px, espaciados entre tarjetas 12px, colores neutros de bordes y selección, tamaños de íconos y del indicador de progreso. No están especificados por la guía, por lo que se presentan como decisiones de interfaz, no como requisitos del documento.

**Identidad del proyecto:** la guía usa el nombre *Redes Comunitarias*; el módulo se integra en *Proyecto Travesías*. No se renombraron los tres logos originales.

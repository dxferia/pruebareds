# Corrección del resultado de `flutter analyze` (21/10/2026)

## Problema original

Tras instalar las dependencias, Flutter 3.41.1 identificó 48 observaciones. Los errores bloqueantes apuntaban a `docs/encuesta_usabilidad_original.dart`, código de referencia con imports ausentes (`cliente_encuesta_api.dart`, `estilos_travesias.dart`, `repositorio_encuesta.dart`). Este archivo NO es la encuesta funcional del proyecto, que está en `lib/screens/encuestas_screen.dart`.

## Cambios aplicados

- Se preserva el documento original como `docs/encuesta_usabilidad_original.dart.txt`; no se elimina ni se intenta compilar.
- Se retira una importación no utilizada en `jobs_screen.dart`.
- Se sustituye `value` por `initialValue` en tres `DropdownButtonFormField` para el SDK Flutter 3.41.1.
- Se ajustan condiciones sin llaves y se refactoriza la selección única para usar `RadioGroup` en Flutter 3.41.1.
- Se corrigen chequeos del `BuildContext` tras operaciones asíncronas en dos pantallas.
- Se aplica `const` en un componente estático de la pantalla de inicio.

## Validación en Windows

Abra la terminal desde la carpeta que contiene `pubspec.yaml` y ejecute:

```powershell
flutter pub get
flutter analyze
flutter test
```

Si Flutter muestra errores restantes, conserve la salida completa; no se ha ejecutado el SDK Flutter en el ambiente de preparación. Antes de probar el guardado de encuestas y solicitudes, instale y configure MySQL y el backend siguiendo `README.md`.

@echo off
REM Travesías Conecta: prueba en Chrome sin login externo.
cd /d "%~dp0"
where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter no esta en el PATH. Agrega la carpeta bin de Flutter al PATH.
  echo En PowerShell puedes usar:
  echo $env:Path = "C:\Users\USER\Documents\Flutter\flutter\bin;$env:Path"
  pause
  exit /b 1
)
flutter pub get
if errorlevel 1 (
  pause
  exit /b 1
)
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3000
pause

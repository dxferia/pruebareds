@echo off
where code >nul 2>&1
if errorlevel 1 (
  echo El comando code no esta disponible. Abre manualmente esta carpeta desde Visual Studio Code.
  pause
  exit /b 1
)
code .

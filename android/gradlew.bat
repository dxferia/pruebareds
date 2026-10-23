@echo off
setlocal EnableExtensions
set VERSION=8.10.2
if "%GRADLE_USER_HOME%"=="" (
  set "BASE=%USERPROFILE%\.gradle\travesias-wrapper"
) else (
  set "BASE=%GRADLE_USER_HOME%\travesias-wrapper"
)
set "DIST=%BASE%\gradle-%VERSION%"
set "ZIP=%BASE%\gradle-%VERSION%-bin.zip"
set "URL=https://services.gradle.org/distributions/gradle-%VERSION%-bin.zip"

if not exist "%DIST%\bin\gradle.bat" (
  if not exist "%BASE%" mkdir "%BASE%"
  if not exist "%ZIP%" (
    echo Descargando Gradle %VERSION%...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%ZIP%'"
    if errorlevel 1 exit /b 1
  )
  echo Preparando Gradle...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP%' -DestinationPath '%BASE%' -Force"
  if errorlevel 1 exit /b 1
)

call "%DIST%\bin\gradle.bat" %*
exit /b %ERRORLEVEL%

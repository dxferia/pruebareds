# Configura únicamente la conexión local sin guardar contraseñas en el ZIP.
# Ejecutar desde PowerShell en la carpeta backend:
# powershell -ExecutionPolicy Bypass -File .\CONFIGURAR_MYSQL_WINDOWS.ps1
$ErrorActionPreference = 'Stop'
$directorio = Split-Path -Parent $MyInvocation.MyCommand.Path
$ejemplo = Join-Path $directorio '.env.example'
$destino = Join-Path $directorio '.env'
if (!(Test-Path $ejemplo)) { throw 'No existe backend/.env.example' }
if (Test-Path $destino) {
  $reemplazar = Read-Host 'El archivo .env ya existe. ¿Deseas reemplazarlo? (S/N)'
  if ($reemplazar -ne 'S') { Write-Host 'No se han modificado tus credenciales.'; exit }
}
$claveSegura = Read-Host 'Contraseña de MySQL para root (no se mostrará)' -AsSecureString
$credencial = New-Object System.Management.Automation.PSCredential('root', $claveSegura)
$clave = $credencial.GetNetworkCredential().Password
if ([string]::IsNullOrEmpty($clave)) { throw 'La contraseña está vacía; operación cancelada.' }
if ($clave.Contains("`r") -or $clave.Contains("`n")) { throw 'La contraseña contiene caracteres no admitidos.' }
# Delimitar el valor para que caracteres como # no se interpreten como comentario.
$claveEnv = '"' + $clave.Replace('\','\\').Replace('"','\"') + '"'
$contenido = Get-Content -LiteralPath $ejemplo -Raw -Encoding UTF8
$contenido = $contenido.Replace('DB_PASSWORD=REEMPLAZAR_LOCALMENTE', 'DB_PASSWORD=' + $claveEnv)
$contenido = $contenido.Replace('DB_ADMIN_PASSWORD=REEMPLAZAR_LOCALMENTE', 'DB_ADMIN_PASSWORD=' + $claveEnv)
[System.IO.File]::WriteAllText($destino,$contenido,[System.Text.UTF8Encoding]::new($false))
Write-Host 'Creado backend/.env con servidor 172.27.30.205:3309 y base servicio_chamba (según .env.example).'
Write-Host 'La contraseña fue guardada SOLO en tu .env local; no la compartas ni subas a Git.'
Write-Host 'Siguiente comando: npm run db:check'

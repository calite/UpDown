param(
  [string]$Device = "chrome",
  [switch]$Release
)

$ErrorActionPreference = "Stop"

$envFile = ".env.web"
if (-not (Test-Path $envFile)) {
  Write-Error "No existe $envFile. Crea uno copiando .env.web.example"
}

$required = @(
  "FIREBASE_WEB_API_KEY",
  "FIREBASE_WEB_APP_ID",
  "FIREBASE_WEB_MESSAGING_SENDER_ID",
  "FIREBASE_WEB_PROJECT_ID",
  "FIREBASE_WEB_AUTH_DOMAIN",
  "FIREBASE_WEB_STORAGE_BUCKET"
)

$optional = @(
  "FIREBASE_WEB_MEASUREMENT_ID"
)

$values = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -eq "" -or $line.StartsWith("#")) {
    return
  }

  $parts = $line -split "=", 2
  if ($parts.Length -ne 2) {
    return
  }

  $key = $parts[0].Trim()
  $val = $parts[1].Trim()
  $values[$key] = $val
}

$missing = @()
foreach ($k in $required) {
  if (-not $values.ContainsKey($k) -or [string]::IsNullOrWhiteSpace($values[$k])) {
    $missing += $k
  }
}

if ($missing.Count -gt 0) {
  Write-Error "Faltan variables requeridas en ${envFile}: $($missing -join ', ')"
}

$args = @("run", "-d", $Device)
if ($Release) {
  $args += "--release"
}

foreach ($k in $required + $optional) {
  if ($values.ContainsKey($k) -and -not [string]::IsNullOrWhiteSpace($values[$k])) {
    $args += "--dart-define=$k=$($values[$k])"
  }
}

Write-Host "Ejecutando: flutter $($args -join ' ')"
flutter @args

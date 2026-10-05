<#
  launch-hardened.ps1 — arranque endurecido de Open Design (modo combo)
  -----------------------------------------------------------------------------
  Postura por defecto, PROTEGIDA:
    - Telemetria OFF (confirmado en el codigo, no inventado):
        * analytics.ts: sin POSTHOG_KEY => resolvePosthogConfig() = null =>
          el servicio de analytics es NOOP_SERVICE (no envia nada).
        * langfuse-trace.ts: sin OPEN_DESIGN_TELEMETRY_RELAY_URL / LANGFUSE_* =>
          no hay relay de trazas.
      Vaciamos esas variables por si quedaron en tu entorno de usuario.
    - Red: bind a loopback (no exponer en LAN).
    - NO seteamos las escotillas peligrosas (DISABLE_API_AUTH, danger-full-access).
    - Modo combo SIN persistir API keys cloud:
        * Local  = proveedor BYOK "ollama" -> http://127.0.0.1:11434 (keyless).
        * Fino   = binario `claude` (Claude Code) en PATH, con su propio auth.
      En ningun caso se pega una API key en la UI => .od/media-config.json
      no guarda secretos. El hallazgo R1 (key en texto plano) no aplica.

  USO:  .\hardening\launch-hardened.ps1   (desde la raiz del repo)
#>

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)   # raiz del repo

# --- Telemetria OFF (vaciar explicitamente) ---
$env:POSTHOG_KEY                     = ''
$env:POSTHOG_HOST                    = ''
$env:OPEN_DESIGN_TELEMETRY_RELAY_URL = ''
$env:OPEN_DESIGN_OBJECT_RELAY_URL    = ''
$env:LANGFUSE_PUBLIC_KEY             = ''
$env:LANGFUSE_SECRET_KEY             = ''
$env:OPEN_DESIGN_VELA_TELEMETRY      = ''

# --- Red: loopback ---
$env:OD_BIND_HOST = '127.0.0.1'

# --- Chequeos previos ---
Write-Host "== Pre-flight ==" -ForegroundColor Cyan

# Ollama (motor local keyless)
try {
    Invoke-WebRequest -UseBasicParsing http://127.0.0.1:11434/api/tags -TimeoutSec 3 | Out-Null
    Write-Host "  [OK] Ollama responde en 11434" -ForegroundColor Green
} catch {
    Write-Host "  [!] Ollama no responde — arrancalo:  ollama serve   (y: ollama pull qwen3:8b)" -ForegroundColor Yellow
}

# Claude Code (motor de fidelidad)
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "  [OK] Claude Code (claude) detectado en PATH" -ForegroundColor Green
} else {
    Write-Host "  [!] 'claude' no esta en PATH — solo vas a tener el motor local" -ForegroundColor Yellow
}

# Aviso si quedo alguna escotilla peligrosa activa en el entorno
foreach ($bad in 'OPEN_DESIGN_DISABLE_API_AUTH','OD_CODEX_SANDBOX') {
    $val = [Environment]::GetEnvironmentVariable($bad)
    if ($val) { Write-Host "  [RIESGO] $bad=$val esta seteada en tu entorno. Quitala." -ForegroundColor Red }
}

Write-Host "`n== Arrancando Open Design (loopback, telemetria off) ==" -ForegroundColor Cyan
corepack enable
corepack pnpm tools-dev run web

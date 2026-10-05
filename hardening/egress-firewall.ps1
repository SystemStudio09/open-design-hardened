<#
  egress-firewall.ps1 — contencion de red (defensa en profundidad)
  -----------------------------------------------------------------------------
  CONTEXTO HONESTO:
  En un build desde fuente, la telemetria ya nace apagada (sin POSTHOG_KEY ni
  relay URLs). Asi que este firewall es DEFENSA EN PROFUNDIDAD, no el unico
  control. Su objetivo: que, aunque algo intentara exfiltrar, no pueda salir.

  LIMITE REAL de Windows Firewall:
  Las reglas por-programa apuntan a un .exe. El daemon corre sobre node.exe,
  que es COMPARTIDO por muchas apps — bloquear node.exe en general romperia
  otras cosas. Por eso:
    - Si corres el daemon con un Node DEDICADO (via nvm/mise, ruta propia),
      pasa esa ruta con -NodePath y creamos una regla de bloqueo SOLO para ese
      binario.
    - El corte de egress REALMENTE hermetico se logra corriendo el daemon en
      WSL2 o en un contenedor con egress allowlist (ver README-HARDENED.md).
      Eso es el gold standard; esto es el complemento Windows-nativo.

  USO (como Administrador):
    .\hardening\egress-firewall.ps1                 # permite 'claude', imprime guia
    .\hardening\egress-firewall.ps1 -NodePath "C:\Users\vos\.nvm\...\node.exe"
    .\hardening\egress-firewall.ps1 -Remove         # quita las reglas creadas
#>

param(
    [string]$NodePath,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
$tagAllow = 'OpenDesign-ALLOW-claude'
$tagBlock = 'OpenDesign-BLOCK-daemon-egress'

if ($Remove) {
    Get-NetFirewallRule -DisplayName $tagAllow -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Get-NetFirewallRule -DisplayName $tagBlock -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Write-Host "Reglas removidas." -ForegroundColor Green
    return
}

# 1. Permitir explicitamente el motor de fidelidad (Claude Code -> Anthropic)
$claude = (Get-Command claude -ErrorAction SilentlyContinue)?.Source
if ($claude) {
    if (-not (Get-NetFirewallRule -DisplayName $tagAllow -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName $tagAllow -Direction Outbound -Action Allow `
            -Program $claude -Profile Any -Enabled True | Out-Null
        Write-Host "[OK] Allow-egress para Claude Code: $claude" -ForegroundColor Green
    } else { Write-Host "[=] Regla allow de claude ya existe" -ForegroundColor DarkGray }
} else {
    Write-Host "[!] 'claude' no encontrado en PATH; sin regla allow (modo solo-local)" -ForegroundColor Yellow
}

# 2. (Opcional) Bloquear egress del Node dedicado del daemon
if ($NodePath) {
    if (-not (Test-Path $NodePath)) { throw "NodePath no existe: $NodePath" }
    # Nota: el trafico a 127.0.0.1 (Ollama) esta exento del filtrado => sigue andando.
    New-NetFirewallRule -DisplayName $tagBlock -Direction Outbound -Action Block `
        -Program $NodePath -Profile Any -Enabled True | Out-Null
    Write-Host "[OK] Block-egress para el daemon Node: $NodePath" -ForegroundColor Green
    Write-Host "    (Ollama en loopback sigue funcionando; se corta la salida a internet)" -ForegroundColor DarkGray
} else {
    Write-Host "`n[i] Sin -NodePath no se bloquea el daemon (evitamos romper node.exe compartido)." -ForegroundColor Yellow
    Write-Host "    Corte hermetico recomendado: corre el daemon en WSL2/contenedor con" -ForegroundColor Yellow
    Write-Host "    egress allowlist. Detalle en README-HARDENED.md -> 'Contencion de egress'." -ForegroundColor Yellow
}

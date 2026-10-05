# SECURITY-HARDENING.md

> Registro del endurecimiento (hardening) de este fork privado de
> `nexu-io/open-design`. Versionado en el repo para trazabilidad. Cada cambio de
> seguridad se anota aca.

- **Fork base:** `nexu-io/open-design` (Apache-2.0)
- **Commit upstream fijado:** `89e64d813bb1c7a11519b3f668f011f7017637d7` — tag `open-design-v0.24.1` (release estable)
- **Repo privado destino:** `System-Studio/open-design-hardened`
- **Perfil de uso:** **combo** — Ollama local (Qwen3) + Claude Code para fidelidad
- **Entorno:** Windows · 16 GB RAM · NVIDIA RTX 2060 (CUDA)

---

## 1. Threat model (resumen de la auditoria)

El upstream tiene buena base de seguridad (SSRF guard con defensa anti
DNS-rebinding, redaccion de secretos en logs, pinning defensivo de dependencias,
piso de auth para exposicion en red). Riesgos residuales y su estado en ESTE fork:

| # | Riesgo | Severidad | Estado en el fork |
|---|--------|-----------|-------------------|
| R1 | API keys BYOK en texto plano en `.od/media-config.json` | Medio | **No aplica en modo combo** — no se pega ninguna key cloud (ver P3) |
| R2 | Daemon lee auth de otras tools (`~/.codex`, `~/.hermes`) | Medio | Irrelevante en combo; opcional gatearlo (P4) |
| R3 | Telemetria "scrubbed" | Medio (privacidad) | **OFF por postura** (P2) + egress (P1) |
| R4 | Escotillas peligrosas (`DISABLE_API_AUTH`, `danger-full-access`) | Bajo | Nunca seteadas; launcher avisa (P4) |
| R5 | Daemon spawnea CLIs (superficie de ejecucion) | Arquitectonico | Contencion (P1) |
| R6 | Supply chain (deps / lockfile) | Bajo | Pin + `pnpm audit` (P5) |

**Insight:** en modo combo, los dos caminos de modelo son **sin secreto cloud en
disco** (Ollama es keyless; Claude Code usa su propio auth). Eso vacia R1 de
superficie. Los controles dominantes pasan a ser **P1 (contencion/egress)** y
**P2 (telemetria off)**.

---

## 2. Prioridades (orden de aplicacion)

1. **P1 — Contencion de egress** (operacional)
2. **P2 — Telemetria off** (postura de config — sin parche de codigo)
3. **P3 — Credenciales at-rest** (solo relevante si algun dia usas BYOK cloud)
4. **P4 — Escotillas + lectura de auth ajeno** (postura + parche opcional)
5. **P5 — Supply chain: pin + escaneo + strip CI** (repo)

---

## P1 — Contencion de egress

**Objetivo:** que el daemon no pueda sacar datos a internet. En combo puro-local
el corte es total (solo loopback a Ollama); con Claude Code, se permite la salida
de `claude` y nada mas.

- **Windows-nativo (parcial):** `hardening/egress-firewall.ps1`. El trafico a
  `127.0.0.1:11434` (Ollama) esta exento del filtrado, asi que las reglas de
  bloqueo no lo cortan. Permite `claude`; con `-NodePath` bloquea el Node dedicado
  del daemon.
- **Hermetico (recomendado):** daemon en **WSL2 o contenedor** con egress
  allowlist. Unico corte realmente hermetico; las reglas por-exe sobre el node.exe
  compartido de Windows son coarse.

---

## P2 — Telemetria off (CONFIRMADO en codigo, sin parche)

Verificado en el fuente del daemon:

- **PostHog** (`apps/daemon/src/analytics.ts`): `resolvePosthogConfig()` hace
  `if (!env.POSTHOG_KEY?.trim()) return null;` y entonces el servicio es
  `NOOP_SERVICE`. **Sin `POSTHOG_KEY`, no se envia nada.** Ademas esta
  consent-gated (`appCfg.telemetry?.metrics !== true` => no-op).
- **Langfuse / relays** (`langfuse-trace.ts`, `integrations/diagnostic-relay.ts`):
  gatean en `OPEN_DESIGN_TELEMETRY_RELAY_URL` / `OPEN_DESIGN_OBJECT_RELAY_URL` /
  `LANGFUSE_PUBLIC_KEY`. Sin esas vars, no hay relay.

**Accion:** el launcher (`hardening/launch-hardened.ps1`) vacia explicitamente
`POSTHOG_KEY`, `POSTHOG_HOST`, `OPEN_DESIGN_TELEMETRY_RELAY_URL`,
`OPEN_DESIGN_OBJECT_RELAY_URL`, `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`,
`OPEN_DESIGN_VELA_TELEMETRY`. No se requiere editar codigo.

> En un build desde fuente, estas vars no vienen seteadas por defecto: la
> telemetria ya nace apagada. El vaciado explicito es el cinturon ademas del tirante.

---

## P3 — Credenciales at-rest (solo si usas BYOK cloud)

En modo combo **no aplica** (sin key cloud en disco). Si algun dia configuras un
proveedor cloud por API key:

- Preferir **variable de entorno** sobre pegarla en la UI. El codigo
  (`media/config.ts`) le da precedencia al env y, con env presente, NO persiste la
  key (`seedProviderIfMissing` hace no-op si `readEnvKey` devuelve algo).
- En Windows, guardar la key con **DPAPI** y descifrarla a env var solo para el
  proceso (ver el patron en el README de la conversacion / launcher comentado).
- Reducir blast radius: **key dedicada + spend cap + rotacion**.
- Backstop si igual la persistis: parche de cifrado at-rest (safeStorage /
  AES-256-GCM) + BitLocker + ACL en `.od/`. `.od` ya esta en `.gitignore`.

---

## P4 — Escotillas + auth ajeno

- **Escotillas:** el fork **no setea** `OPEN_DESIGN_DISABLE_API_AUTH` ni
  `OD_CODEX_SANDBOX=danger-full-access`. El launcher avisa en rojo si quedaron en
  tu entorno. (Opcional: parche en `server.ts` para ignorarlas por completo.)
- **Auth ajeno (R2):** irrelevante en combo. Opcional: gatear la lectura de
  `~/.codex/auth.json` / `~/.hermes/auth.json` tras un flag off por defecto.

---

## P5 — Supply chain

- **Pin:** `open-design-v0.24.1` (`89e64d8`). Nunca `main` movil.
- **Escaneo** antes de confiar:
  ```
  corepack pnpm install --frozen-lockfile
  corepack pnpm audit --audit-level=high
  # opcional: osv-scanner --lockfile=pnpm-lock.yaml
  ```
- **Mantener del upstream** (no remover): `pnpm.onlyBuiltDependencies` (allowlist
  de build scripts) y `pnpm.overrides` (pins de paquetes vuln-prone).
- **Strip de CI:** en el mirror privado, borrar los workflows innecesarios de
  `.github/workflows/` (elimina de paso el tema `pull_request_target + checkout`,
  clasificado POTENCIAL en la auditoria).
- **Branch protection** en `main` del repo privado.

---

## Checklist de validacion final

- [ ] Commit `89e64d8` (tag v0.24.1) fijado y anotado
- [ ] Mirror privado creado; `upstream` + `origin` configurados
- [ ] P1 — egress contenido (firewall Windows o WSL2) y verificado
- [ ] P2 — telemetria vaciada por el launcher (sin POSTHOG_KEY / relays)
- [ ] P3 — N/A en combo (sin key cloud en disco)
- [ ] P4 — sin escotillas; launcher no reporta warnings en rojo
- [ ] P5 — `pnpm audit` limpio; CI innecesario removido; branch protection on
- [ ] Build local OK (`corepack enable && pnpm install && pnpm tools-dev run web`)
- [ ] Ollama (qwen3) responde y una generacion de prueba funciona
- [ ] Sin conexiones salientes fuera de loopback/`claude` durante una corrida

---

## Actualizar desde upstream (rebase manual)

```
git fetch upstream --tags
git log --oneline HEAD..upstream/main      # revisar que cambio ANTES de traer
git rebase <nuevo-tag-estable-auditado>
# re-aplicar/verificar el overlay si upstream toco los mismos archivos
corepack pnpm audit --audit-level=high
git push origin main
```

> Nunca rebasar a ciegas. Revisar el diff, re-escanear y re-validar el checklist
> antes de volver a usar.

---

## Historial de cambios de seguridad

| Fecha | Cambio | Autor |
|-------|--------|-------|
| _(completar)_ | Overlay inicial de hardening sobre v0.24.1 | System Studio |

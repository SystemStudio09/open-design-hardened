# open-design-hardened

Fork privado y **endurecido** de [`nexu-io/open-design`](https://github.com/nexu-io/open-design),
preparado para uso seguro en el ecosistema propio. No es el repo original: es una
base controlada sobre un commit auditado, con una postura de seguridad por
defecto. El registro completo de cambios de seguridad esta en
[`SECURITY-HARDENING.md`](./SECURITY-HARDENING.md).

- **Base upstream:** `open-design-v0.24.1` (commit `89e64d8`) — release estable, fijado.
- **Licencia:** Apache-2.0 (heredada del upstream).
- **Modo por defecto:** **combo** — Ollama local (gratis, privado) + Claude Code (fidelidad).

---

## Por que este fork

El upstream esta, en general, bien construido en seguridad (guard anti-SSRF con
defensa contra DNS-rebinding, redaccion de secretos en logs, pinning defensivo de
dependencias, piso de auth para exposicion en red). Este fork no "arregla" un repo
inseguro: fija una **postura protegida por defecto** y agrega contencion, para no
depender de que el usuario recuerde configurar bien cada vez.

Lo que cambia respecto del upstream:

1. **Pin a release auditado** (no `main` movil).
2. **Telemetria OFF por postura.** Confirmado en el codigo: sin `POSTHOG_KEY`,
   `analytics.ts` usa un `NOOP_SERVICE` (no envia nada); sin
   `OPEN_DESIGN_TELEMETRY_RELAY_URL` / `LANGFUSE_*` no hay relay de trazas. El
   launcher vacia esas variables explicitamente.
3. **Launcher endurecido** (`hardening/launch-hardened.ps1`): bind loopback, sin
   persistir API keys, telemetria vaciada, chequeos pre-flight.
4. **Egress firewall** (`hardening/egress-firewall.ps1`): defensa en profundidad.
5. **Sin escotillas peligrosas.** El fork nunca setea `OPEN_DESIGN_DISABLE_API_AUTH`
   ni `OD_CODEX_SANDBOX=danger-full-access`; el launcher avisa si quedaron en tu entorno.

---

## Modo combo (recomendado)

La jugada: iterar gratis en local, y pasar a Claude Code solo para el pulido fino.
**Ninguno de los dos caminos pega una API key cloud en la UI**, asi que no se
guardan secretos en `.od/media-config.json`.

- **Motor local (iteracion, gratis, cero egress):** Ollama con Qwen3.
  ```
  ollama serve
  ollama pull qwen3:8b      # en RTX 2060 6GB corre con offload parcial a RAM
  # fallback rapido: ollama pull qwen3:4b
  ```
  En la UI, elegi el proveedor **Ollama** apuntando a `http://127.0.0.1:11434`
  (sin API key — Ollama es keyless).

- **Motor de fidelidad (pulido final):** Claude Code. Tene el binario `claude`
  en el PATH; el daemon lo detecta solo. Usa su propio auth (no pegas key).
  Consume tu cuota de Claude, asi que usalo para las pasadas finas, no para iterar.

> El ultimo tramo de diseño fino "a pixel" sigue siendo tu criterio — el upstream
> lo dice y es verdad. Un motor fuerte te deja arrancando desde el 90%, no al 60%.

---

## Como arrancar

Requisitos: Node ~24, git, corepack (viene con Node). En Windows:

```powershell
corepack enable
.\hardening\launch-hardened.ps1
```

El launcher imprime la URL local (tipo `http://localhost:3000`). Abrila en el browser.

---

## Contencion de egress (opcional pero recomendado)

La telemetria ya nace apagada desde fuente, asi que el firewall es defensa en
profundidad. Dos niveles:

- **Windows-nativo (parcial):** `./hardening/egress-firewall.ps1` (como admin).
  Permite `claude` y, si le pasas `-NodePath` al Node dedicado del daemon, bloquea
  su salida a internet (Ollama en loopback sigue andando).
- **Hermetico (gold standard):** corre el daemon en **WSL2 o un contenedor** con
  egress allowlist (solo loopback a Ollama, y el host de tu proveedor si usas
  cloud). Es el unico corte realmente hermetico; las reglas por-exe sobre el
  node.exe compartido de Windows son coarse.

---

## Checklist de validacion

- [ ] Clonado desde `bootstrap-hardened-fork.ps1` (pin `open-design-v0.24.1`)
- [ ] `git remote -v` muestra `upstream` (original) y `origin` (tu repo privado)
- [ ] Arranca con `launch-hardened.ps1` sin warnings de escotillas
- [ ] Ollama responde y `claude` detectado
- [ ] Ninguna API key cloud guardada en `.od/media-config.json`
- [ ] (Opcional) `pnpm audit --audit-level=high` limpio
- [ ] (Opcional) egress contenido (firewall o WSL2)

---

## Actualizar desde upstream (rebase manual)

Este fork es un mirror privado (no tiene el boton "Sync" de GitHub). Para traer
parches de seguridad del original, ver la seccion correspondiente en
[`SECURITY-HARDENING.md`](./SECURITY-HARDENING.md). Regla de oro: nunca rebasar a
ciegas — revisar el diff de upstream, re-correr `pnpm audit` y re-validar el
checklist antes de volver a usar.

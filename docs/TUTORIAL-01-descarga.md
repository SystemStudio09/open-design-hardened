# Tutorial 01 — Descarga del fork (clone fijado) · Windows

> Material de referencia del ecosistema. Documenta la **Fase 1** de la
> construccion del fork endurecido de Open Design: bajar el codigo fijado a un
> release auditado, en Windows, con los errores reales que aparecen y como se
> resuelven. Reproducible paso a paso.

- **Objetivo de esta fase:** descargar (clonar) el repo fijado — **sin instalar
  ni ejecutar nada**.
- **Base upstream:** `nexu-io/open-design`
- **Pin:** tag `open-design-v0.24.1` → commit `89e64d8`
- **Entorno:** Windows + PowerShell
- **Ruta de trabajo usada:** `D:\Proyectos\Claude\Instalacion-de-Proyectos`

---

## 0. Concepto clave antes de empezar

La "descarga" acá **no** es el `git clone` crudo de la guia de Enrique Rocha (que
baja `main` movil). Es un clone **fijado** (pinned) al release auditado. Mismo
paso, pero apuntando a una version estable y revisada, que es lo que corresponde
para una base de produccion.

Toda la Fase 1 es **inofensiva**: solo baja archivos y verifica. No instala
dependencias, no ejecuta el proyecto, no toca GitHub, no pide credenciales.

---

## 1. Decision de ruta (leccion aprendida)

Open Design es un **monorepo** (muchos paquetes anidados) que se instala con pnpm.
Eso genera rutas de archivo muy profundas. Windows tiene un limite historico de
**260 caracteres (MAX_PATH)**. Por eso, al elegir donde clonar:

- ❌ **Evitar rutas largas** (muchas carpetas anidadas) → riesgo de "path too long"
  en el `pnpm install`.
- ❌ **Evitar espacios** en la ruta ("Open Design", "Proyectos por consola") →
  obligan a comillas en cada comando y marean a algunas tools de Node.
- ✅ **Corta y sin espacios.** Guiones (`-`) estan OK.

En este caso se corrigio de una ruta larga con espacios a:
`D:\Proyectos\Claude\Instalacion-de-Proyectos` (sin espacios, corta).

> **Importante:** se crea solo la **carpeta contenedora**. La carpeta del repo
> (`open-design-hardened`) **la crea sola el `git clone`**. Si la creas a mano, el
> clone falla por "directorio no vacio".

Estructura final esperada:

```
D:\Proyectos\Claude\Instalacion-de-Proyectos\      <- contenedor (lo creas vos)
        └── open-design-hardened\                  <- lo crea git clone
```

---

## 2. Abrir la terminal

- `Win + X` → **Terminal** (o **Windows PowerShell**), o
- Explorador → entrar a la carpeta → **Shift + clic derecho** → **"Abrir en
  Terminal"** (arranca parado adentro).

---

## 3. Pasos

### Paso 1 — Confirmar git

```powershell
git --version
```

Si no lo reconoce: instalar **Git for Windows** desde `git-scm.com`, reabrir la
terminal.

### Paso 2 — Crear el contenedor y pararse adentro

```powershell
New-Item -ItemType Directory -Force -Path "D:\Proyectos\Claude\Instalacion-de-Proyectos"
cd "D:\Proyectos\Claude\Instalacion-de-Proyectos"
pwd    # debe imprimir la ruta de arriba
```

### Paso 3 — Red de seguridad para rutas largas

```powershell
git config --global core.longpaths true
```

No imprime nada (es normal). Previene errores de path largo en el `pnpm install`
posterior.

### Paso 4 — Clonar FIJADO al release auditado (la descarga en si)

```powershell
git clone --branch open-design-v0.24.1 --depth 1 https://github.com/nexu-io/open-design.git open-design-hardened
```

Desglose:
- `git clone` → descargar una copia del repo.
- `--branch open-design-v0.24.1` → fija el release auditado (no `main` movil).
- `--depth 1` → baja solo el estado actual (shallow clone, mas rapido/liviano).
- `https://github.com/nexu-io/open-design.git` → origen.
- `open-design-hardened` → carpeta destino.

Qué hace: **solo baja archivos**. No instala, no ejecuta, no toca tu GitHub.
Tarda un rato ("Receiving objects…") — es un monorepo grande. Termino cuando
vuelve el cursor y ves algo como `Updating files: 100% (12917/12917), done.`

### Paso 5 — Entrar al repo y crear la rama de trabajo

```powershell
cd open-design-hardened
pwd                 # el prompt debe terminar en ...\open-design-hardened
git switch -c main  # crea tu rama 'main' sobre el commit fijado
```

### Paso 6 — Verificar

```powershell
git log --oneline -1   # debe empezar con 89e64d8 (release v0.24.1)
dir                    # deben verse apps, packages, design-systems, skills, package.json...
```

Si el commit arranca con `89e64d8`, **la descarga esta OK**.

---

## 4. Errores reales que aparecieron (y su solucion)

### 4.1 "You are in 'detached HEAD' state"

- **Cuando:** al terminar el `git clone --branch <tag>`.
- **Es un error?** NO. Es un **aviso esperado**: al clonar fijado a un *tag* (no a
  una rama), git te deja parado sobre un commit puntual. Es justo lo que queremos
  (pin al release auditado).
- **Solucion:** crear tu rama encima — `git switch -c main` (Paso 5). Eso sale del
  detached HEAD y te deja en `main`.

### 4.2 "fatal: not a git repository (or any of the parent directories): .git"

- **Cuando:** al correr `git switch -c main`.
- **Causa:** estabas parado en la **carpeta contenedora**
  (`...\Instalacion-de-Proyectos`), no dentro del repo. El `.git` vive una carpeta
  mas adentro, en `open-design-hardened`.
- **Solucion:** entrar al repo primero — `cd open-design-hardened` — y recien ahi
  correr `git switch -c main`.
- **Como detectarlo rapido:** mira el prompt. Si no termina en
  `...\open-design-hardened>`, no estas adentro del repo. `pwd` lo confirma.

---

## 5. Checklist de cierre de Fase 1

- [ ] `git --version` responde
- [ ] Contenedor creado, ruta corta y sin espacios
- [ ] `core.longpaths` en true
- [ ] `git clone --branch open-design-v0.24.1 --depth 1` termino sin error
- [ ] `cd open-design-hardened` + `git switch -c main` → en rama `main`
- [ ] `git log --oneline -1` empieza con `89e64d8`
- [ ] `dir` muestra la estructura del proyecto

---

## 6. Que sigue — Fase 2 (hardening)

Con la descarga cerrada, lo que viene (documentado aparte) es:

1. Configurar remotes: `upstream` (original) + `origin` (tu repo privado).
2. Aplicar el overlay de hardening (`README-HARDENED.md`, `SECURITY-HARDENING.md`,
   `hardening/launch-hardened.ps1`, `hardening/egress-firewall.ps1`).
3. Commit del hardening y push al repo privado.
4. Setup del modo combo (Ollama local + Claude Code) y arranque con el launcher.

> Nota: la Fase 2 se puede hacer a mano (paso a paso) o automatizada con
> `bootstrap-hardened-fork.ps1`. Como aca ya clonaste a mano, en la Fase 2
> seguimos desde este mismo repo (remotes + overlay), sin volver a clonar.

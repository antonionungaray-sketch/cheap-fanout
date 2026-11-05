# Codex CLI — segundo presupuesto (suscripción ChatGPT)

> Material de referencia del skill `cheap-fanout`, extraído del `SKILL.md` el 2026-10-01 para no
> cargarlo en cada invocación. Ábrelo cuando un job `codex` falle, para elegir modelo por cuota, o para el sandbox de Linux.

`codex exec` corre **no-interactivo con el login de ChatGPT** (sin API key). En `jobs.tsv` usa
`codex` (modelo default) o `codex:<model>`; el helper lo lanza como
`codex exec --skip-git-repo-check --ephemeral -s read-only -o out_file` (y `-C <dir>` si pasaste
`--dir`). Releído el **2026-11-05**: la estable es **0.166.0** y **es la que ya estaba instalada aquí**
cuando lo revisé (npm global bajo nvm; el symlink es del 2026-11-05 14:50 hora local; no la instalé yo;
antes: 0.159.3 desde el 2026-10-01). Entre 0.159.3 y 0.166.0 el changelog no trae rupturas para
`codex exec` (los flags `-m`, `-s`, `-C`, `--skip-git-repo-check`, `--ephemeral` y `-o` siguen en
`--help`). Sí trae: `gpt-6.1-sol` es el default del catálogo incluido (0.161.0), `gpt-6.1-terra`
entró a los catálogos (0.165.0), el sandbox de Linux arranca mejor con varios archivos denegados
(0.162.0) y los reintentos respetan el `Retry-After` del servidor (0.161.0).

- **Modelos disponibles con login ChatGPT** (`developers.openai.com/codex/models`, 2026-11-05):
  `gpt-6-astra`, `gpt-6.1-sol` (contexto por defecto de 500K), `gpt-6.1-terra` (**nuevo**: exige
  Codex ≥ 0.159.0; "rápido y eficiente para escritura, visión y uso de computadora") y `gpt-6-luna`.
  `gpt-6-sol` ya no aparece entre los recomendados aunque la tabla de límites aún lo lista.
  **Retirados:** GPT-5.5 (2026-10-14), GPT-5.3-Codex-Spark (2026-09-14) y GPT-5.4 (2026-08-31).
  Historia: con 0.157.1 `gpt-6.1-sol` fallaba con *"not supported when using Codex with a ChatGPT
  account"* y *"Model metadata … not found"* porque entró al catálogo en la 0.159.1.
- **El modelo default de `codex` sale de `~/.codex/config.toml`**, hoy **`gpt-6-luna` con
  `model_reasoning_effort = "high"`** (el 2026-10-01 era `gpt-6-astra` con `xhigh`; alguien lo
  cambió). Un job `codex` pelado usa entonces Luna, el más barato de la cuota. Cuotas en Plus
  (mensajes por 5h, estimaciones de OpenAI del 2026-11-05; Pro no tiene límite de 5h y pueden aplicar
  límites semanales): Astra **5-45**, 6.1 Sol **15-160**, 6.1 Terra **35-285**, 6 Sol 15-150, Luna
  **350-3,000**. Pide el modelo explícito en el job: `codex:gpt-6.1-sol`, `codex:gpt-6-luna`.
- **Calidad (AA v5.0.1, por esfuerzo, de high a max):** `gpt-6-astra` 55-57 · `gpt-6.1-sol` 50-55
  (xhigh 52) · `gpt-6.1-terra` 42-51 · `gpt-6-luna` 21-28. El Coding Agent Index en Codex de la v4.3.2
  (astra 62, sol 57, luna 41) no se releyó. OpenAI dice que 6.1 Sol "casi iguala a Astra" a menor
  costo. Es la opción casi-frontier que **no gasta tokens de Anthropic ni cuota Go**.
- **Para qué:** el asiento casi-frontier (`gpt-6.1-sol`), y código/mecánico cuando la cuota Go
  escasea (`gpt-6-luna`). `gpt-6-luna` también está EN el pool Go (4,230 req/5h, límite 15): codex
  no suma un modelo, suma **cuota** aparte.
- **Para qué NO:** investigación web (`codex exec` no trae web search) — eso siempre a opencode.
- **Sandbox de Linux — arreglado el 2026-10-01.** Hasta ese día `bwrap` fallaba aquí con
  `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted` y **ni en `read-only` podía un job
  codex abrir un archivo** (0/84 en la extracción; en `workspace-write` tampoco escribía). Causa:
  Ubuntu 24.04 trae `kernel.apparmor_restrict_unprivileged_userns=1` y bubblewrap no podía crear
  su namespace. Actualizar a 0.159.3 **no** lo arregló (su `bwrap` empaquetado exige el mismo
  permiso). Lo resolvió el procedimiento oficial de OpenAI (`developers.openai.com/codex/sandboxing`, que hoy redirige a
  `learn.chatgpt.com/docs/sandboxing`; releído el 2026-10-01: los comandos coinciden),
  que el usuario ejecutó con sudo:
  ```
  sudo apt update
  sudo apt install apparmor-profiles apparmor-utils
  sudo install -m 0644 /usr/share/apparmor/extra-profiles/bwrap-userns-restrict \
       /etc/apparmor.d/bwrap-userns-restrict
  sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
  ```
  Concede user namespaces **solo a `/usr/bin/bwrap`**; la restricción global del sistema sigue
  activa (no uses `sysctl kernel.apparmor_restrict_unprivileged_userns=0`: la apaga para todos los
  programas). Persiste al reiniciar. **Verificado después** (`bwrap --unshare-all --ro-bind / / true`
  da OK): `read-only` lee archivos (84/84 con `codex:gpt-6.1-sol` y `codex:gpt-6-luna`);
  `workspace-write` escribe dentro del directorio del job; y **la contención sigue intacta**:
  `read-only` no deja escribir (archivo no creado, el modelo responde que está bloqueado) y
  `workspace-write` no deja salirse del directorio (un `../archivo` no se creó). Reversión:
  `sudo apparmor_parser -R /etc/apparmor.d/bwrap-userns-restrict && sudo rm /etc/apparmor.d/bwrap-userns-restrict`.
  - Los jobs codex que **editan** usan `CHEAP_FANOUT_CODEX_SANDBOX=workspace-write` con `--dir` a un
    worktree git aislado; revisa el diff antes de mergear (el sandbox contiene el filesystem, no
    juzga si lo escrito es correcto).
  - `danger-full-access` ya no hace falta. Queda solo como último recurso en una máquina Ubuntu
    24.04 **sin** ese perfil (y entonces, solo en un directorio aislado: sin barrera de filesystem).
- **Reverificado el 2026-11-05 con 0.166.0:** `bwrap --unshare-all --ro-bind / / true` da OK (el
  perfil de AppArmor sigue cargado) y `codex:gpt-6-luna`, `codex:gpt-6.1-sol` y `codex:gpt-6.1-terra`
  leyeron por el helper, en `read-only`, el archivo de ~6K tokens y devolvieron los 84 valores bien:
  **84/84 en 20-24s** (Luna 23-24s, Sol 21-22s, Terra 20s). Como asiento del consejo (prompt-only):
  Sol 60s y Terra 23s; ver `cheap-fanout-ultimate`.
- **Luna por dos puertas:** `gpt-6-luna` → `opencode run` → cuota **Go**; `codex:gpt-6-luna` →
  `codex exec` → cuota **ChatGPT**. Mismo modelo, presupuestos independientes; un mismo lote puede
  mezclar ambas. Regla: el ancho con Luna va por **Go**; `codex` es desborde. Reintento típico:
  los jobs con `.status`≠0 por cuota se relanzan cambiando solo el campo `model` a `codex:`.

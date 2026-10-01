# Codex CLI — segundo presupuesto (suscripción ChatGPT)

> Material de referencia del skill `cheap-fanout`, extraído del `SKILL.md` el 2026-10-01 para no
> cargarlo en cada invocación. Ábrelo cuando un job `codex` falle, para elegir modelo por cuota, o para el sandbox de Linux.

`codex exec` corre **no-interactivo con el login de ChatGPT** (sin API key). En `jobs.tsv` usa
`codex` (modelo default) o `codex:<model>`; el helper lo lanza como
`codex exec --skip-git-repo-check --ephemeral -s read-only -o out_file` (y `-C <dir>` si pasaste
`--dir`). Releído el **2026-10-01**: la estable es **0.159.3** (2026-09-30) y **es la que quedó
instalada aquí ese día** (`npm install -g @openai/codex@0.159.3` bajo nvm, en espacio de usuario, sin
sudo; antes: 0.157.1).

- **Modelos disponibles con login ChatGPT** (`developers.openai.com/codex/models`, 2026-10-01):
  `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6-sol`, `gpt-6-luna`. **GPT-5.5 se retira de Codex el
  2026-10-14** en todos los planes; GPT-5.4 y 5.3-Codex-Spark ya se retiraron. Con
  `0.157.1` respondieron PONG `gpt-6-astra`, `gpt-6-sol`, `gpt-6-luna`, `gpt-5.6-luna` y el oculto
  `gpt-reserve` (3-4s los que cronometré), pero **`gpt-6.1-sol` falló** con *"not supported when
  using Codex with a ChatGPT account"* y *"Model metadata … not found"*: el modelo entró al
  catálogo en la 0.159.1. **Tras actualizar a 0.159.3, `codex:gpt-6.1-sol` y el `codex` default
  responden PONG por el helper** (verificado 2026-10-01).
- **El modelo default de `codex` sale de `~/.codex/config.toml`**, hoy `gpt-6-astra` con
  `model_reasoning_effort = "xhigh"` (antes `gpt-5.5`). Es el más caro de la cuota: **5-45
  mensajes/5h en Plus** contra 15-160 de `gpt-6.1-sol`, 15-150 de `gpt-6-sol` y 350-3,000 de
  `gpt-6-luna` (estimaciones de OpenAI para Plus/Business Standard; Pro no tiene límite de 5h).
  Pide el modelo explícito en el job: `codex:gpt-6.1-sol`, `codex:gpt-6-luna`.
- **Calidad (AA v4.3.2):** `gpt-6-astra` 53 · `gpt-6.1-sol` 52 · `gpt-6-sol` 48 · `gpt-6-luna` 37;
  Coding Agent Index en Codex: astra 62, sol 57, luna 41. OpenAI dice que 6.1 Sol "casi iguala a
  Astra en coding agentic a un quinto del precio" y AA lo confirma (52 vs 53). Es la opción
  casi-frontier que **no gasta tokens de Anthropic ni cuota Go**.
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
- **Luna por dos puertas:** `gpt-6-luna` → `opencode run` → cuota **Go**; `codex:gpt-6-luna` →
  `codex exec` → cuota **ChatGPT**. Mismo modelo, presupuestos independientes; un mismo lote puede
  mezclar ambas. Regla: el ancho con Luna va por **Go**; `codex` es desborde. Reintento típico:
  los jobs con `.status`≠0 por cuota se relanzan cambiando solo el campo `model` a `codex:`.

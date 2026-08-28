# cheap-fanout — Spec portable: orquestación frontier + agentes baratos

> **Un solo archivo, autocontenido.** Cópialo a cualquier computadora con OpenCode CLI (y,
> opcionalmente, Claude Code) y sigue los pasos. Incluye el helper completo embebido — no
> necesitas ningún otro archivo. Última verificación de datos: **2026-07-14**.

---

## 1. La idea

Combinar **un modelo de avanzada (frontier) como orquestador** con **muchos modelos baratos
como ejecutores**. El caro piensa una vez y revisa; los baratos absorben el trabajo ancho.

- **Orquestador (frontier):** Claude Code (Opus), otro CLI frontier, **o tú mismo**. Hace lo
  único que un modelo barato NO hace bien: **planear, rutear y revisar/sintetizar**.
- **Ejecutores (baratos):** agentes de **OpenCode Go** (~$10/mes: DeepSeek, Qwen, Kimi, GLM,
  MiniMax, MiMo) disparados **en paralelo**. Cuestan centavos y tienen cuota enorme.

**Cuándo conviene:** trabajo *ancho y superficial* — muchas unidades independientes sin
razonamiento frontier por unidad:
- **Investigación web** (leer/resumir muchas páginas/fuentes en paralelo),
- **ediciones mecánicas en lote** (mismo cambio acotado en muchos archivos),
- **búsqueda/auditoría amplia** (barrer muchos módulos por un patrón).

**Cuándo NO:** razonamiento frontier por unidad (arquitectura, seguridad, semántica delicada),
una sola tarea secuencial profunda, o cuando un resultado barato malo sea caro de detectar y no
lo vas a revisar.

**Regla de oro del ahorro:** los tokens del modelo caro se gastan en **planear + revisar +
sintetizar**, NUNCA en el ancho. Si te sorprendes a punto de lanzar muchos subagentes *caros*
para búsqueda/lote → para y usa este flujo.

---

## 2. Requisitos en la otra computadora

| Requisito | Para qué | Verificar |
|-----------|----------|-----------|
| **OpenCode CLI** ≥ 1.18 | correr los agentes baratos | `opencode --version` |
| **Auth de OpenCode Go** | acceso al plan barato (Zen Go) | ver §3.2 |
| **bash + python3** | el helper y generar prompts/jobs | `bash --version && python3 --version` |
| Orquestador frontier *(opcional)* | Claude Code, otro CLI, o tú | — |
| Codex CLI + login ChatGPT *(opcional)* | jobs `codex` = segundo presupuesto, aparte de Go | `codex --version && codex exec --skip-git-repo-check --ephemeral -s read-only "di OK"` |
| Suscripción Kimi For Coding *(opcional)* | subteniente K3 que pre-revisa el lote | credencial `kimi-for-coding` en `auth.json` (o `KIMI_API_KEY`); `opencode run -m kimi-for-coding/k3 "di OK"` |

---

## 3. Instalación (paso a paso)

### 3.1 OpenCode CLI
```bash
curl -fsSL https://opencode.ai/install | bash      # instalador oficial
# o: npm i -g opencode-ai
opencode --version                                  # confirma ≥ 1.18
```

### 3.2 Autenticar OpenCode Go
El CLI guarda la credencial en `~/.local/share/opencode/auth.json` con esta forma:
```json
{ "opencode-go": { "key": "<TU_API_KEY_DE_OPENCODE_GO>" } }
```
Dos maneras de ponerla en la máquina nueva:
- **Copiar** ese `auth.json` desde una máquina que ya funciona (misma cuenta), **o**
- Correr `opencode auth login` y elegir el proveedor de OpenCode Zen / Go, pegando tu key.

> Presupuesto compartido del plan Go: ~$12/5h, $30/sem, $60/mes. La cuota se mide en
> **requests por ventana de 5h** (ver §6).

### 3.3 Smoke test (confirma que jala)
```bash
opencode run --auto -m opencode-go/deepseek-v4-flash "responde solo con la palabra: OK"
# Debe imprimir OK. Si falla aquí, es auth o red — arréglalo antes de seguir.
```

### 3.4 El helper `cheap-fanout` (cópialo tal cual)
Guárdalo en tu PATH (p.ej. `~/.local/bin/cheap-fanout`) y hazlo ejecutable
(`chmod +x`). Es el dispatcher que corre N agentes en paralelo desde un `jobs.tsv`.

El campo `<model>` del `jobs.tsv` admite tres formas — si en la otra máquina solo tienes
OpenCode Go, usa la primera y el resto no estorba:

| Forma | Corre por | Presupuesto |
|---|---|---|
| `deepseek-v4-flash` | `opencode run -m opencode-go/<id>` | plan Go |
| `kimi-for-coding/k3` (cualquier `<provider>/<id>`) | `opencode run -m <ruta>` tal cual | el de ese proveedor |
| `codex` o `codex:<modelo>` | `codex exec` | suscripción ChatGPT |

```bash
#!/usr/bin/env bash
# cheap-fanout — dispara N agentes baratos en paralelo (OpenCode + Codex CLI) y junta sus salidas.
#
# El orquestador (Claude) escribe un jobs.tsv y un archivo de prompt por job; este script
# corre todos los agentes en paralelo (concurrencia acotada), guarda la salida de cada uno
# en su archivo, y devuelve como exit code el número de jobs que fallaron (0 = todos OK).
#
# Uso:
#   cheap-fanout [--dir REPO] [--parallel N] [--timeout T] [--on-quota free|off] JOBS.tsv
#
# JOBS.tsv — un job por línea, campos separados por TAB:
#   <model>\t<prompt_file>\t<out_file>[\t<timeout>]
#     model       : una de tres formas —
#                     <id>              → opencode run -m opencode-go/<id>   (plan Go)
#                     <provider>/<id>   → opencode run -m <provider>/<id>    (tal cual;
#                                         ej: kimi-for-coding/k3, suscripción Moonshot)
#                     codex | codex:<m> → codex exec (suscripción ChatGPT)
#     prompt_file : ruta a un archivo con el prompt COMPLETO y autocontenido del agente
#     out_file    : ruta donde se escribe la salida de ese agente
#     timeout     : OPCIONAL, plazo de ESE job. Sin sufijo = segundos; admite s/m/h
#                   (30s, 8m, 1h). `0`, `none` u `off` = sin límite. Si falta, se usa --timeout.
#   Las líneas vacías y las que empiezan con # se ignoran.
#
# Timeouts (el helper garantiza que termina):
#   --timeout T   plazo por default para los jobs sin 4ª columna (default: 15m).
#                 `--timeout none` lo desactiva globalmente.
#   Al vencer se manda SIGTERM y, 15s después, SIGKILL. El .status queda en 124 (venció y
#   murió con TERM) o 137 (necesitó KILL); ambos cuentan como fallo. Se anexa una nota al
#   out_file para que el orquestador lo vea sin mirar el .status.
#   Nota: `timeout(1)` de GNU corre el job en su propio grupo de procesos y señala al grupo
#   completo — verificado en coreutils 9.4 con un job que ignora TERM y deja un nieto: 0
#   sobrevivientes. Por eso NO hace falta envolverlo en `setsid`.
#
# Cuota Go agotada (se maneja sola; no hay que prohibir modelos a mano):
#   El plan Go limita por DÓLARES y desde agosto 2026 tiene DOS límites: el pozo GLOBAL
#   ($12/5h, $30/semana, $60/mes) y un TOPE MENSUAL POR MODELO ($60/$30/$15 según el modelo
#   — opencode.ai/docs/go). Por eso reintentar en otro modelo Go a veces SÍ sirve (si lo
#   agotado fue el tope de un modelo) y a veces no (si fue el pozo global). Distinguirlo es
#   una decisión de calidad y de presupuesto: la toma el orquestador con `go-budget`, no
#   este script.
#   Al detectar la firma del error de cuota en la salida de un job, el helper reintenta ese job
#   UNA vez en el gemelo gratuito del MISMO modelo (opencode/<id>-free) — la propia doc de Go
#   dice: "If you reach the usage limit, you can continue using the free models".
#     --on-quota free  (default) reintenta en el gemelo free si existe
#     --on-quota off             no reintenta; deja el fallo para que decidas tú
#   Si no hay gemelo free (kimi-k3, glm-5.2…), el job NO se sustituye por otro modelo: cambiar
#   de modelo cambia la calidad, y esa decisión es del orquestador. Queda con .status=77.
#   Consulta el presupuesto con el script hermano `go-budget` antes de lanzar un lote grande.
#
# Cada job corre:
#   opencode: opencode run --auto -m <ruta> [--dir REPO] "$(cat prompt_file)" > out_file 2>&1
#   codex   : codex exec --skip-git-repo-check --ephemeral -s $SANDBOX [-C REPO] \
#               [-m <m>] -o out_file "$(cat prompt_file)" > out_file.log 2>&1
#
# Notas:
#   - --auto auto-aprueba permisos: úsalo solo con prompts de solo-lectura/investigación o en
#     un worktree/dir aislado si el agente va a escribir.
#   - Junto a cada out_file se escriben:
#       out_file.status   exit code (0 OK · 124/137 timeout · 77 sin cuota ·
#                         66 salida vacía · 64 prompt > límite argv · otro = fallo)
#       out_file.gate     qué modelo/puerta lo sirvió realmente
#       out_file.rescued  solo si hubo rescate por cuota: "<modelo original>\t<gemelo free>"
#   - status=66 (salida vacía): opencode puede terminar con exit 0 y un .out que trae SOLO la
#     cabecera `> build · <model>` (variante silenciosa del choque de SQLite bajo concurrencia,
#     vista en Windows 2026-08-11). El helper marca fallo igual: el .status solo NO basta.
#   - status=64 (prompt largo): el prompt viaja como ARGUMENTO de la línea de comandos. En
#     Windows (Git Bash → CreateProcess) el límite es ~32 KB; en Linux es ARG_MAX (~2 MB)
#     menos el entorno. Si el prompt_file excede el límite, el job NO se lanza: falla antes
#     con 64 y un mensaje claro (en vez del críptico `Argument list too long`, exit 126).
#   - En jobs codex, out_file trae SOLO el mensaje final; la traza completa va a out_file.log.
#   - Modelos VETADOS (muse-spark-1.2-contributor, grok-4.6, y sus gemelos -free): el lote se
#     rechaza entero en pre-vuelo con exit 2. Override por invocación: CHEAP_FANOUT_ALLOW_VETOED=1.
#     La cuota de ChatGPT NO se autodetecta (no tengo la firma de su error verificada).
#   - Sandbox de codex: read-only por default. Para jobs que escriben, exporta
#     CHEAP_FANOUT_CODEX_SANDBOX=workspace-write (usa worktree aislado + --dir).
set -uo pipefail

REPO=""
PAR=6
JOBS=""
TIMEOUT_DEF="15m"
KILL_AFTER="15s"
ON_QUOTA="free"
QUOTA_STATUS=77
EMPTY_STATUS=66
ARGV_STATUS=64
MODELS_CACHE="$(mktemp -u "${TMPDIR:-/tmp}/cheap-fanout-models.XXXXXX")"
trap 'rm -f "$MODELS_CACHE"' EXIT
CODEX_SANDBOX="${CHEAP_FANOUT_CODEX_SANDBOX:-read-only}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          REPO="$2"; shift 2;;
    --parallel|-p)  PAR="$2";  shift 2;;
    --timeout|-t)   TIMEOUT_DEF="$2"; shift 2;;
    --on-quota)     ON_QUOTA="$2"; shift 2;;
    -h|--help)      sed -n '2,70p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    -*)             echo "cheap-fanout: opción desconocida: $1" >&2; exit 2;;
    *)              JOBS="$1"; shift;;
  esac
done

[ -n "$JOBS" ] && [ -f "$JOBS" ] || { echo "cheap-fanout: falta un JOBS.tsv válido" >&2; exit 2; }
case "$PAR" in ''|*[!0-9]*) echo "cheap-fanout: --parallel debe ser entero" >&2; exit 2;; esac
[ "$PAR" -ge 1 ] || PAR=1

# normaliza un plazo: imprime "" si es sin-límite, el valor para timeout(1) si es válido,
# y sale 1 si el formato no sirve.
norm_timeout() {
  local t="${1:-}"
  t="${t%%$'\r'}"
  case "$t" in
    ''|0|none|off|None|NONE|OFF) echo ""; return 0;;
    *[!0-9smh]*) return 1;;
    *[0-9]) echo "${t}s"; return 0;;          # sin sufijo ⇒ segundos
    *[0-9][smh]) echo "$t"; return 0;;
    *) return 1;;
  esac
}
TIMEOUT_DEF="$(norm_timeout "$TIMEOUT_DEF")" || {
  echo "cheap-fanout: --timeout inválido (usa 90, 30s, 8m, 1h o none)" >&2; exit 2; }
case "$ON_QUOTA" in
  free|off) ;;
  *) echo "cheap-fanout: --on-quota debe ser 'free' u 'off'" >&2; exit 2;;
esac

# --- modelos vetados (decisión permanente del usuario, 2026-08-28) ---
# No es una preferencia de estilo: son modelos cuyo uso tiene un costo que no se ve en la cuota.
#   muse-spark-1.2-contributor : entrena con tus datos y no es ZDR. Su gemelo free, igual.
#   grok-4.6                   : regresión en agentic coding vs 4.5 y TTFT de 31s.
# El rechazo es en PRE-VUELO: si un jobs.tsv trae uno, no se lanza NADA (mejor que gastar cuota
# en los demás y descubrirlo al final). Se puede saltar a propósito, por invocación:
#   CHEAP_FANOUT_ALLOW_VETOED=1 cheap-fanout jobs.tsv
VETOED="muse-spark-1.2-contributor grok-4.6"
ALLOW_VETOED="${CHEAP_FANOUT_ALLOW_VETOED:-0}"

# id desnudo de un modelo, sea cual sea la puerta: quita el prefijo de proveedor, el 'codex:' y
# el sufijo '-free', para que ni opencode/<id>-free ni codex:<id> se cuelen por la puerta de atrás.
bare_id() {
  local m="$1"
  m="${m#codex:}"
  m="${m##*/}"
  m="${m%-free}"
  printf '%s' "$m"
}

is_vetoed() {
  local id; id="$(bare_id "$1")"
  case " $VETOED " in *" $id "*) return 0;; esac
  return 1
}

# --- qué CLIs necesita este jobs.tsv (solo exige los que se usan) + valida los plazos ---
need_opencode=0; need_codex=0; lineno=0; vetados_vistos=""
while IFS=$'\t' read -r model pf of to || [ -n "${model:-}" ]; do
  lineno=$((lineno + 1))
  model="${model%%$'\r'}"
  [ -z "${model:-}" ] && continue
  case "$model" in
    \#*)          continue;;
    codex|codex:*) need_codex=1;;
    *)            need_opencode=1;;
  esac
  if [ "$ALLOW_VETOED" != 1 ] && is_vetoed "$model"; then
    vetados_vistos="${vetados_vistos}${vetados_vistos:+$'\n'}  línea ${lineno}: ${model}"
  fi
  norm_timeout "${to:-}" >/dev/null || {
    echo "cheap-fanout: línea $lineno: timeout inválido: '${to}'" >&2; exit 2; }
done < "$JOBS"
if [ -n "$vetados_vistos" ]; then
  echo "cheap-fanout: MODELO VETADO — no se lanzó ningún job del lote." >&2
  printf '%s\n' "$vetados_vistos" >&2
  echo "cheap-fanout: vetados: ${VETOED// /, } (y sus gemelos -free)." >&2
  echo "cheap-fanout: el ancho va a mimo-v2.5 o longcat-2.0; lo quirúrgico, a kimi-for-coding/k3," >&2
  echo "cheap-fanout: qwen3.8-max o glm-5.3. Ver 'Modelos vetados' en el SKILL.md." >&2
  echo "cheap-fanout: para saltarlo a propósito: CHEAP_FANOUT_ALLOW_VETOED=1" >&2
  exit 2
fi
if [ "$need_opencode" = 1 ]; then
  command -v opencode >/dev/null 2>&1 || { echo "cheap-fanout: opencode no está en PATH" >&2; exit 2; }
fi
if [ "$need_codex" = 1 ]; then
  command -v codex >/dev/null 2>&1 || { echo "cheap-fanout: codex no está en PATH" >&2; exit 2; }
  case "$CODEX_SANDBOX" in
    read-only|workspace-write|danger-full-access) ;;
    *) echo "cheap-fanout: CHEAP_FANOUT_CODEX_SANDBOX inválido: $CODEX_SANDBOX" >&2; exit 2;;
  esac
fi
HAVE_TIMEOUT=1
command -v timeout >/dev/null 2>&1 || { HAVE_TIMEOUT=0
  echo "cheap-fanout: aviso — timeout(1) no está en PATH; los jobs corren sin plazo" >&2; }

# Tamaño máximo del prompt, que viaja como ARGUMENTO de la línea de comandos.
# Windows (Git Bash → CreateProcess) topa en ~32 KB por línea — un prompt de 172 KB murió con
# exit 126 "Argument list too long" (hallazgo 2026-08-11). En Linux manda ARG_MAX menos una
# reserva para el entorno y los demás argumentos. Override: CHEAP_FANOUT_ARGV_MAX.
case "${OSTYPE:-$(uname -s 2>/dev/null || echo unknown)}" in
  msys*|cygwin*|MINGW*|MSYS*|CYGWIN*) ARGV_MAX_DEF=28000;;
  *) ARGV_MAX_DEF=$(getconf ARG_MAX 2>/dev/null || echo 2097152)
     case "$ARGV_MAX_DEF" in ''|*[!0-9]*) ARGV_MAX_DEF=2097152;; esac
     ARGV_MAX_DEF=$((ARGV_MAX_DEF / 4));;
esac
ARGV_PROMPT_MAX="${CHEAP_FANOUT_ARGV_MAX:-$ARGV_MAX_DEF}"

# Firma exacta que emite opencode al agotarse el presupuesto Go. Verificada en el log real:
#   error.error="AI_APICallError: Error from provider (Console Go): Provider rate limit exceeded"
is_quota_error() {
  grep -qiE 'provider rate limit exceeded|error from provider \(console go\)' "$1" 2>/dev/null
}

# Caracteres de CUERPO útil en un .out de opencode: sin códigos ANSI (\x1b[…m), sin la cabecera
# `> build · <model>` y sin espacios/saltos. 0 ⇒ el job "salió bien" pero no dijo nada (variante
# silenciosa del choque de SQLite bajo concurrencia: .status=0 con solo-cabecera, hallazgo
# 2026-08-11). NO se pone umbral >0 a propósito: respuestas cortas legítimas ("PONG") existen.
body_chars() {
  sed -e 's/\x1b\[[0-9;]*m//g' -e '/^[[:space:]]*>[[:space:]]*build[[:space:]]/d' "$1" 2>/dev/null \
    | tr -d '[:space:]' | wc -c | tr -d ' '
}

# Gemelo gratuito de un modelo Go, si el proveedor lo sirve (opencode/<id>-free).
# La lista se consulta UNA vez y se cachea; varios jobs pueden pedirla a la vez.
free_twin() {
  local mpath="$1" id="${1##*/}"
  case "$mpath" in opencode-go/*) ;; *) echo ""; return;; esac
  if [ ! -s "$MODELS_CACHE" ]; then
    # OJO: `$$` dentro de un subshell es el PID del PADRE, así que dos jobs concurrentes
    # elegirían el MISMO nombre y uno de los dos `mv` fallaría. mktemp da un nombre por job.
    local tmp; tmp="$(mktemp "${MODELS_CACHE}.XXXXXX")" || { echo ""; return; }
    if opencode models > "$tmp" 2>/dev/null; then mv -f "$tmp" "$MODELS_CACHE"; else rm -f "$tmp"; fi
  fi
  grep -qx "opencode/${id}-free" "$MODELS_CACHE" 2>/dev/null && echo "opencode/${id}-free" || echo ""
}

run_one() {
  local model="$1" pf="$2" of="$3" tspec="$4"
  if [ ! -f "$pf" ]; then echo "PROMPT FILE NO EXISTE: $pf" > "$of"; return 1; fi

  # El prompt viaja como argv. Si excede el límite de ESTE sistema, falla ANTES de lanzar
  # (exit 126 "Argument list too long" no le dice nada al orquestador).
  local psz
  psz="$(wc -c < "$pf" | tr -d ' ')"
  if [ "$psz" -gt "$ARGV_PROMPT_MAX" ]; then
    printf '[cheap-fanout] PROMPT DEMASIADO LARGO: %s bytes; el límite de argumentos de este sistema es %s.\n' \
      "$psz" "$ARGV_PROMPT_MAX" > "$of"
    printf 'Rehaz el job con prompt POR REFERENCIA: un prompt corto que liste las rutas de los\n' >> "$of"
    printf 'archivos a leer y deje que el agente los abra con sus herramientas de archivo desde\n' >> "$of"
    printf 'el cwd (los agentes de opencode SÍ leen archivos locales). Override: CHEAP_FANOUT_ARGV_MAX.\n' >> "$of"
    return "$ARGV_STATUS"
  fi

  # prefijo de plazo: vacío ⇒ el job corre sin límite
  local tmo=()
  [ -n "$tspec" ] && [ "$HAVE_TIMEOUT" = 1 ] && \
    tmo=(timeout --signal=TERM --kill-after="$KILL_AFTER" "$tspec")

  local rc=0
  # < /dev/null es OBLIGATORIO en ambas ramas: sin esto, cada proceso en background hereda el
  # fd 0 del `while read < jobs.tsv` y se come las líneas restantes → solo corre el primer
  # lote de --parallel. (codex exec además lee stdin como prompt y se colgaría.)
  case "$model" in
    codex|codex:*)
      local marg=()
      case "$model" in codex:*) marg=(-m "${model#codex:}");; esac
      local dirarg=()
      [ -n "$REPO" ] && dirarg=(-C "$REPO")
      "${tmo[@]}" codex exec --skip-git-repo-check --ephemeral -s "$CODEX_SANDBOX" \
        "${dirarg[@]}" "${marg[@]}" -o "$of" "$(cat "$pf")" \
        > "${of}.log" 2>&1 < /dev/null || rc=$?
      case "$model" in codex:*) echo "codex:${model#codex:}";; *) echo "codex (default de ~/.codex/config.toml)";; esac > "${of}.gate"
      # si codex murió antes de escribir el mensaje final, deja la traza a la vista
      [ -s "$of" ] || { echo "(sin mensaje final de codex; traza en ${of}.log)" > "$of"
                        tail -40 "${of}.log" >> "$of" 2>/dev/null; }
      ;;
    *)
      # con `/` es una ruta provider/id de opencode y va tal cual; sin `/`, es del plan Go
      local mpath="$model"
      case "$model" in */*) ;; *) mpath="opencode-go/${model}";; esac
      local dirarg=()
      [ -n "$REPO" ] && dirarg=(--dir "$REPO")
      "${tmo[@]}" opencode run --auto -m "$mpath" "${dirarg[@]}" "$(cat "$pf")" \
        > "$of" 2>&1 < /dev/null || rc=$?
      echo "$mpath" > "${of}.gate"

      # --- cuota Go agotada: puede ser el pozo global o el tope mensual de ESTE modelo, y
      # desde aquí no se distingue. El único fallback seguro —el que no cambia la calidad
      # porque es el MISMO modelo— es su gemelo free (opencode/<id>-free), que la doc señala:
      # "If you reach the usage limit, you can continue using the free models."
      if is_quota_error "$of"; then
        local twin=""
        [ "$ON_QUOTA" = free ] && twin="$(free_twin "$mpath")"
        if [ -n "$twin" ]; then
          "${tmo[@]}" opencode run --auto -m "$twin" "${dirarg[@]}" "$(cat "$pf")" \
            > "$of" 2>&1 < /dev/null; rc=$?
          echo "$twin" > "${of}.gate"
          if is_quota_error "$of" || [ "$rc" != 0 ]; then
            rc="${QUOTA_STATUS}"
          else
            # marca explícita del RESCATE: pedir un modelo free a propósito no es lo mismo que
            # caer en él por falta de cuota, y el resumen no debe confundirlos.
            printf '%s\t%s\n' "$mpath" "$twin" > "${of}.rescued"
            printf '\n[cheap-fanout] CUOTA: %s sin presupuesto Go; servido por su gemelo free %s.\n' \
              "$mpath" "$twin" >> "$of"
          fi
        else
          rc="${QUOTA_STATUS}"
        fi
      fi
      ;;
  esac

  # 124 = venció y murió con TERM; 137 = necesitó SIGKILL tras --kill-after
  if [ -n "$tspec" ] && { [ "$rc" = 124 ] || [ "$rc" = 137 ]; }; then
    printf '\n[cheap-fanout] TIMEOUT: el job excedió %s y fue terminado (exit %s).\n' \
      "$tspec" "$rc" >> "$of"
  fi

  # status=0 NO basta: bajo concurrencia opencode puede terminar con exit 0 y un .out que trae
  # SOLO la cabecera `> build · <model>` + códigos ANSI (variante silenciosa del choque de
  # SQLite, hallazgo 2026-08-11 — pasa el check de .status). Se marca fallo igual.
  if [ "$rc" = 0 ] && [ "$(body_chars "$of")" = 0 ]; then
    printf '\n[cheap-fanout] SALIDA VACÍA: exit 0 pero sin cuerpo tras quitar cabecera y ANSI\n' >> "$of"
    printf '(variante silenciosa del choque de SQLite bajo concurrencia). Reintenta este job con\n' >> "$of"
    printf 'MENOS concurrencia: en Windows el límite 2-3 es GLOBAL por máquina — dos lotes\n' >> "$of"
    printf 'cheap-fanout simultáneos comparten el mismo SQLite de opencode.\n' >> "$of"
    rc="$EMPTY_STATUS"
  fi
  return "$rc"
}

# --- lanzar con concurrencia acotada; el fail count sale de los .status (confiable) ---
active=0
while IFS=$'\t' read -r model pf of to || [ -n "${model:-}" ]; do
  model="${model%%$'\r'}"
  [ -z "${model:-}" ] && continue
  case "$model" in \#*) continue;; esac
  of="${of%%$'\r'}"
  # 4ª columna presente ⇒ manda sobre el default (incluido `none`, que quita el límite);
  # los formatos ya se validaron arriba, así que aquí norm_timeout no puede fallar.
  if [ -n "${to:-}" ] && [ -n "${to%%$'\r'}" ]; then
    tspec="$(norm_timeout "$to")"
  else
    tspec="$TIMEOUT_DEF"
  fi
  ( run_one "$model" "$pf" "$of" "$tspec"; echo $? > "${of}.status" ) &
  active=$((active + 1))
  if [ "$active" -ge "$PAR" ]; then wait -n 2>/dev/null || true; active=$((active - 1)); fi
done < "$JOBS"
wait

# --- contar fallos releyendo los .status ---
fail=0; total=0; timedout=0; sincuota=0; rescatados=0; vacios=0; largos=0
while IFS=$'\t' read -r model pf of to || [ -n "${model:-}" ]; do
  model="${model%%$'\r'}"
  [ -z "${model:-}" ] && continue
  case "$model" in \#*) continue;; esac
  of="${of%%$'\r'}"
  total=$((total + 1))
  s="$(cat "${of}.status" 2>/dev/null || echo 1)"
  case "$s" in
    0) if [ -s "${of}.rescued" ]; then
         rescatados=$((rescatados + 1))
         IFS=$'\t' read -r desde hacia < "${of}.rescued"
         echo "cheap-fanout: cuota Go agotada en $desde → $of servido por $hacia" >&2
       fi;;
    124|137) fail=$((fail + 1)); timedout=$((timedout + 1))
             echo "cheap-fanout: TIMEOUT (status=$s) → $of" >&2;;
    "$QUOTA_STATUS") fail=$((fail + 1)); sincuota=$((sincuota + 1))
             echo "cheap-fanout: SIN CUOTA (status=$s) → $of" >&2;;
    "$EMPTY_STATUS") fail=$((fail + 1)); vacios=$((vacios + 1))
             echo "cheap-fanout: SALIDA VACÍA (status=$s) → $of" >&2;;
    "$ARGV_STATUS") fail=$((fail + 1)); largos=$((largos + 1))
             echo "cheap-fanout: PROMPT DEMASIADO LARGO (status=$s) → $of" >&2;;
    *) fail=$((fail + 1)); echo "cheap-fanout: FALLÓ (status=$s) → $of" >&2;;
  esac
done < "$JOBS"

msg="cheap-fanout: $((total - fail))/${total} OK, ${fail} fallo(s)"
[ "$timedout" -gt 0 ]   && msg="$msg (${timedout} por timeout)"
[ "$rescatados" -gt 0 ] && msg="$msg (${rescatados} rescatado(s) por modelos free)"
[ "$vacios" -gt 0 ]     && msg="$msg (${vacios} con salida vacía)"
[ "$largos" -gt 0 ]     && msg="$msg (${largos} por prompt demasiado largo)"
if [ "$sincuota" -gt 0 ]; then
  msg="$msg (${sincuota} sin cuota y sin gemelo free)"
  echo "$msg" >&2
  echo 'cheap-fanout: Go limita por DÓLARES en dos niveles: pozo global ($12/5h, $30/sem,' >&2
  echo 'cheap-fanout: $60/mes) y tope mensual por modelo ($60/$30/$15). Corre go-budget:' >&2
  echo "cheap-fanout:   - si lo agotado es el TOPE del modelo -> manda ese job a otro modelo Go" >&2
  echo "cheap-fanout:   - si lo agotado es el POZO global -> opencode/<modelo>-free, 'codex'" >&2
  echo "cheap-fanout:     o kimi-for-coding/k3; cambiar de modelo Go no ayuda." >&2
  exit "$fail"
fi
if [ "$vacios" -gt 0 ]; then
  echo "$msg" >&2
  echo 'cheap-fanout: salidas vacías = choque de SQLite bajo concurrencia. Reintenta esos jobs' >&2
  echo 'cheap-fanout: con menos --parallel y SIN otros lotes cheap-fanout corriendo a la vez.' >&2
  exit "$fail"
fi
if [ "$largos" -gt 0 ]; then
  echo "$msg" >&2
  echo 'cheap-fanout: prompts que exceden el argv del sistema. Rehaz esos jobs por REFERENCIA:' >&2
  echo 'cheap-fanout: prompt corto con las rutas de los archivos, y que el agente los lea del cwd.' >&2
  exit "$fail"
fi
echo "$msg" >&2
exit "$fail"
```

```bash
chmod +x ~/.local/bin/cheap-fanout
cheap-fanout --help          # confirma que corre
```

### 3.4.bis El medidor `go-budget` (opcional pero recomendado)

El plan Go limita por **dólares** en dos niveles —un pozo global ($12/5h · $30/semana · $60/mes)
y un **tope mensual por modelo** ($60/$30/$15 según el modelo)—, no por requests, y no hay API
pública de consumo. `go-budget` lo estima leyendo la base local de sesiones (`opencode db`), que
guarda `cost`, `providerID` y `modelID` por mensaje:

```bash
opencode db "SELECT ROUND(SUM(json_extract(data,'\$.cost')),4) FROM message
 WHERE json_extract(data,'\$.providerID')='opencode-go'
   AND json_extract(data,'\$.time.created') >= (CAST(strftime('%s','now') AS INTEGER)-5*3600)*1000"
```

Copia el script completo de `bin/go-budget` del skill: imprime las tres ventanas globales **y** el
gasto del mes de cada modelo contra su propio tope, que es lo que decide si ante un fallo de cuota
conviene cambiar de modelo Go (tope agotado) o salirse de Go (pozo global agotado). Mide solo lo
gastado desde esa máquina.

### 3.5 (Opcional) Instalarlo como skill de Claude Code
Si la otra máquina tiene **Claude Code** y quieres que el orquestador lo invoque solo:
```
~/.claude/skills/cheap-fanout/
├── SKILL.md          # la metodología (puedes usar §7–§8 de este doc como base)
└── bin/cheap-fanout  # el helper de §3.4
```
El `SKILL.md` necesita frontmatter `name:` y `description:` con los triggers (ver el original en
la máquina donde ya existe). Sin Claude Code, este spec basta: el orquestador (tú u otro CLI)
sigue los pasos a mano.

---

## 4. Uso

1. **Escribe un prompt autocontenido por unidad** en archivos (`p01.txt`, `p02.txt`, …). El
   agente barato no debe decidir ni preguntar nada: dale objetivo, fuentes/URLs o archivos
   exactos, y el **formato de salida** (idealmente JSON estricto de una línea).
2. **Arma un `jobs.tsv`** — una línea por job, campos separados por **TAB**:
   ```
   <model><TAB><prompt_file><TAB><out_file>
   ```
3. **Dispara en paralelo:**
   ```bash
   cheap-fanout --parallel 8 jobs.tsv           # investigación (solo lectura)
   cheap-fanout --dir /ruta/al/repo --parallel 6 jobs.tsv   # si van a leer/escribir un repo
   ```
4. **Recolecta:** lee cada `out_file`. Ignora la cabecera de opencode (`> build · <model>` y
   líneas de control); el contenido útil es el cuerpo/tail. `out_file.status` = exit code (0 = OK).
5. **Revisa y sintetiza TÚ** (el orquestador). Ver §8–§9.

---

## 5. Ejemplo mínimo end-to-end (investigación web)

```bash
mkdir -p /tmp/cf && cd /tmp/cf
printf 'Busca la fecha de lanzamiento de Python 3.14 y da la URL fuente. Responde en 2 lineas.' > p01.txt
printf 'Busca cuantos habitantes tiene Monterrey (dato mas reciente) y la URL fuente. 2 lineas.' > p02.txt
printf 'mimo-v2.5\t/tmp/cf/p01.txt\t/tmp/cf/o01.out\n'  > jobs.tsv
printf 'mimo-v2.5\t/tmp/cf/p02.txt\t/tmp/cf/o02.out\n' >> jobs.tsv
cheap-fanout --parallel 2 jobs.tsv
cat o01.out o02.out         # ← tú lees, verificas y sintetizas
```
Cada agente barato usa su tool `webfetch` para investigar consultas **abiertas** solo (construye
URLs de fuentes autoritativas — Wikipedia, sitios oficiales — las baja y extrae). No hay motor de
búsqueda dedicado; para temas *long-tail* dale una URL de arranque en el prompt.

---

## 6. Catálogo de modelos OpenCode Go (releído en opencode.ai/docs/go el 2026-08-28)

Todos se invocan como `opencode-go/<id>`. Cuota en **requests por ventana de 5h**; `tope` = los
dólares del mes que ese modelo puede consumir del plan (además del pozo global compartido).
La tabla va ordenada por utilidad práctica, no por cuota.

| id | req/5h | tope | contexto | free | Úsalo para |
|----|-------:|:----:|:--------:|:--:|------------|
| **mimo-v2.5** | **30,100** | $60 | 1M | ✅ | **DEFAULT.** Investigación, fetch+resumen, mecánico simple, resumen a gran escala. Multimodal nativo, $0.14/$0.28 |
| ~~muse-spark-1.2-contributor~~ | 45,300 | $60 | 1M | ✅ | 🚫 **VETADO** — entrena con tus datos y no es ZDR. Tiene la cuota más alta del pool; da igual. Ver *Modelos vetados* |
| longcat-2.0 | 11,400 | $60 | 1M | — | Segundo del ancho con 0 días de retención ($0.30/$1.20; cache a $0.006/1M) |
| deepseek-v4-flash | 7,600 | $30 | 1M | — | Agentic multi-paso. Ex-default: subió a $0.22/$0.66 (2x en peak), cayó a 7,600 req/5h y perdió su gemelo free |
| qwen3.8-flash | 5,400 | $30 | 1M | — | Barato ($0.15/$0.47) con 1M ctx |
| hy3 | 4,300 | $60 | 256K | ✅ | Código acotado con spec cerrada ($0.14/$0.58). Razonamiento/SWE altos |
| qwen3.7-plus | 4,300 | $60 | 1M | — | Tool-calling+MCP. Escalón: >256K factura $1.20/$4.80 |
| minimax-m3 | 3,200 | $60 | 1M | — | Código/agentic, contexto largo |
| glm-5.3-flash | 1,580 | **$15** | 1M | — | **El escalón de la unidad difícil.** Índice de Inteligencia 57 (= Claude Opus 4.8, = Kimi K3) a $0.15/$0.50. El tope bajo lo mantiene fuera del ancho, que es lo que se quiere |
| gpt-5.6-luna | 2,050 | **$15** | 1.05M | — | Agentic/multimodal fuerte, pero tope bajo y retiene datos 30 días |
| kimi-k2.7-code | 1,350 | $60 | 256K | — | Código agentic multi-paso (>5 tools), specs rígidas |
| deepseek-v4-pro | 1,050 | **$15** | 1M | — | Código con razonamiento algorítmico. Ya no es barato: $0.66/$1.98 y tope $15 |
| glm-5.2 | 880 | $60 | 1M | — | Bug-fixing / SWE con repro claro |

**NO uses para fan-out** (cuota casi nula: resérvalos para una consulta puntual tuya, nunca para
un jobs.tsv con muchas líneas): `qwen3.7-max` (340 req/5h), `glm-5.3` (220), `qwen3.8-max` (160),
`kimi-k3` (110). Todos con tope $15/mes salvo `qwen3.7-max`.

**Modelos vetados (decisión permanente del usuario, 2026-08-28).** Dos modelos del pool NO se usan
aunque los números inviten, y el helper lo aplica solo: rechaza el lote **entero en pre-vuelo**
(exit 2) si un jobs.tsv trae alguno, en cualquiera de sus formas (`<id>`, `opencode-go/<id>`,
`opencode/<id>-free`, `codex:<id>`).
- `muse-spark-1.2-contributor` **y su gemelo free** — trato explícito "cuota gigante a cambio de
  tus datos": mismos pesos que `muse-spark-1.2` ($1.25/$4.25) a 12x menos en input porque el lab
  usa lo que le mandes para entrenar. No es ZDR.
- `grok-4.6` — su agentic coding regresó frente a `grok-4.5` (LiveBench 54.2 vs 56.5) y su
  time-to-first-token pasó de 8.7s a 31.2s. Además retiene datos 30 días.

Sus casos se cubren con `mimo-v2.5` / `longcat-2.0` (el ancho) y `kimi-for-coding/k3`,
`qwen3.8-max` o `glm-5.3` (lo quirúrgico). Override deliberado, por invocación:
`CHEAP_FANOUT_ALLOW_VETOED=1`.

**Dos límites, no uno (cambió en agosto 2026).** Además del pozo global, cada modelo tiene un tope
mensual en dólares ($60, $30 o $15 — la doc lo explica en *"Why some models have lower usage"*).
Consecuencia: agotar un modelo ya **no** agota el plan, así que cambiar de modelo Go sí consigue
presupuesto; lo que no consigue nada es cambiar de modelo cuando lo agotado fue el pozo global.
`go-budget` distingue los dos casos.

**Peak/off-peak de DeepSeek.** Los tres modelos DeepSeek cuestan el doble en horas peak
(01:00-04:00 y 06:00-10:00 UTC, L-V; en CDMX, dom-jue 19:00-22:00 y lun-vie 00:00-04:00). Ningún
otro modelo del pool tiene esta mecánica.

**Gemelos free vivos** (probados 2026-08-28): `opencode/mimo-v2.5-free` y `opencode/hy3-free`.
El de `deepseek-v4-flash` **murió**; el de `muse-spark-1.2-contributor` responde pero está
**vetado** (el gemelo free entrena igual que el de paga). Otros `*-free`
que aparecen en `models.dev` no responden: pruébalos antes de meterlos en un jobs.tsv.

**`opencode models` no es autoridad**: viene desfasado (el 2026-08-28 omitía cuatro modelos que sí
responden y listaba dos que no). La prueba real es
`opencode run -m opencode-go/<id> "Responde exactamente: PONG"`.

**Ruteo por dificultad (no uses un router LLM, decide tú):**
- Investigación / fetch+resumen / mecánico simple → **`mimo-v2.5`** (o `longcat-2.0` /
  `qwen3.8-flash` para no tocar el tope de mimo). El volumen bruto NO va a
  `muse-spark-1.2-contributor`: está vetado.
- Código acotado con spec cerrada → `hy3`, `qwen3.7-plus` o `kimi-k2.7-code`.
- **La unidad difícil del lote** (1-3 por lote: más dura que el ancho, sin llegar a frontier) →
  `glm-5.3-flash`. Existe para dejar de quemar asientos de K3 en cosas que no eran tan graves.
  Evidencia todavía delgada: el modelo salió el 2026-08-26 y casi todos sus benchmarks los
  reporta su propio lab. Valídalo mandando una unidad difícil a `glm-5.3-flash` y a K3 a la vez
  y comparando; si no gana, borra el escalón.
- Código agentic multi-paso → `deepseek-v4-flash`, fuera de horas peak.
- Contexto muy largo (documentos/transcripciones gigantes) → `mimo-v2.5`, `longcat-2.0` o
  `minimax-m3` (1M ctx los tres, tope $60).
- Delicado / frontier (arquitectura, seguridad, semántica) → **el orquestador (tú/Claude)**, no
  un barato.

> Los modelos frontier de Go tienen **~1M de contexto** (verificado en fuente primaria): un
> agente barato puede ingerir páginas/transcripciones enormes de un jalón. No lo subestimes.

---

## 7. El flujo (5 pasos)

1. **Descomponer** en N unidades independientes (sub-preguntas / URLs / archivos). Ownership
   disjunto: dos jobs nunca tocan el mismo archivo.
2. **Asignar modelo por unidad** (ruteo por dificultad, §6).
3. **Disparar en paralelo** con `cheap-fanout` (prompts autocontenidos + jobs.tsv). Para
   ediciones que escriben, corre cada job en un **git worktree** aislado o usa `--dir`.
4. **Recolectar** los `out_file` (revisa `.status`).
5. **Revisar y sintetizar TÚ** — el invariante que no se salta.

---

## 8. Reglas de oro (lecciones caras, no las repitas)

1. **Ningún output barato aterriza sin tu revisión.** Para investigación, TÚ escribes la síntesis
   (los baratos son materia prima, no la respuesta). Para código, TÚ lees el diff y corres tests.
2. **La `confidence` auto-reportada del agente no es señal** — casi siempre dice "high". Ignórala.
3. **Extracción factual: verifica contra la FUENTE PRIMARIA, no por votos ni por tu prior.**
   Cruzar 2 agentes de familias distintas ayuda, PERO el consenso puede ser un prior compartido
   (correcto o incorrecto). Pide URL + cita textual, y para valores de alto impacto o raros, ve
   TÚ a la fuente oficial y lee el número.
4. **Tu propio conocimiento de entrenamiento también caduca.** Un dato *sourced* que te parezca
   "alucinación" puede ser correcto y tú estar desactualizado. Verifica en la primaria; no lo
   descartes con corazonada.
5. **Disciplina de tokens.** El caro solo en planear+revisar+sintetizar. El ancho, siempre barato.

---

## 9. Troubleshooting portátil

| Síntoma | Causa / arreglo |
|---------|-----------------|
| `opencode no está en PATH` | Instala §3.1 o exporta el bin a tu `$PATH`. |
| Smoke test falla | Auth (§3.2): revisa `~/.local/share/opencode/auth.json`. |
| Solo corre el primer lote de `--parallel` | Falta el `< /dev/null` del helper — usa la versión de §3.4 tal cual. |
| Salida con basura al inicio | Es la cabecera de opencode (`> build · <model>`); parsea el cuerpo/tail. |
| Un job devolvió basura / null | Rehazlo tú o reasígnalo a un modelo mejor; no lo integres a ciegas. |
| 429 / budget excedido | Cuota Go agotada (compartida): espera la ventana o baja `--parallel`. |
| El agente "no puede buscar" | Solo tiene `webfetch` (no buscador): dale una URL de arranque en el prompt. |

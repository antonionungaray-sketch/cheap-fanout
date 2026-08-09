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
#   El plan Go limita por DÓLARES con un pozo ÚNICO compartido entre todos sus modelos
#   ($12/5h, $30/semana, $60/mes — opencode.ai/docs/go). Por eso reintentar en otro modelo Go
#   NO consigue nada: el presupuesto ya se acabó para todos.
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
#       out_file.status   exit code (0 OK · 124/137 timeout · 77 sin cuota · otro = fallo)
#       out_file.gate     qué modelo/puerta lo sirvió realmente
#       out_file.rescued  solo si hubo rescate por cuota: "<modelo original>\t<gemelo free>"
#   - En jobs codex, out_file trae SOLO el mensaje final; la traza completa va a out_file.log.
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
MODELS_CACHE="$(mktemp -u "${TMPDIR:-/tmp}/cheap-fanout-models.XXXXXX")"
trap 'rm -f "$MODELS_CACHE"' EXIT
CODEX_SANDBOX="${CHEAP_FANOUT_CODEX_SANDBOX:-read-only}"
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          REPO="$2"; shift 2;;
    --parallel|-p)  PAR="$2";  shift 2;;
    --timeout|-t)   TIMEOUT_DEF="$2"; shift 2;;
    --on-quota)     ON_QUOTA="$2"; shift 2;;
    -h|--help)      sed -n '2,62p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
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

# --- qué CLIs necesita este jobs.tsv (solo exige los que se usan) + valida los plazos ---
need_opencode=0; need_codex=0; lineno=0
while IFS=$'\t' read -r model pf of to || [ -n "${model:-}" ]; do
  lineno=$((lineno + 1))
  model="${model%%$'\r'}"
  [ -z "${model:-}" ] && continue
  case "$model" in
    \#*)          continue;;
    codex|codex:*) need_codex=1;;
    *)            need_opencode=1;;
  esac
  norm_timeout "${to:-}" >/dev/null || {
    echo "cheap-fanout: línea $lineno: timeout inválido: '${to}'" >&2; exit 2; }
done < "$JOBS"
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

# Firma exacta que emite opencode al agotarse el presupuesto Go. Verificada en el log real:
#   error.error="AI_APICallError: Error from provider (Console Go): Provider rate limit exceeded"
is_quota_error() {
  grep -qiE 'provider rate limit exceeded|error from provider \(console go\)' "$1" 2>/dev/null
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

      # --- cuota Go agotada: el plan limita por DÓLARES con un pozo ÚNICO compartido, así que
      # reintentar en otro modelo Go no sirve de nada. El único fallback que sigue siendo el
      # MISMO modelo es su gemelo free (opencode/<id>-free), que la propia doc de Go señala:
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
fail=0; total=0; timedout=0; sincuota=0; rescatados=0
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
    *) fail=$((fail + 1)); echo "cheap-fanout: FALLÓ (status=$s) → $of" >&2;;
  esac
done < "$JOBS"

msg="cheap-fanout: $((total - fail))/${total} OK, ${fail} fallo(s)"
[ "$timedout" -gt 0 ]   && msg="$msg (${timedout} por timeout)"
[ "$rescatados" -gt 0 ] && msg="$msg (${rescatados} rescatado(s) por modelos free)"
if [ "$sincuota" -gt 0 ]; then
  msg="$msg (${sincuota} sin cuota y sin gemelo free)"
  echo "$msg" >&2
  echo 'cheap-fanout: el plan Go limita por DÓLARES con un pozo único ($12/5h, $30/sem, $60/mes)' >&2
  echo "cheap-fanout: cambiar a otro modelo Go NO ayuda. Revisa 'go-budget' y manda esos jobs a" >&2
  echo "cheap-fanout: opencode/<modelo>-free, a 'codex' (ChatGPT) o a kimi-for-coding/k3." >&2
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

El plan Go limita por **dólares** con un pozo único ($12/5h · $30/semana · $60/mes), no por
requests, y no hay API pública de consumo. `go-budget` lo estima leyendo la base local de
sesiones (`opencode db`), que guarda `cost` y `providerID` por mensaje:

```bash
opencode db "SELECT ROUND(SUM(json_extract(data,'\$.cost')),4) FROM message
 WHERE json_extract(data,'\$.providerID')='opencode-go'
   AND json_extract(data,'\$.time.created') >= (CAST(strftime('%s','now') AS INTEGER)-5*3600)*1000"
```

Copia el script completo de `bin/go-budget` del skill. Mide solo lo gastado desde esa máquina.

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
printf 'deepseek-v4-flash\t/tmp/cf/p01.txt\t/tmp/cf/o01.out\n'  > jobs.tsv
printf 'deepseek-v4-flash\t/tmp/cf/p02.txt\t/tmp/cf/o02.out\n' >> jobs.tsv
cheap-fanout --parallel 2 jobs.tsv
cat o01.out o02.out         # ← tú lees, verificas y sintetizas
```
Cada agente barato usa su tool `webfetch` para investigar consultas **abiertas** solo (construye
URLs de fuentes autoritativas — Wikipedia, sitios oficiales — las baja y extrae). No hay motor de
búsqueda dedicado; para temas *long-tail* dale una URL de arranque en el prompt.

---

## 6. Catálogo de modelos OpenCode Go (releído en opencode.ai/docs/go el 2026-08-09)

Todos se invocan como `opencode-go/<id>`. Cuota en **requests por ventana de 5h** (más = más barato).

| id | req/5h | contexto | Úsalo para |
|----|-------:|:--------:|------------|
| **deepseek-v4-flash** | **31,650** | 1M | **DEFAULT.** Investigación, fetch+resumen, mecánico simple, tests desde spec. Smoke-test 2026-08-06: responde OK. |
| mimo-v2.5 | 30,100 | 1M | Alternativa de cuota altísima (mecánico, resumen a gran escala) |
| hy3 | 4,300 | 262k | **NUEVO.** Misma cuota que qwen3.7-plus a ~3x menos costo ($0.14/$0.58) y sin escalones de precio. Candidato a reemplazarlo en mecánico/simple — `confidence: low`, sin uso propio medido todavía |
| qwen3.7-plus | 4,300 | — | Código acotado con spec cerrada |
| deepseek-v4-pro | 3,450 | 1M | Código con razonamiento algorítmico |
| minimax-m3 | 3,200 | 1M | Código/agentic, contexto largo |
| gpt-5.6-luna | 2,050 | 1.05M | **NUEVO.** Contexto enorme a precio bajo ($0.20/$1.20); útil para ingerir documentos/transcripciones gigantes. `confidence: low`, sin uso propio medido |
| kimi-k2.7-code | 1,350 | 262k | Código agentic multi-paso (>5 tools), specs rígidas |
| glm-5.2 | 880 | 1M | Bug-fixing / SWE con repro claro |

**NO uses para fan-out** (aparecieron en el catálogo 2026-08-04 pero su cuota los hace inviables
para trabajo ancho): `grok-4.5` (120 req/5h), `kimi-k3` (110 req/5h), `qwen3.8-max` (160 req/5h).
Son modelos frontier de cuota casi nula — resérvalos para una consulta puntual tuya, nunca para
un jobs.tsv con muchas líneas.

**Ruteo por dificultad (no uses un router LLM, decide tú):**
- Investigación / fetch+resumen / mecánico simple → **`deepseek-v4-flash`** (o `mimo-v2.5` si
  quieres reservar la cuota de flash; `hy3` como alternativa más barata sin verificar aún).
- Código acotado con spec cerrada → `deepseek-v4-pro`, `qwen3.7-plus` o `kimi-k2.7-code`.
- Contexto muy largo (documentos/transcripciones gigantes) → `gpt-5.6-luna` (1.05M ctx) o
  `deepseek-v4-flash`/`mimo-v2.5` (1M ctx, más cuota).
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

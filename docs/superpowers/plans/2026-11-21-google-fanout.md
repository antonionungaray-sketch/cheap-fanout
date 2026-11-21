# google-fanout — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Agregar tres cosas, con pruebas sin costo y mediciones en vivo que fijen el ruteo:

- la puerta `agy:<id>` (CLI de Google Antigravity) a `bin/cheap-fanout`;
- el script `bin/agy-budget`;
- el skill `google-fanout`.

**Architecture:**

- **La puerta.** Es una rama más de `run_one`, junto a codex y opencode. Tiene pre-vuelo propio
  (atestación de telemetría e ids válidos) y un workspace temporal por job. Sus estados son los
  `.status` de siempre más 65 (denegado).
- **`agy-budget`.** Lee `agy -p /usage`, y el helper lo llama para confirmar una cuota agotada.
- **Documentación.** El skill nuevo cubre reglas, ruteo y cuota; cheap-fanout solo gana referencias.

**Tech Stack:**

- bash 5.2, con `set -uo pipefail` y `wait -n`;
- `timeout(1)` de coreutils;
- `python3 -I` (3.12) para leer JSON y NDJSON;
- agy 1.5.14;
- OpenCode y Codex CLI, solo para las mediciones.

**Spec:** `docs/superpowers/specs/2026-11-21-google-fanout-design.md`

## Global Constraints

**Forma del job.** El campo `model` es `agy:<id>`, con el id exacto de `agy models`. Un `agy` sin id es
error de pre-vuelo (exit 2).

**`--settings` de cada job agy:**

- Solo lectura (default):
  `{"useG1Credits":false,"allowNonWorkspaceAccess":false,"agentMode":"auto","permissions":{"deny":["write_file(*)"]}}`
- Escritura, con `CHEAP_FANOUT_AGY_WRITE=1`:
  `{"useG1Credits":false,"allowNonWorkspaceAccess":false,"agentMode":"auto"}`
- **Por qué solo `write_file(*)`:** en agy no existe una acción `edit_file`; las ediciones caen bajo
  `write_file` (`docs/cli/permissions`, consultado el 2026-11-21). La precedencia es Deny > Ask > Allow.

**Atestación.** La ruta es `${XDG_CONFIG_HOME:-$HOME/.config}/cheap-fanout/agy-telemetry-off`. No tiene
override por variable de entorno.

**Estados:**

| `.status` | Significado |
|---|---|
| 65 | Denegado (nuevo) |
| 66 | Respuesta vacía |
| 124 / 137 | Venció el plazo (137 si necesitó KILL) |
| 77 | Sin cuota |
| 76 | Transitorio tras agotar reintentos |
| 64 | Prompt más largo que el argv |

Un exit 2 del helper significa que el pre-vuelo rechazó el lote.

**Archivos por job agy:**

- `out_file`: solo el mensaje final;
- `.gate`: `agy:<id>`;
- `.log`: el NDJSON de `stream-json`;
- `.err`: stderr;
- `.denied`: los permisos negados, uno por línea;
- `.quota`: `bolsa<TAB>ventana<TAB>reset_local`, solo con 77;
- `.capretried`: los reintentos (este nombre ya existe).

**`agy-budget`:**

- Interfaz: `[--model <id>] [--tsv] [--quiet]`.
- Exit codes: 0 holgada · 1 apretada (80% o más usado) · 2 agotada (0% restante) · 3 no se pudo leer.

**Reglas de texto:**

- En los SKILL.md nunca va `$` pegado a un dígito, porque el cargador lo sustituye; los precios van en
  "USD".
- Todo texto nuevo (mensajes y docs) va en español de México, como el resto del repo.

**Pruebas:**

- Los tres tests existentes (`test/detectores-y-vetos.sh`, `test/dos-lotes.sh`,
  `test/sqlite-race.sh`) siguen pasando sin cambios.
- Las pruebas automáticas nunca llaman al agy real: usan `test/fake-agy/agy`.

**Versión:** 1.7.0, en la rama `feat/google-fanout`. Merge y push solo cuando Antonio lo pida.

## Review Focus

1. **agy se autoactualiza y cambia su formato** (`stream-json` o `/usage`). El job debe fallar con la
   nota "formato de agy no reconocido" y nunca quedar en 0; `agy-budget` debe salir con 3. Tests: Task 3
   (escenario `raro`) y Task 1.
2. **Prompts con caracteres especiales** (comillas, saltos de línea, `ñ`, `$HOME`, `$(date)`) deben
   llegar a agy byte por byte. Test: Task 3 (escenario `eco`).
3. **Una respuesta de 2 MB** en una sola línea NDJSON debe llegar completa a `out_file`. Test: Task 3
   (escenario `grande`).
4. **Muchos jobs agy en paralelo** deben usar workspaces distintos y no dejar ninguno en disco, ni
   siquiera tras un timeout externo. Test: Task 3 (6 jobs `pwd` y el escenario `cuelga`).
5. **Sesión de agy vencida** (`authentication required`): fallo con la nota "SIN SESIÓN" y una pista en
   el resumen, nunca 77. Test: Task 4 (escenario `auth`).

---

### Task 1: `bin/agy-budget` y el agy falso de pruebas

**Files:**
- Create: `skills/cheap-fanout/bin/agy-budget` (ejecutable)
- Create: `skills/cheap-fanout/test/fake-agy/agy` (ejecutable)
- Create: `skills/cheap-fanout/test/agy-budget.sh`

**Interfaces:**

- **Produces `agy-budget [--model <id>] [--tsv] [--quiet]`.**
  - **TSV:** `bolsa<TAB>ventana<TAB>restante_pct<TAB>reset_utc<TAB>reset_local`.
    - `ventana` es `5h` si la etiqueta dice "Five Hour", `semana` si dice "Weekly" y `otra` en
      cualquier otro caso.
    - `restante_pct` es un entero, sin `%`.
    - `reset_local` sale de `date -d <utc> '+%Y-%m-%d %H:%M %Z'`.
  - **Mapeo de `--model`:**
    - `gemini-4-argon-*` y `gemini-pro-orchestrator-g1-pro` usan "Gemini Models" y "Gemini 4 Argon".
    - Los demás `gemini-*` usan "Gemini Models".
    - `claude-*` y `gpt-oss-*` usan "Claude and GPT models".
    - Cualquier otro id sale con 3.
  - **Modo humano** (sin `--tsv` ni `--quiet`):
    - muestra el % **usado** (100 menos el restante) y la hora local de reset;
    - agrega `Créditos de IA: N` (de `/credits`);
    - avisa si `/config` dice `useG1Credits true`;
    - cierra con esta línea exacta: `Ojo: agy da porcentajes enteros y con retraso; no sirven para
      medir un job suelto.`

- **Produces `test/fake-agy/agy`**, el agy falso que usan las Tasks 1 a 4:

  | Invocación | Salida |
  |---|---|
  | `agy models` | `Fetching available models...` y luego el contenido de `$FAKE_AGY_MODELS` |
  | `agy -p /usage` | El contenido de `$FAKE_AGY_USAGE`, con exit `${FAKE_AGY_USAGE_RC:-0}` |
  | `agy -p /credits` | `Remaining credits<TAB>${FAKE_AGY_CREDITS:-0}` |
  | `agy -p /config` | `useG1Credits<TAB>${FAKE_AGY_G1:-false}` |
  | `agy -p <prompt> …` | Lo que pida el token `ESCENARIO=<x>` del prompt (tablas de las Tasks 3 y 4) |

  Cada invocación agrega una línea JSON a `$FAKE_AGY_LOG`, generada con `python3 -I`:
  `{"cwd": <cwd>, "argv": [<args>], "ls": [<entradas del cwd>]}`.

- [ ] **Step 1: Crear la rama y commitear el diseño**

```bash
cd ~/Proyectos_local/cheap-fanout && git checkout -b feat/google-fanout
git add docs/superpowers && git commit -m "docs: diseño y plan de la puerta agy (google-fanout)"
```

- [ ] **Step 2: Escribir `test/fake-agy/agy`** con las cuatro invocaciones de comando y el log. Los
  escenarios de prompt llegan en las Tasks 3 y 4.

- [ ] **Step 3: Escribir los tests que fallan** en `test/agy-budget.sh`. Van al estilo de
  `detectores-y-vetos.sh`: funciones `ok`/`bad`, un `WORK` temporal y `PATH="$TEST/fake-agy:$PATH"`.

```bash
# cada caso escribe $FAKE_AGY_USAGE con filas reales de /usage (formato de la spec, sección 3.3)
holgada   (todas las filas ≥21%)                                  → exit 0
apretada  (una fila en 20%)                                       → exit 1
agotada   (una fila en 0%)                                        → exit 2
--model claude-sonnet-5-5-low, Gemini 5h en 0% y Claude en 50%    → exit 0
--model gemini-4-argon-low, "Gemini 4 Argon … Weekly Limit 0%"    → exit 2
--model gemini-pro-orchestrator-g1-pro, Argon en 0%               → exit 2
--model gemini-4-hydrogen-low, Argon en 0% y Gemini en 90%        → exit 0
--model modelo-raro                                               → exit 3
--tsv → 5 columnas; "Five Hour Limit Remaining" → 5h; "Weekly Limit Remaining" → semana
FAKE_AGY_USAGE_RC=1                                               → exit 3
/usage sin filas que parseen (texto libre)                        → exit 3
sin agy en el PATH                                                → exit 3
modo humano con FAKE_AGY_G1=true → la salida contiene "useG1Credits"
```

- [ ] **Step 4: Verificar que fallan.** `bash skills/cheap-fanout/test/agy-budget.sh` debe dar FAIL,
  porque todavía no existe `bin/agy-budget`.

- [ ] **Step 5: Implementar `bin/agy-budget`.**
  - Corre `timeout 30 agy -p /usage < /dev/null`.
  - Una fila válida tiene 4 campos separados por TAB y el tercero cumple `^[0-9]+%$`.
  - `/credits` y `/config` solo se consultan en modo humano.
  - La cabecera de uso sigue el estilo de `go-budget`.

- [ ] **Step 6: Verificar que pasan.** El mismo comando del Step 4 debe dar PASS.

- [ ] **Step 7: Commit**

```bash
git add skills/cheap-fanout/bin/agy-budget skills/cheap-fanout/test/fake-agy skills/cheap-fanout/test/agy-budget.sh
git commit -m "feat(agy-budget): cuota de Google leída de agy -p /usage"
```

### Task 2: Pre-vuelo de la puerta agy

**Files:**
- Modify: `skills/cheap-fanout/bin/cheap-fanout`: la cabecera de uso (cuarta forma del campo `model`),
  `bare_id()`, el bucle de pre-vuelo `need_*` y las constantes.
- Create: `skills/cheap-fanout/test/agy-puerta.sh`, sección 1.

**Interfaces:**
- **Consumes:** `test/fake-agy/agy` (`agy models` y el log).
- **Produces:**
  - `need_agy` (0 o 1) y `AGY_IDS` (los ids del lote, separados por espacio);
  - `AGY_ATTEST_FILE`;
  - `DENIED_STATUS=65`;
  - `bare_id` también quita el prefijo `agy:`.

**Mensajes exactos** (a stderr, con exit 2):

```
cheap-fanout: línea N: 'agy' necesita un id: agy:<id> (lista: agy models)
cheap-fanout: agy no está en PATH
cheap-fanout: FALTA LA ATESTACIÓN DE TELEMETRÍA — no se lanzó ningún job del lote.
cheap-fanout: los términos de Antigravity usan tus interacciones para mejorar los modelos de Google
cheap-fanout: salvo que apagues la telemetría. Una vez: abre `agy`, entra a /config y apaga "Enable Telemetry";
cheap-fanout: luego deja constancia:  mkdir -p <dir de AGY_ATTEST_FILE> && date -I > <AGY_ATTEST_FILE>
cheap-fanout: id(s) de agy desconocido(s): <ids> — no se lanzó ningún job. Válidos: <ids separados por coma>
```

- [ ] **Step 1: Escribir los tests que fallan** en la sección 1 de `agy-puerta.sh`. La atestación vive
  en `XDG_CONFIG_HOME=$WORK/cfg`.

```bash
a) jobs.tsv con agy:grok-4.7 (vetado vía bare_id)        → exit 2 y $FAKE_AGY_LOG vacío
b) jobs.tsv con 'agy' pelado                             → exit 2, stderr contiene "necesita un id"
c) sin $WORK/cfg/cheap-fanout/agy-telemetry-off          → exit 2, stderr contiene "FALTA LA ATESTACIÓN", ningún "-p" en el log
d) agy:gemini-4-argon-xhigh (no existe)                  → exit 2, stderr nombra el id, ningún "-p" en el log
e) lote sin jobs agy y sin atestación                    → $FAKE_AGY_LOG vacío (nunca llama a agy)
f) atestación + agy:gemini-4-hydrogen-low válido         → pasa el pre-vuelo y el job se lanza (hay un "-p" en el log)
```

- [ ] **Step 2: Verificar que fallan.** `bash skills/cheap-fanout/test/agy-puerta.sh` debe dar FAIL en a
  hasta f.

- [ ] **Step 3: Implementar.**
  - En el `case` de pre-vuelo, `agy)` sale con exit 2 y `agy:*)` pone `need_agy=1` y agrega el id.
  - Tras el bucle, solo si `need_agy=1`, en este orden:
    - comprobar que agy está en el PATH;
    - comprobar la atestación;
    - hacer **una** llamada a `agy models`. Los ids son el primer campo de cada línea con TAB, y el
      caché temporal se borra en el `trap EXIT` existente.
  - Los vetos se siguen comprobando antes que todo lo de agy.

- [ ] **Step 4: Verificar.** Deben pasar la sección 1 de `agy-puerta.sh` y los tres tests existentes.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(helper): pre-vuelo de la puerta agy (atestación, ids, vetos)"
```

### Task 3: Ejecución de jobs agy y estados

**Files:**
- Modify: `skills/cheap-fanout/bin/cheap-fanout`: las funciones nuevas van antes de `run_one`; la rama
  `agy:*)` va dentro del `case "$model"` de `run_one`.
- Modify: `skills/cheap-fanout/test/fake-agy/agy` (escenarios de prompt).
- Modify: `skills/cheap-fanout/test/agy-puerta.sh`, sección 2.

**Interfaces:**

- **Consumes:**
  - de la Task 2: `need_agy` y `DENIED_STATUS`;
  - del helper actual: `norm_timeout`, `HAVE_TIMEOUT`, `KILL_AFTER`, `REPO` y el chequeo de argv de
    `run_one`, que ya corre antes del `case`.

- **Produces:**
  - **`agy_settings_json`.** Imprime el JSON exacto de las Global Constraints según
    `CHEAP_FANOUT_AGY_WRITE`.
  - **`agy_print_timeout <tspec>`.** Recibe `Ns`, `Nm`, `Nh` o `N` e imprime `"<n>s"`, o `""` si no
    hay plazo.
    - Regla: si son 60 s o más, resta 20 s; si son menos, resta `max(2, secs/4)` (división entera).
  - **`agy_parse_result <ndjson> <out_file>`.**
    - Escribe en `out_file` la `response` del **último** evento `result`.
    - Imprime una línea `status<TAB>finished_reason<TAB>error`, con los campos vacíos si faltan.
    - Exit 0 si hubo `result`, 1 si no lo hubo, 2 si ninguna línea trae `event` (formato no
      reconocido).
  - **`agy_denied_perms <err_file>`.**
    - Imprime los permisos negados, únicos y uno por línea, con la regex
      `required the "([a-z_]+)" permission`.
    - Imprime `desconocido` si aparece `auto-denied` pero no se puede extraer el permiso.
    - No imprime nada si no hubo soft-deny.
  - **`run_agy <id> <prompt_file> <out_file> <tspec>`.**
    - Regresa el `.status` y deja los archivos de las Global Constraints.
    - Lee el prompt **antes** del `cd`.
    - Workspace sin `--dir`: `mktemp -d "${TMPDIR:-/tmp}/cheap-fanout-agy.XXXXXX"`, borrado al
      terminar (también tras un timeout). Con `--dir`, el workspace es `$REPO`.
    - El comando: `agy -p "$prompt" --model "$id" --output-format stream-json [--print-timeout "$pt"]
      --settings "$(agy_settings_json)" < /dev/null > "$of.log" 2> "$of.err"`. Va bajo el
      `timeout(1)` externo con el plazo completo.
    - Asignación de `.status`: gana el primero que aplique en el orden 65 → 124/137 → 66 →
      sin `result` → formato no reconocido → `rc` → 0.
    - Agrega una nota en `out_file` por cada condición detectada: `[cheap-fanout] DENEGADO`,
      `TIMEOUT`, `SALIDA VACÍA`, "sin evento result" y "formato de agy no reconocido". Cuando no hay
      `result`, la nota lleva la cola de `.err`.
    - Un soft-deny escribe `.denied`.

**Escenarios del agy falso** (token `ESCENARIO=<x>` dentro del prompt):

| x | stdout (NDJSON) | stderr | exit |
|---|---|---|---|
| `ok` | `init` y `result` SUCCESS con response `RESPUESTA-OK` | — | 0 |
| `vacio` | `result` SUCCESS con response `""` | — | 0 |
| `softdeny-vacio` | `result` SUCCESS `""` | El aviso real de la spec, sección 3.2 (permiso `"command"`) | 0 |
| `softdeny-resp` | `result` SUCCESS `"hice lo que pude"` | El mismo aviso, con el permiso `"write_file"` | 0 |
| `timeout` | `result` ERROR con response `PARCIAL` y `finished_reason` `print_timeout` | `AGY_ERROR: {"short_error":"print timeout…","status":"DEADLINE_EXCEEDED","retryable":false,"reason":"print_timeout"}` | 3 |
| `cuelga` | `init` y luego `sleep 30`, ignorando `--print-timeout` | — | (lo mata el timeout externo) |
| `sin-result` | `init` y un `step_update` | — | 0 |
| `raro` | `{"foo":1}` | — | 0 |
| `eco` | `result` SUCCESS cuya response es el prompt recibido, tal cual | — | 0 |
| `grande` | `result` SUCCESS con una response de 2,000,000 caracteres `x` | — | 0 |
| `pwd` | `result` SUCCESS con response `<cwd>\n<número de entradas del cwd>` | — | 0 |

- [ ] **Step 1: Escribir los tests que fallan** en la sección 2. Todos corren con la atestación
  presente y los modelos de `FAKE_AGY_MODELS`.

```bash
agy_print_timeout: 4m→220s · 90s→70s · 40s→30s · 8s→6s · 1h→3580s · ""→""
ok        → .status 0, out = "RESPUESTA-OK", .gate = "agy:gemini-4-hydrogen-low", existen .log y .err
argv      → trae --model gemini-4-hydrogen-low --output-format stream-json --settings <JSON solo lectura exacto>
          → con CHEAP_FANOUT_AGY_WRITE=1, --settings <JSON escritura exacto>
          → con plazo 4m trae "--print-timeout 220s"; con plazo none NO trae --print-timeout
vacio → 66 · softdeny-vacio → 65 y .denied = "command"
softdeny-resp → 65, out contiene "hice lo que pude" y "[cheap-fanout] DENEGADO", .denied = "write_file"
timeout → 124, out contiene "PARCIAL" y "[cheap-fanout] TIMEOUT"
cuelga con plazo 3s → 124 o 137, nota TIMEOUT, y el cwd del log ya no existe
sin-result → .status ≠ 0, nota "sin evento result" · raro → .status ≠ 0, nota "formato de agy no reconocido"
eco con prompt  comillas "dobles" y 'simples', ñ, $HOME, $(date), línea2⏎línea3  → out idéntico byte a byte
grande → out de 2,000,000 bytes "x" (se tolera un salto de línea final)
pwd sin --dir → cwd ≠ cwd del helper, 0 entradas, y ese directorio ya no existe
pwd con --dir $WORK/repo y prompt_file relativo al cwd del helper → cwd = $WORK/repo
6 jobs pwd con --parallel 6 → 6 cwd distintos; ninguno existe al final
prompt de 3000 bytes con CHEAP_FANOUT_ARGV_MAX=1000 → 64 y ningún "-p" en el log
lote mixto (CHEAP_FANOUT_NO_WARMUP=1): opencode falso que imprime "> build · x⏎OK" + agy:… ok → "2/2 OK"
```

- [ ] **Step 2: Verificar que fallan.** La sección 2 debe dar FAIL.

- [ ] **Step 3: Implementar** las funciones y la rama `agy:*)`, que llama a `run_agy`. El parseo usa
  `python3 -I -c` con un solo script, que lee el NDJSON línea por línea e ignora las líneas que no son
  JSON.

- [ ] **Step 4: Verificar.** Deben pasar las secciones 1 y 2 y los tres tests existentes.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(helper): jobs agy: workspace aislado, settings forzados y estados"
```

### Task 4: Cuota, transitorios, sesión vencida y resumen

**Files:**
- Modify: `skills/cheap-fanout/bin/cheap-fanout`: la rama agy de `run_agy`, el bucle de conteo del
  resumen y los mensajes finales.
- Modify: `skills/cheap-fanout/test/fake-agy/agy` (escenarios `cuota`, `transitorio` y `auth`).
- Modify: `skills/cheap-fanout/test/agy-puerta.sh`, sección 3.

**Interfaces:**

- **Consumes:**
  - `"$(dirname "$0")/agy-budget" --model <id> --tsv`, de la Task 1;
  - del helper actual: `cap_backoff_secs`, `CAP_RETRIES`, `CAP_STATUS` y `QUOTA_STATUS`.

- **Produces:**
  - **`agy_error_field <err_file> <campo>`.** Imprime el campo pedido del **último**
    `AGY_ERROR: {json}` de stderr, o nada si no hay.
  - **`is_agy_quota_sig <err_file> <ndjson> <rc>`.** Regresa 0 si se cumplen las tres condiciones:
    - `rc ≠ 0`;
    - `RESOURCE_EXHAUSTED`, `429` como número aislado o `quota` (sin distinguir mayúsculas) aparece en
      `AGY_ERROR.short_error`, `status` o `reason`, o en `result.error`;
    - `retryable` no es `true`.
  - **`agy_confirm_exhausted <id>`.**
    - Si `agy-budget --model <id> --tsv` sale con 2, regresa 0 e imprime
      `bolsa<TAB>ventana<TAB>reset_local` de la primera fila en 0%.
    - En cualquier otro caso regresa 1, incluido el de un `agy-budget` ausente.
    - Se cachea por id durante el lote, en un directorio temporal que se borra en el `trap EXIT`.
  - **El marcador `.quota`** y un contador `sincuota_agy` en el resumen, separado del de Go.

**Lógica dentro de `run_agy`:**

- **Cuota.** Una firma de cuota más `agy_confirm_exhausted` da 77, escribe `.quota` y agrega la nota
  `[cheap-fanout] CUOTA`.
- **Transitorio.** Si la firma no se confirma, o si `retryable` es `true`, el job se reintenta hasta
  `CAP_RETRIES` veces con `cap_backoff_secs` y escribe `.capretried`. Si persiste, da 76 con la nota
  `[cheap-fanout] SATURADO`.
- **Modo escritura.** Con `CHEAP_FANOUT_AGY_WRITE=1` no hay reintentos: da 76 directo, con una nota que
  dice que no se reintentó por ser un job de escritura.
- **Sesión vencida.** Si `authentication required` aparece en `.err` o en `result.error`, el status es
  el `rc` (nunca 77) y la nota es `[cheap-fanout] SIN SESIÓN`.
- **Orden final de asignación de `.status`**, que reemplaza el de la Task 3:
  65 → 124/137 → 77 → 76 → 66 → sin `result` → formato no reconocido → `rc` → 0.

**Escenarios del agy falso:**

| x | stdout | stderr | exit |
|---|---|---|---|
| `cuota` | `result` ERROR con error `Quota exhausted for model <id>` | `AGY_ERROR: {"short_error":"Quota exhausted…","status":"RESOURCE_EXHAUSTED","retryable":false,"reason":"quota_exhausted"}` | 1 |
| `transitorio` | `result` ERROR con error `backend unavailable` | `AGY_ERROR: {…,"status":"UNAVAILABLE","retryable":true,…}` | 1 |
| `auth` | — | `error: authentication required` | 1 |

En `transitorio`, el agy falso falla mientras `$FAKE_AGY_COUNTER` sea menor que `$FAKE_AGY_FAIL_TIMES`;
después se comporta como `ok`.

**Mensajes exactos del resumen** (a stderr):

```
cheap-fanout: SIN CUOTA DE GOOGLE (status=77) → <of>: bolsa "<bolsa>" (<ventana>) agotada; se resetea <reset_local>
cheap-fanout: la cuota de Google no se rescata: espera el reset (agy-budget te dice cuándo) o manda esos jobs a otra puerta.
cheap-fanout: DENEGADO (status=65) → <of>: agy negó <permisos separados por coma> en headless; revisa <of>.err y <of>.denied
cheap-fanout: SIN SESIÓN DE AGY → <of>: corre `agy` una vez en modo interactivo para iniciar sesión.
```

La línea final del resumen agrega `(N con acciones denegadas: revisa .err y .denied)` cuando N es
mayor que 0.

- [ ] **Step 1: Escribir los tests que fallan** en la sección 3. Todos corren con
  `CHEAP_FANOUT_CAP_RETRY_BASE=1` para que sean rápidos.

```bash
cuota + /usage con "Gemini Models / Five Hour … 0%"        → 77; .quota empieza con "Gemini Models<TAB>5h<TAB>"
                                                           → stderr contiene "SIN CUOTA DE GOOGLE" y NO contiene "Go tiene UNA bolsa"
cuota + /usage todo en 50%                                 → 1+CAP_RETRIES invocaciones "-p" en el log y .status 76
cuota con un bin/ copiado SIN agy-budget                   → 76
transitorio FAIL_TIMES=1                                   → .status 0 y .capretried = 1
transitorio FAIL_TIMES=9                                   → .status 76 tras 1+CAP_RETRIES invocaciones
transitorio FAIL_TIMES=9 con CHEAP_FANOUT_AGY_WRITE=1      → 1 sola invocación y .status 76
auth                                                       → .status 1, nota "SIN SESIÓN", stderr con la pista
lote: 1 job Go en 77 (opencode falso de cuota, como en detectores-y-vetos) + 1 agy en 77
                                                           → stderr trae los mensajes de las dos bolsas
lote con softdeny-resp                                     → exit del helper 1 y "(1 con acciones denegadas"
```

- [ ] **Step 2: Verificar que fallan.** La sección 3 debe dar FAIL.

- [ ] **Step 3: Implementar.** Dentro de `run_agy`, el ciclo de reintento reusa `cap_backoff_secs`. En
  el resumen, `sincuota` se reparte entre Go y agy según si `.gate` empieza con `agy:`.

- [ ] **Step 4: Verificar.** Deben pasar las secciones 1 a 3 y los tres tests existentes.

- [ ] **Step 5: Commit**

```bash
git commit -am "feat(helper): cuota de Google confirmada con agy-budget, transitorios y resumen"
```

### Task 5: `install.sh` y `plugin.json`

**Files:**
- Modify: `install.sh`: la sección "Dependencias" y la sección "Puertas configuradas".
- Modify: `.claude-plugin/plugin.json`: `version` a `1.7.0` y las keywords `antigravity` y `gemini`.
- Modify: `.claude-plugin/marketplace.json`, solo si tiene un campo de versión.

- [ ] **Step 1: Escribir el chequeo que falla.**
  - `./install.sh --check` debe listar `agy` bajo "Dependencias".
  - Bajo "Puertas configuradas", con `XDG_CONFIG_HOME` vacío, debe mostrar
    `⚠️  google (agy)     falta la atestación de telemetría (ver skill google-fanout)`.
  - Con el archivo presente, debe mostrar `✅ google (agy)     atestación de telemetría presente`.
  - Se comprueba corriendo los dos casos y buscando cada línea con `grep`.

- [ ] **Step 2: Implementar.**
  - Agregar `chk agy agy "opcional: habilita los jobs 'agy:' (cuota de Google AI Pro/Ultra)" 0`.
  - Agregar la línea de la puerta, que lee el mismo `AGY_ATTEST_FILE` del helper.

- [ ] **Step 3: Verificar.** `jq -r .version .claude-plugin/plugin.json` debe imprimir `1.7.0`, y los
  dos chequeos del Step 1 deben pasar.

- [ ] **Step 4: Commit**

```bash
git commit -am "chore: install.sh detecta agy y la atestación; versión 1.7.0"
```

### Task 6: Banco de extracción en el repo

**Files:**
- Create: `skills/cheap-fanout/test/bench-extraccion/gen.py`, `grade.py` y `prompt.md`. Se copian del
  scratchpad (`…/scratchpad/bench/tools/gen.py`, `tools/grade.py` y `prompt.md`).
- Create: `skills/cheap-fanout/test/bench-extraccion/autoprueba.sh`

**Interfaces:**
- **`python3 -I gen.py <dir>`** escribe `<dir>/fuente.md` y `<dir>/expected.json`. Es determinista
  (semilla `20261121`), y el sha256 de `fuente.md` es
  `2116c44e21f831f7dbb1135543e9621f521354853921c305558e17c50ff71a9e`.
- **`python3 -I grade.py [--tolerante] <expected.json> <fuente.md> <salida.txt>`** imprime
  `N/31 FIN=si|NO malos=[…]`.
  - `--tolerante` acepta líneas que empiezan con `<n>|` en lugar de `FILA|`, y líneas sin el `|` final.

- [ ] **Step 1: Copiar los tres archivos y escribir `autoprueba.sh`.**

```bash
gen.py dos veces en dirs distintos → mismo sha256, igual al fijado arriba
respuesta perfecta construida desde expected.json → "31/31 FIN=si"
la misma con "<n>|" en lugar de "FILA|"           → estricto "0/31", --tolerante "31/31"
respuesta sin ===FIN===                           → "FIN=NO"
```

- [ ] **Step 2: Verificar que falla.** `bash …/bench-extraccion/autoprueba.sh` debe fallar en el caso
  `--tolerante`.

- [ ] **Step 3: Implementar `--tolerante`** en `grade.py` y hacer que `gen.py` reciba el directorio de
  salida.

- [ ] **Step 4: Verificar.** `autoprueba.sh` debe dar PASS.

- [ ] **Step 5: Commit**

```bash
git commit -m "test: banco de extracción de 31 filas (fixture determinista)"
```

### Task 7: Banco de pre-revisión sembrado

**Files:**
- Create: `skills/cheap-fanout/test/bench-prerevision/sembrar.py`, `calificar.py` y `autoprueba.sh`

**Interfaces:**

- **`python3 -I sembrar.py <dir-con-fuente.md> <out-dir>`.** Es determinista (semilla `20261121`) y
  escribe:
  - 8 unidades `U1` a `U8`, cada una con `prompt-Uk.md` (extraer las filas a..b de `fuente.md` en
    formato FILA, con `===FIN===`) y `Uk.out` (la salida del "agente");
  - `prompt-PREREV.md`, que es la plantilla de pre-revisión por referencia del SKILL.md de
    cheap-fanout con los 8 pares;
  - `clave.json`, por ejemplo `{"U1":"OK","U3":"FALLO:numero",…}`.
- **Cómo se reparten las 8 unidades:** 2 limpias y 6 sembradas, una falla por unidad:
  - un número alterado frente a la fuente;
  - dos filas intercambiadas junto con sus citas;
  - dos filas omitidas, con `===FIN===` presente;
  - una fila inventada con una cita fabricada;
  - una salida truncada, sin `===FIN===`;
  - una cita no textual (una palabra cambiada).
- **`python3 -I calificar.py <clave.json> <salida-del-prerevisor>`** imprime
  `aciertos=N/8 falsos_ok=K falsas_alarmas=M fin=si|NO`.
  - Una unidad sembrada acierta si su veredicto es DUDOSO o FALLO.
  - Una unidad limpia acierta si su veredicto es OK.

- [ ] **Step 1: Escribir `autoprueba.sh`.**

```bash
sembrar dos veces                                         → árboles idénticos (sha256 de cada archivo)
salida simulada con ===VEREDICTOS=== tomados de la clave → "aciertos=8/8 falsos_ok=0 falsas_alarmas=0 fin=si"
todas las unidades en OK                                  → "falsos_ok=6"
salida sin ===FIN===                                      → "fin=NO"
```

- [ ] **Step 2: Verificar que falla.**

- [ ] **Step 3: Implementar `sembrar.py` y `calificar.py`.**

- [ ] **Step 4: Verificar.** `autoprueba.sh` debe dar PASS.

- [ ] **Step 5: Commit**

```bash
git commit -m "test: banco de pre-revisión con 6 fallas sembradas"
```

### Task 8: Mediciones en vivo

**Requisito previo.** `test -f "${XDG_CONFIG_HOME:-$HOME/.config}/cheap-fanout/agy-telemetry-off"`. Si
el archivo no existe, **detente y pregúntale a Antonio**. No hay rodeo.

**Presupuesto.** Como máximo 4 jobs en la bolsa "Claude and GPT models" en toda la task. Cada corrida
se registra con su comando, sus números y la fecha y hora de CDMX.

**Files:**
- Create: `Bugs/hallazgos-2026-11-21.md`. Lleva la evidencia de la spec (sección 3, con sus citas y
  fuentes) y los resultados de los pasos de abajo.

- [ ] **Step 1: Medir la cuota de arranque.** Correr `bin/agy-budget` y guardar la salida.

- [ ] **Step 2: Smoke mixto.** Cuatro jobs PONG con `deepseek-v4.1-flash`,
  `agy:gemini-4-hydrogen-low`, `agy:gemini-4-neon-low` y `agy:claude-sonnet-5-5-low`.
  - Esperado: `4/4 OK` y cada `.gate` correcto.

- [ ] **Step 3: Regla deny y sandbox.**
  - a) Job de solo lectura que intenta escribir `nota.txt` con la herramienta de escritura.
    Esperado: 65 con `write_file` en `.denied`, o 0 sin el archivo. Anotar cuál de los dos pasó.
  - b) Job de solo lectura que corre `touch /tmp/cfagy-<aleatorio>`. Esperado: el archivo no existe al
    terminar.
  - c) Job con `CHEAP_FANOUT_AGY_WRITE=1` y `--dir` apuntando a un `git worktree` temporal. Esperado:
    el archivo se crea y el status es 0.
  - Si a) o b) fallan, **detente**: la postura de solo lectura de la spec (5.1) se revisa con Antonio
    antes de seguir.

- [ ] **Step 4: Unidad web.** La unidad de la fecha de lanzamiento de Hydrogen con
  `gemini-4-hydrogen-low`, `gemini-4-hydrogen-medium` y `gemini-3.8-flash-low`, con la regla deny
  activa.
  - Correcto = `2026-11-12` más la URL de blog.google.
  - Registrar los tiempos.

- [ ] **Step 5: Concurrencia.** 12 jobs simultáneos de extracción con `agy:gemini-4-hydrogen-low`
  (`--parallel 12`). Registrar cuántos salen OK y el tiempo de pared.

- [ ] **Step 6: Extracción con el banco de la Task 6.** Dos corridas por modelo, salvo Sonnet.
  - agy: `gemini-4-hydrogen-low`, `gemini-4-hydrogen-medium`, `gemini-4-neon-low`,
    `gemini-4-neon-medium` y `gemini-3.8-flash-low`.
  - Sonnet: `claude-sonnet-5-5-low`, una sola corrida.
  - Go: `deepseek-v4.1-flash`, `glm-5.3-flash` y `hy4-flash-free`.
  - Registrar la calificación estricta y la tolerante, los tiempos y los tokens.

- [ ] **Step 7: Pre-revisión con el banco de la Task 7.** Pre-revisores: `agy:gemini-4-neon-medium`,
  `agy:gemini-4-hydrogen-high`, `deepseek-v4.1-flash` y `codex:gpt-6.1-terra`. Pasar cada salida por
  `calificar.py`.

- [ ] **Step 8: Medir el gasto.** Correr `bin/agy-budget` otra vez y calcular la diferencia por bolsa.
  Es una medida gruesa, en puntos por job.

- [ ] **Step 9: Escribir y commitear los hallazgos.**

```bash
git add Bugs/hallazgos-2026-11-21.md && git commit -m "docs(hallazgos): mediciones de la puerta agy del 2026-11-21"
```

### Task 9: El skill `google-fanout` (RED → GREEN)

**Files:**
- Create: `skills/google-fanout/SKILL.md`, de 12 KB como máximo.
- Create: `skills/google-fanout/reference/agy.md`: el CLI, el envelope, los estados, las tablas medidas
  y las fuentes.
- Create: `skills/google-fanout/test/escenarios.md`, `baseline.md` y `con-skill.md`.

**Escenarios** (`escenarios.md`, cada uno con su conducta esperada):

| | Situación | Conducta esperada |
|---|---|---|
| E1 | Investigar 10 temas públicos sin URL de arranque | Puerta agy con Hydrogen (`search_web`), atestación revisada, `agy-budget` antes del lote y revisión al final |
| E2 | Resumir 30 documentos del expediente de un cliente | **No** usar agy: Go con 0 días de retención, o hacerlo local |
| E3 | Segunda opinión casi-frontier sobre un diseño público | `agy:gemini-4-neon-xhigh` o `codex:gpt-6.2-astra`; nunca Claude por agy como ancho |
| E4 | La bolsa de Go está agotada y faltan 40 extracciones públicas | `agy:gemini-4-hydrogen-low` después de `agy-budget`; nunca créditos |
| E5 | Auditar el repo de un cliente buscando un patrón | No usar agy, o solo con `--dir` a un worktree de material público; si no lo hay, no agy |

- [ ] **Step 1: Correr la línea base (RED).** Cada escenario va 5 veces con el sujeto
  `agy:gemini-4-neon-medium`, un modelo fuera de Anthropic (spec 5.5).
  - El prompt da la ruta al SKILL.md de cheap-fanout y el escenario, y termina con: "describe
    exactamente qué lanzarías: jobs.tsv y comandos".
  - La salida va **textual** a `baseline.md`, con cada falla clasificada.

- [ ] **Step 2: Escribir `SKILL.md` (GREEN).**
  - Frontmatter: `name: google-fanout`.
  - La `description` empieza con "Use when" e incluye estos disparadores: agy, Antigravity, Gemini 4,
    Neon, Argon, Hydrogen, Orchestrator, "cuota de Google", "investigar sin URL", "segunda opinión
    Claude sin gastar Max" y "bolsa de Go apretada".
  - Las secciones salen de la spec (5.3).
  - El ruteo sale de los resultados de la Task 8.
  - Cada falla de la línea base tiene una regla que la contesta.

- [ ] **Step 3: Volver a correr con el skill.** Los 5 escenarios, 5 veces cada uno, con el skill
  incluido. La salida va a `con-skill.md`.
  - Cada repetición debe coincidir con la conducta esperada.
  - Se leen **todas** las salidas a mano.

- [ ] **Step 4: Cerrar huecos (REFACTOR).** Corregir los huecos que aparezcan y volver a correr los
  escenarios que fallaron.

- [ ] **Step 5: Presión final.** Dos subagentes nuevos de Anthropic, en E2 y E5, con el skill cargado.
  Ninguno debe mandar material del cliente por agy.

- [ ] **Step 6: Revisar el texto.** `grep -nE '\$[0-9]' skills/google-fanout/SKILL.md
  skills/google-fanout/reference/agy.md` no debe imprimir nada.

- [ ] **Step 7: Commit**

```bash
git add skills/google-fanout && git commit -m "feat(skill): google-fanout — ruteo, cuota y privacidad de la puerta agy"
```

### Task 10: Referencias en cheap-fanout, README y CHANGELOG

**Files:**
- Modify: `skills/cheap-fanout/SKILL.md`:
  - En *Uso del helper*: "El `<model>` admite tres formas" pasa a cuatro, con un bullet para
    `agy:<id>`. Al bloque de comandos se agrega la línea de `agy-budget`.
  - En la tabla "Los tres presupuestos activos": pasa a cuatro y gana una fila Google con
    `agy:gemini-4-hydrogen-low` / `agy:<id>`. Su descripción: dos bolsas (Gemini; Claude y GPT) con
    ventanas de 5 h y semanal, más el límite semanal de Argon, y solo material público o no sensible.
    Después de la tabla va un puntero al skill **google-fanout**.
  - En *Troubleshooting*: la lista de `.status` agrega `65`.
- Modify: `README.md`: la puerta, el skill, `agy-budget` y el requisito de la atestación.
- Modify: `CHANGELOG.md`: una entrada `## [1.7.0]` con la misma estructura que la 1.6.1 (Estado del
  release, ⚠ Cambio de comportamiento, Verificación).
- Modify: `skills/cheap-fanout/bin/cheap-fanout`: la cabecera de uso, si no quedó completa en las Tasks
  2 a 4.

- [ ] **Step 1: Editar los cuatro archivos.**

- [ ] **Step 2: Revisar el texto.** `grep -nE '\$[0-9]' skills/cheap-fanout/SKILL.md` no debe imprimir
  nada.

- [ ] **Step 3: Verificar.** Correr todos los tests (lista en la Task 11): todos PASS.

- [ ] **Step 4: Commit**

```bash
git commit -am "docs: puerta agy en cheap-fanout, README y CHANGELOG 1.7.0"
```

### Task 11: Revisión final

- [ ] **Step 1: Correr todos los tests.** Todos deben dar PASS:
  - `test/detectores-y-vetos.sh`, `test/dos-lotes.sh` y `test/sqlite-race.sh`;
  - `test/agy-budget.sh` y `test/agy-puerta.sh`;
  - `test/bench-extraccion/autoprueba.sh` y `test/bench-prerevision/autoprueba.sh`.

- [ ] **Step 2: Revisión de la rama completa.** Con `codex:gpt-6.2-astra`, en solo lectura y con
  `--dir` al repo.
  - El prompt da la ruta de la spec y pide leer `git diff main...feat/google-fanout`.
  - Pide bugs de correctitud, ordenados por gravedad.

- [ ] **Step 3: Corregir.** Cada hallazgo confirmado recibe su test. Volver a correr todo y commitear.

- [ ] **Step 4: Instalar.** Correr `./install.sh`. `ls -l ~/.claude/skills/google-fanout` debe mostrar
  el symlink al repo.

- [ ] **Step 5: Reportar a Antonio.** Merge y push solo si él lo pide.

# google-fanout — la puerta `agy:` de cheap-fanout (diseño)

- **Fecha:** 2026-11-21
- **Estado:** borrador para aprobación de Antonio
- **Enfoque elegido:** A (puerta `agy:` en el helper actual + skill `google-fanout` aparte)
- **Evidencia:** la sección 3 resume lo verificado ese día. Las salidas crudas viven en el scratchpad de
  la sesión y se pasan a `Bugs/hallazgos-2026-11-21.md` como parte del trabajo (ver 5.6).

## 1. Intención

Antonio paga Google AI Pro. Con ese plan, el CLI oficial de Google Antigravity (`agy`) corre en modo
headless Gemini 4 (Neon, Argon, Hydrogen), Orchestrator, Gemini 3.8 Flash, Claude Opus y Sonnet 5.5 y
GPT-OSS 120B. Lo hace con una cuota propia, que no toca los tokens de Anthropic, la bolsa de OpenCode Go
ni la cuota de ChatGPT.

La meta es usar esa cuota como **un presupuesto más del fan-out barato**, con la disciplina de
cheap-fanout: el orquestador (Claude) planea, rutea, revisa y sintetiza, y los modelos baratos absorben
el ancho.

La puerta trae tres cosas que las otras no tienen:

1. **`search_web`**, la búsqueda de Google con grounding. Permite investigar temas long-tail sin URL de
   arranque: los agentes de Go solo tienen `webfetch` y los de Codex no tienen web.
2. **Gemini 4 Neon a esfuerzo xhigh**, con índice 61 en Artificial Analysis v5.0.1, por encima de Opus
   5.5 a esfuerzo max (59), sin costo marginal.
3. **Asientos de la familia Claude** (Sonnet y Opus 5.5) que no gastan la ventana del plan Max.

## 2. Metas, no-metas y anti-metas

### Metas

1. **La puerta.** `agy:<id>` se vuelve la cuarta forma del campo `model` de `jobs.tsv` en el helper
   existente `bin/cheap-fanout`, con sus mismas garantías:
   - paralelismo acotado y plazo por job;
   - `.status` confiable, `.gate` y resumen final;
   - exit code igual al número de fallos;
   - lotes mixtos (Go, Codex y agy) en un solo `jobs.tsv`.
2. **`bin/agy-budget`**, el gemelo de `go-budget` para la cuota de Google.
3. **El skill `skills/google-fanout/SKILL.md`.** Dice cuándo usar la puerta y cubre el ruteo entre
   modelos de Google, la cuota, la privacidad, los términos de uso, la mecánica y el troubleshooting.
   cheap-fanout solo gana referencias cortas (5.4).
4. **Pruebas:** locales y sin costo (un `agy` falso en el PATH), más un smoke test en vivo documentado.
5. **Evidencia** en `Bugs/hallazgos-2026-11-21.md`, versión 1.7.0, CHANGELOG y README, como en cada
   release del repo.

### No-metas (v1)

- **Modo delegado:** usar Orchestrator, `run_workflow` o `/swarm` como motor del fan-out. Se documenta
  como capacidad; no se implementa ni se recomienda hasta medirlo en headless.
- **Otras vías de agy:** el SDK de Python (`google-antigravity`), los agentes remotos
  (`--remote-agent`), MCP y `--json-schema`. Este último puede llegar después, para pre-revisores.
- **`PORTABLE-SPEC.md`:** no se actualiza, porque la otra computadora no tiene agy.
- **Windows:** sin soporte probado para la puerta agy.
- **Sin fallback automático** entre puertas ni entre modelos. Es la regla de cheap-fanout: cambiar de
  modelo cambia la calidad y lo decide el orquestador.

### Anti-metas

Si pasa cualquiera de estas cosas, el trabajo falló aunque funcione:

- **Violar los términos de Antigravity (3.4):** extraer o reusar el token OAuth fuera de `agy`, llamar
  endpoints de Google directo o usar herramientas de terceros en lugar del binario oficial.
- **Material sensible o del cliente** que llega a Google por esta puerta.
- **Gasto de dinero:** que cualquier job pueda consumir AI credits.
- **Falsos OK:** que un job sin trabajo hecho pase como OK (el soft-deny de 3.2).
- **El ancho en la bolsa equivocada:** gastar en el ancho la bolsa "Claude and GPT models" de Google.
- **Regresiones:** cambiar el comportamiento de las puertas opencode y codex, o romper sus tres tests.

## 3. Restricciones (verificadas el 2026-11-21)

### 3.1 Cuenta y modelos

**La cuenta es Google AI Pro pagado.** No se ve directo; se deduce de `agy models`:

- La lista incluye Orchestrator, Claude 5.5 y GPT-OSS, que `docs/models` marca como disponibles solo
  en Pro pagado.
- La lista no incluye Gemini 4 Carbon, que es exclusivo de Ultra.

**El CLI.** Es `agy` 1.5.14, en `~/.local/bin/agy`. Se autoactualiza: pasó de 1.5.10 a 1.5.14 durante
la sesión.

**Los ids** de `agy`. El nivel de esfuerzo va en el id:

- `gemini-4-neon-{low,medium,high,xhigh}`
- `gemini-4-argon-{low,medium,high}`
- `gemini-4-hydrogen-{low,medium,high,xhigh}`
- `gemini-pro-orchestrator-neon` (planner Neon) y `gemini-pro-orchestrator-g1-pro` (planner Argon)
- `gemini-3.8-flash-{low,medium,high}`
- `claude-opus-5-5-{low,medium,high}` y `claude-sonnet-5-5-{low,medium,high}`
- `gpt-oss-120b-medium`

**Capacidades.** Medido = esta máquina el 2026-11-21: un PONG y una extracción de 31 filas con cita
desde un archivo local de 3 KB, 8 modelos en paralelo, una corrida por modelo.

| Modelo | Qué es | Contexto en Antigravity | Índice AA v5.0.1 | Medido |
|---|---|---|---|---|
| Neon | Salió el 2026-11-18. Está entre Hydrogen y Carbon y es el planner por default de Orchestrator | **512K** (1M en la API) | 61 xhigh · 60 high · 55 medium · 44 low | PONG 5 s · extracción 21 s, 31/31 |
| Argon | Frontier del 2026-09-30; salida de hasta 1M. Tiene **límite semanal propio** (3.3) | 1M | 50 (high) | PONG 9 s · extracción 23 s, 31/31 |
| Hydrogen | Salió el 2026-11-12. Reemplaza a Flash y es el ejecutor por default de Orchestrator | 1M de entrada, 1M de salida | 54 xhigh · 51 high · 41 medium · 27 low | PONG 5 s · extracción 11 s (low) y 16 s (medium), 31/31 |
| Orchestrator | No es un router. En una conversación, el planner explora en solo lectura, planea y revisa, y el ejecutor (Hydrogen) trabaja y le regresa el control si algo falla dos veces | — | — | PONG 6 s · extracción 51 s, 31/31 (6.1K tokens de razonamiento) |
| Gemini 3.8 Flash | Modelo de todos los planes | 1M de entrada, 65K de salida | sin dato | PONG 4 s · extracción 15 s, **formato roto** · unidad web 40 s |
| Claude Sonnet 5.5 | Bolsa "Claude and GPT models" | — | 55 (a esfuerzo max; en agy el tope es high) | PONG 4 s · extracción 11 s, 31/31 |
| Claude Opus 5.5 | Bolsa "Claude and GPT models" | — | 59 (a esfuerzo max) | PONG 4 s |
| GPT-OSS 120B | Bolsa "Claude and GPT models" | — | — | PONG 3 s · extracción 33 s, **formato roto** |

- **Formato roto:** Flash y GPT-OSS escribieron el número de fila en lugar del literal `FILA|`. Con
  calificación tolerante, ambos sacan 31/31. Es una corrida por modelo, así que la evidencia es
  delgada.
- **Fuentes de las capacidades:** `antigravity.google/docs/models` (disponibilidad por plan, 512K de
  Neon, Orchestrator), los posts de blog.google de Argon e Hydrogen, el blog de Antigravity sobre Neon y
  `artificialanalysis.ai/models/comparisons/gemini-4-neon-vs-gemini-4-hydrogen`.
- **Precios de API** (informativos, sin releer en primaria): Hydrogen 1.50/7.50 USD, Neon 3/15 y Argon
  2/10, que sube a 4/20 el 2026-12-01. Solo importarían si se gastaran créditos, cosa que este diseño
  impide.

### 3.2 Mecánica headless (medida)

**El comando:**

```
agy -p "<prompt>" --model <id> --output-format json|stream-json --print-timeout <T> --settings '<json>'
```

**El envelope JSON** trae:

- `conversation_id`, `status`, `response`, `error`, `duration_seconds`, `num_turns`;
- `usage`, con `input_tokens`, `output_tokens`, `thinking_tokens`, `cache_read_tokens` y
  `total_tokens`;
- `finished_reason`, solo cuando la corrida terminó antes de tiempo;
- `structured_output`, solo con `--json-schema`.

**`stream-json`** emite tres tipos de evento:

- `init`, con el modelo y el cwd;
- `step_update`, con `step_type` (`user_input`, `agent_response`, `tool` o `system_message`),
  `tool_name`, `tool_info.parameters` y `state` (`ACTIVE` o `DONE`);
- `result`, con el mismo envelope.

**Códigos de salida:**

- **0:** éxito.
- **1:** modelo desconocido, con `status: ERROR` y sin fallback (la doc lo garantiza para headless).
- **3:** venció `--print-timeout`. El envelope trae `status: ERROR` y
  `finished_reason: "print_timeout"`, y stderr trae:
  `AGY_ERROR: {"short_error":"…","status":"DEADLINE_EXCEEDED","retryable":false,"reason":"print_timeout"}`.

**Soft-deny, medido.** En modo `default` (con `--settings '{"agentMode":""}'`), un comando de shell
salió con **exit 0, `status: SUCCESS` y `response` vacía**, y este aviso en stderr:

```
jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied. Add an allow-rule under permissions.allow in settings.json (e.g. command(<target>)). Alternatively, re-run with --dangerously-skip-permissions to auto-approve all tools.
```

La doc dice lo mismo: *"the run continues, exits `0`, and prints a notice to `stderr` naming the tool
and how to allow it"*. Eso implica que también puede haber soft-deny con respuesta no vacía.

**Modo `auto`.**

- Sin `agentMode` en settings, `-p` corre en `auto` desde la v1.5.7.
- En `auto`, los comandos corren en un sandbox con la red filtrada: un GET a blog.google pasó y un POST
  a httpbin.org no resolvió DNS.
- La web entra por `search_web`. El agente lee las páginas con curl o python vía `run_command`.

**Costo y concurrencia.**

- Cada job arranca con unos 11K tokens de entrada (sistema y herramientas).
- 8 instancias simultáneas, dos veces, sin choques. No está medido arriba de 8 ni con el estado local
  en frío.

**`--settings`** aplica claves de `settings.json` solo a esa corrida. Verificado: `'{"agentMode":""}'`
cambió el modo y `'{"useG1Credits":false}'` corrió sin error.

**Herramientas del agente headless:** `ask_question`, `define_subagent`, `edit_file`,
`invoke_subagent`, `manage_subagents`, `manage_task`, `read_file`, `run_command`, `run_workflow`,
`schedule`, `search_web`, `send_message`, `swarm` y `write_file`.

**Settings actuales de Antonio** (`agy -p /config`):

- `agentMode`: `auto`
- `allowNonWorkspaceAccess`: **`true`** (el default es `false`)
- `toolPermission`: `request-review`
- `enableTerminalSandbox`: `false`
- `useG1Credits`: `false`
- `model`: `Gemini 3.5 Flash (High)`. Está obsoleto, porque ya no aparece en `agy models`; de ahí que
  `--model` sea obligatorio.

**Créditos:** `agy -p /credits` reporta 0.

### 3.3 Cuota

**`agy -p "/usage"`** tarda 2 s y no llama al modelo. Devuelve TSV con
`familia <TAB> ventana <TAB> % restante <TAB> reset en ISO UTC`. Filas vistas:

```
Gemini Models          Weekly Limit Remaining        99%  2026-11-28T18:48:17Z
Gemini Models          Five Hour Limit Remaining     98%  2026-11-21T23:48:17Z
Claude and GPT models  Weekly Limit Remaining        97%  2026-11-28T18:48:33Z
Claude and GPT models  Five Hour Limit Remaining     94%  2026-11-21T23:48:33Z
Gemini 4 Argon         Gemini 4 Argon Weekly Limit   99%  2026-11-28T18:48:33Z
```

**Cómo leerlo:**

- Las ventanas arrancan en el primer uso.
- Los porcentajes son enteros y llegan con retraso: la bolsa Gemini osciló entre 98 y 99.
- Medido: 16 jobs de Gemini bajaron 2 puntos la ventana de 5 h de su bolsa, y **5 jobs de Claude/GPT
  bajaron 6 puntos la suya**.

**`docs/plans`:**

- En Pro, la cuota se refresca cada 5 horas hasta topar con el límite semanal.
- *"the rate limits correlate with the amount of work done by the agent"*.
- No publica cifras.

**AI credits:**

- Son dinero real, a precio de Gemini Enterprise.
- `useG1Credits` viene en `false` por default (`docs/cli/reference`).
- No hay BYOK.

**Error de cuota: firma NO verificada.** El binario contiene `Quota exhausted`, y una doc interna lo
describe como `` `RESOURCE_EXHAUSTED`, 429 ``. agy reintenta solo los 429 y 5xx, respetando
`Retry-After` (changelog 1.5.x).

### 3.4 Privacidad y términos

Citas textuales de `antigravity.google/terms`, salvo donde se indica otra fuente.

**Cláusula 5.** *"We use Interactions to evaluate, develop, and improve Google and Alphabet research,
products, services and machine learning technologies. […] Google employees and contractors may access,
view, review and use Interactions. Please don't submit confidential information […]. If you don't want
your Interactions used in this way, navigate to settings to change your preference on how such data is
used. Even when your Telemetry is toggled off, Google still uses your data to provide the service,
process any feedback and help keep Antigravity safe."*

**El opt-out** es *Enable Telemetry* en `/config`. Según `docs/cli/reference`, *"has no
`settings.json` key: the CLI saves that choice with your account"*. No aparece en `agy -p /config`, así
que **no se puede verificar desde un script**.

**Cláusula 6.** *"Using third party software, tools, or services to access the Service (e.g. using
OpenClaw with Antigravity OAuth) is a breach of this Agreement. Such actions may be grounds for
suspension or termination of your Antigravity and/or Gemini CLI accounts."* La misma cláusula prohíbe
usar el servicio *"in connection with products not provided by us"*.

**Contrapeso** (`docs/cli/headless`): *"Run Antigravity CLI non-interactively to script agent tasks,
integrate with CI pipelines, and capture machine-readable output."* Invocar el binario oficial en
headless es uso documentado; el riesgo residual viene de lo amplio de la cláusula 6.

**Retención en días:** no publicada.

## 4. Enfoques

| | Enfoque | Gana | Pierde |
|---|---|---|---|
| **A (elegido)** | Puerta `agy:` en `bin/cheap-fanout`, más `agy-budget` y un skill `google-fanout` aparte | Reusa lo ya probado (plazos, `.status`, reintentos, vetos, resumen). Permite lotes mixtos. Una sola herramienta | Crece un helper de 700 líneas y hay que cuidar sus tests |
| B | Skill y helper independientes (`agy-fanout`) | Aislamiento total de cheap-fanout | Lógica duplicada, sin lotes mixtos, dos herramientas que se desfasan |
| C | Modo delegado: un `agy -p` con Orchestrator o `run_workflow` reparte por dentro | Menos plomería local | Sin control por unidad (`run_workflow` solo ofrece niveles `flash`/`pro`), sin probar en headless, y según la doc los swarms consumen cuota "mucho más rápido" |

Antonio eligió A el 2026-11-21.

## 5. Diseño

### 5.1 La puerta `agy:` en `bin/cheap-fanout`

**Forma.** `agy:<id>`, con el id exacto de `agy models`. No existe un `agy` pelado (a diferencia de
`codex`), porque el default de settings está obsoleto.

**Pre-vuelo.** Corre solo si el lote trae jobs agy. Si falla, sale con exit 2 sin lanzar nada:

1. **`agy` en el PATH.**
2. **Atestación de telemetría apagada.** Debe existir `~/.config/cheap-fanout/agy-telemetry-off`.
   Antonio lo crea una vez, tras apagar *Enable Telemetry*; el contenido es libre, por ejemplo la
   fecha. Si falta, el mensaje explica cómo apagarla y cómo crear el archivo. No hay override por
   variable de entorno: crear el archivo **es** la decisión.
3. **Ids válidos.** Se validan contra `agy models` con una sola llamada, que además calienta el estado
   local. Un id desconocido aborta el lote y el mensaje lista los válidos.
4. **Vetos.** `bare_id()` también quita el prefijo `agy:`, así que la lista `VETOED` aplica igual.

**Ejecución por job:**

- Leer el prompt **antes** de cambiar de directorio.
- **Workspace.** agy usa el cwd como workspace y, con `allowNonWorkspaceAccess:false`, no ve nada fuera
  de él.
  - **Default:** un directorio temporal **vacío y propio de cada job**, que se borra al terminar. Así
    un job de agy nunca ve el cwd del helper, que podría ser el repo de un cliente.
  - **Con `--dir`:** el job corre en `$REPO`. Esa bandera es la forma explícita de mostrarle archivos,
    y el orquestador solo la apunta a un directorio cuyo contenido completo puede ver Google: el
    directorio del lote o un worktree de material público.
  - Los prompts por referencia, como la pre-revisión, necesitan `--dir` al directorio del lote.
- El comando: `agy -p "$prompt" --model "$id" --output-format stream-json --print-timeout "$pt"
  --settings "$SETTINGS" < /dev/null`.
  - stdout va a `${of}.log` (traza NDJSON) y stderr a `${of}.err`.
- `$pt` es el plazo del job menos un margen, para que agy corte limpio con salida parcial y exit 3. El
  `timeout(1)` externo conserva el plazo completo como respaldo. Un job sin plazo va sin
  `--print-timeout`.
- `$SETTINGS` lleva siempre:
  - `"useG1Credits": false`, para que ningún job pague créditos aunque Antonio cambie su setting;
  - `"allowNonWorkspaceAccess": false`;
  - `"agentMode": "auto"`.
- **Modo solo lectura (default), de mejor esfuerzo.** `$SETTINGS` agrega reglas deny para
  `write_file` y `edit_file`.
  - **Lo que no bloquea:** `run_command` puede escribir dentro del workspace. No se bloquea porque la
    lectura web lo usa (curl/python).
  - **Lo que lo contiene:** el sandbox de `auto` lo confina al workspace, que por default es el
    temporal vacío.
  - **Por confirmar al construir:** un job que intente `touch` fuera del workspace debe fallar.
  - Es la misma postura que la puerta opencode con `--auto`: para auditar un repo real, `--dir` a un
    worktree.
- **Modo escritura.** `CHEAP_FANOUT_AGY_WRITE=1` quita las reglas deny para los jobs que editan, que
  siempre van con `--dir` a un worktree aislado. Es la misma idea que
  `CHEAP_FANOUT_CODEX_SANDBOX=workspace-write`.
  - Aplica a toda la invocación, como el sandbox de codex. Un lote que mezcle jobs de lectura y de
    escritura se parte en dos invocaciones.
  - Los jobs que escriben nunca se reintentan solos: un fallo tardío pudo haber dejado cambios. Quedan
    en 76 o en su código de error.
- **Salidas.**
  - `out_file` recibe solo el mensaje final, el `.result.response` del evento `result`, igual que en
    codex.
  - `.gate` recibe `agy:<id>`.
  - El chequeo del prompt contra el argv se aplica igual.

**Estados:**

**Estados.** Cuando aplican varios, gana el primero de la tabla, salvo el plazo, que siempre se
reporta.

| Caso | Señal | Resultado |
|---|---|---|
| Soft-deny | Aviso `auto-denied` en `.err` | **`.status=65`, fallo**, con o sin respuesta. Deja el marcador `.denied` con los permisos negados, conserva la respuesta en `out_file` y agrega la nota `[cheap-fanout] DENEGADO`. El orquestador puede aceptar la respuesta después de leerla, pero el helper no la cuenta como OK |
| Plazo | exit 3 o `finished_reason: print_timeout`, o 124/137 del `timeout` externo | `.status=124` (137 si necesitó KILL), con nota TIMEOUT. Si hay evento `result`, se conserva su respuesta parcial; si el `timeout` externo lo mató antes, `out_file` lleva la nota y la cola de `.err`, sin prometer contenido |
| Sin cuota | exit≠0, firma de cuota (`RESOURCE_EXHAUSTED`, 429 o "quota" en `AGY_ERROR` o en `error`) y `retryable` falso o ausente | **Se confirma con `/usage`**, una sola consulta por lote y cacheada. Si la bolsa del modelo está en 0%, `.status=77`, con la hora de reset de esa ventana en la nota y en el resumen. Si no está en 0%, se trata como transitorio. **Sin rescate:** no cambia de modelo ni de puerta y no gasta créditos |
| Transitorio | `AGY_ERROR` con `"retryable": true`, o firma de cuota que `/usage` no confirma | Reintento con `cap_backoff_secs` (nunca en modo escritura); `.status=76` si persiste |
| Respuesta vacía | exit 0 y `response` vacía | `.status=66` |
| Sin evento `result` | exit 0 sin evento `result` | Fallo, con la traza en `.log` |
| Otro error | exit≠0 | El exit code de agy, con el error de `.err` en la nota |
| OK | exit 0, `status: SUCCESS`, respuesta no vacía y sin aviso de soft-deny | `.status=0` |

**El plazo es por intento**, igual que en las otras puertas: un reintento vuelve a recibir el plazo
completo.

**El resumen final** cuenta los 65 aparte ("N con acciones denegadas: revisa `.err` y `.denied`"). Un 77
de agy recibe su propio mensaje: qué bolsa de Google se agotó, a qué hora se resetea y que corras
`agy-budget`.

### 5.2 `bin/agy-budget`

- **Fuente:** corre `agy -p "/usage"` con un plazo corto y parsea el TSV.
- **Salida:** una tabla con el % **usado** por familia y ventana, y la hora de reset en hora local de
  CDMX. Incluye además los créditos (de `/credits`) y avisa si `useG1Credits` está en `true` (de
  `/config`).
- **`--model <id>`** restringe la evaluación a las bolsas de ese modelo:
  - `gemini-*` usa "Gemini Models";
  - Argon y `gemini-pro-orchestrator-g1-pro` usan además "Gemini 4 Argon";
  - `claude-*` y `gpt-oss-*` usan "Claude and GPT models".
- **Exit codes:**
  - 0: holgada.
  - 1: apretada (80% o más usado en alguna ventana relevante).
  - 2: agotada (0% restante en alguna ventana relevante).
  - 3: no se pudo leer (sin agy o sin sesión).
- **Advertencia en la salida:** los porcentajes son enteros y llegan con retraso, así que no sirven para
  medir un job suelto.

### 5.3 `skills/google-fanout/SKILL.md`

**Qué es.** Un skill nuevo, en español y mucho más corto que cheap-fanout. Usa el mismo helper y el
mismo flujo de 6 pasos; este skill solo cubre lo específico de la puerta Google.

**Reglas duras:**

1. **Material:** solo público o no sensible, nunca del cliente. La telemetría apagada es requisito, pero
   no vuelve aceptable el material sensible.
2. **Términos de uso:** solo el binario oficial `agy`, sin tocar su token y sin wrappers de terceros.
   Concurrencia moderada (6 por default) y nada de loops 24/7.
3. **Modelo explícito:** siempre `--model` con el nivel de esfuerzo en el id.
4. **Bolsas:** el ancho va a la bolsa Gemini; la bolsa Claude/GPT es para 1 o 2 unidades por sesión.
5. **Revisión:** la regla de oro de cheap-fanout sigue vigente. Ningún output barato aterriza sin
   revisión del orquestador.

**Ruteo inicial,** a confirmar con las mediciones de 5.5:

| Caso | Primario | Fallback | Por qué |
|---|---|---|---|
| Ancho de solo lectura (extracción, resumen, barrido) | `agy:gemini-4-hydrogen-low` | `agy:gemini-4-hydrogen-medium` | El más rápido medido (11 s) y respetó el formato |
| Investigación long-tail sin URL | `agy:gemini-4-hydrogen-medium` | `agy:gemini-4-neon-low` | `search_web`; falta medir Hydrogen en una unidad web |
| Unidad difícil dentro del lote | `agy:gemini-4-neon-medium` | `agy:gemini-4-neon-high` | Índice 55-60 |
| Casi-frontier quirúrgica | `agy:gemini-4-neon-xhigh` | `codex:gpt-6.2-astra` | 61 contra 62, de presupuestos distintos |
| Segunda opinión de la familia Claude sin gastar Max | `agy:claude-sonnet-5-5-high` | `agy:claude-opus-5-5-high` | Bolsa chica: 1 o 2 por sesión |

**Fuera del ancho:**

- `gemini-3.8-flash-*` y `gpt-oss-120b-medium`, porque rompieron el formato.
- Orchestrator, porque tardó 51 s y está pensado para código multi-paso.
- Argon, porque Neon lo domina (61 contra 50) y además tiene un límite semanal propio.

**Pre-revisor por agy:** sin decidir hasta medirlo con el lote sembrado de cheap-fanout (ver 5.5).

**Secciones:**

- Cuándo usar esta puerta y cuándo no.
- Las reglas duras.
- Requisitos: telemetría apagada y archivo de atestación.
- Ruteo y cuota, con `agy-budget`.
- Mecánica: ids, estados, archivos `.log`, `.err` y `.denied`.
- Lo medido, con fecha.
- Qué caduca y dónde releerlo.
- Troubleshooting.

Lo pesado va en `reference/`.

### 5.4 Cambios a lo existente

- **`skills/cheap-fanout/SKILL.md`:** tres ediciones mínimas.
  - Agregar `agy:<id>` como cuarta forma en *Uso del helper*.
  - Agregar una fila "Google (agy)" a la tabla de presupuestos activos.
  - Agregar un puntero a `google-fanout`.
- **Archivos del repo:**
  - **README:** la nueva puerta y el nuevo skill.
  - **CHANGELOG:** entrada 1.7.0.
  - **`plugin.json`:** 1.7.0, con las keywords `antigravity` y `gemini`.
- **`install.sh`:**
  - Agregar `chk agy` como dependencia opcional.
  - En `--check`, informar si existe la atestación de telemetría.
  - El nuevo skill se enlaza solo, porque `install.sh` ya recorre `skills/*/`.

### 5.5 Pruebas y mediciones

1. **`test/agy-puerta.sh`, sin costo.** Usa un `agy` falso en el PATH que registra su argv y emite el
   escenario que pida el prompt. Casos:
   - **Estados:**
     - OK.
     - Soft-deny con respuesta vacía, que da 65 y `.denied`.
     - Soft-deny con respuesta, que también da 65, conserva la respuesta y deja `.denied`.
     - Exit 3, que da 124 y conserva la respuesta parcial.
     - Un stream cortado sin evento `result`, que da fallo con nota.
     - Firma de cuota con `/usage` en 0%, que da 77 con hora de reset.
     - Firma de cuota con `/usage` por arriba de 0%, que se trata como transitorio.
     - `retryable: true`, que reintenta y deja 76 si persiste.
   - **Modo escritura:** con `CHEAP_FANOUT_AGY_WRITE=1`, `retryable: true` no se reintenta.
   - **Workspace:** sin `--dir`, el cwd que recibe agy es un temporal vacío y no el del helper, y se
     borra al terminar.
   - **Pre-vuelo:**
     - Id desconocido, que aborta con exit 2.
     - Sin atestación, que aborta con exit 2.
     - `agy:` con un id vetado, que aborta con exit 2.
   - **Lo que recibe agy:**
     - El argv trae siempre `useG1Credits:false` y `allowNonWorkspaceAccess:false`.
     - El modo solo lectura trae las reglas deny; con `CHEAP_FANOUT_AGY_WRITE=1` no las trae.
   - **Rutas y mezcla:**
     - Un prompt relativo funciona con `--dir`.
     - Un lote mixto con un opencode falso funciona.
2. **Los tres tests existentes** siguen pasando sin cambios.
3. **Smoke test en vivo**, que gasta cuota y requiere la atestación: un lote mixto con un job Go, uno
   Hydrogen, uno Neon y uno Sonnet. Va documentado en los hallazgos.
4. **Mediciones para el ruteo**, con el mismo fixture de 31 filas:
   - Hydrogen en una unidad web.
   - 12 jobs simultáneos.
   - El lote sembrado de pre-revisión de cheap-fanout con Neon y con Hydrogen, si el material de esa
     medición sigue disponible; si no, se siembra uno nuevo.
   - El gasto por bolsa medido con `/usage` antes y después.
5. **El skill, con el ciclo RED/GREEN de writing-skills.** Escenarios: ancho de investigación con
   URLs, investigación sin URLs, una unidad casi-frontier y una tentación de mandar material del
   cliente. Cada uno corre sin y con el skill.
   - Para medir si la redacción es clara, el sujeto es un modelo fuera de Anthropic, por ejemplo
     `codex:gpt-6.2-sol`.
   - Los escenarios de presión finales usan como máximo 2 o 3 subagentes de Anthropic.

### 5.6 Evidencia

`Bugs/hallazgos-2026-11-21.md` guarda lo de la sección 3 con sus fuentes: citas textuales, firmas de
error y latencias. Así la evidencia no depende del scratchpad.

**Dónde está hoy.** En el scratchpad de la sesión del 2026-11-21:

- `/tmp/claude-1000/-home-antonio-Proyectos-local-Ai-marketing/4fc4d89a-d6f0-4493-ad79-2fff4931ca78/scratchpad/`
  - `research/`: las 11 unidades y las 2 pre-revisiones.
  - `agy-probe/`: los PONG, la prueba web, el timeout y `/usage`.
  - `agy-deny/`: el soft-deny.
  - `verify-dl/`: las páginas primarias, vía Jina.
  - `bench/`: el fixture de 31 filas.

**El benchmark.** Se copia al repo en `skills/cheap-fanout/test/bench-extraccion/` (`gen.py`,
`grade.py`, `prompt.md`) para que sea reutilizable:

- `gen.py` genera el fixture de forma determinista (semilla `20261121`).
- `grade.py` califica en estricto y acepta una bandera para el modo tolerante.

**Línea base.** El fixture de la medición del 2026-11-20 (la tabla de la consola de Go) no está en el
repo, así que esta medición es una **línea base nueva**, no la misma de antes. Para comparar entre
puertas sobre el mismo fixture, se corren además 2 o 3 modelos de Go con él (`deepseek-v4.1-flash`,
`glm-5.3-flash` y `hy4-flash-free`, que no pesa en la bolsa).

## 6. Lo que decidió Antonio

- El enfoque A.
- Implícito, porque no lo objetó al elegir A: el material por agy es solo público o no sensible, con la
  telemetría apagada, y nada del cliente.

## 7. Decisiones mías (para que las revises)

1. **Nombre.** El skill se llama `google-fanout`.
2. **Telemetría.** Se hace cumplir con un archivo de atestación sin override por entorno, porque el
   estado real no se puede leer.
3. **Salidas.** `out_file` lleva solo el mensaje final; la traza va en `stream-json` a `.log`.
4. **Soft-deny.** Siempre es fallo (`.status=65`), aunque haya respuesta: se conserva la respuesta y el
   orquestador decide si la acepta. *Cambió tras la revisión del constructor:* la versión anterior lo
   dejaba en 0 y contradecía la anti-meta de los falsos OK.
5. **Workspace.** Por default es un temporal vacío por job, y `--dir` es la única forma de mostrarle
   archivos a Google. *Nuevo tras la revisión.*
6. **Solo lectura.** Es el default y es de mejor esfuerzo: deny a `write_file` y `edit_file`, sin
   bloquear `run_command`. Editar requiere `CHEAP_FANOUT_AGY_WRITE=1`, por invocación y sin
   reintentos automáticos.
7. **Cuota.** Una firma de cuota se confirma con `/usage` antes de dar 77; si no se confirma, se trata
   como transitoria. No hay rescate. *Nuevo tras la revisión.*
8. **Benchmark.** Es una línea base nueva con un fixture determinista guardado en el repo, más 2 o 3
   modelos de Go corridos sobre el mismo fixture.
9. **Release.** 1.7.0.

## 8. Lo que queda al builder

- Leer el NDJSON con `python3 -I` o con `jq`; los dos están instalados.
- La sintaxis exacta de las reglas deny. Hay que verificarla en `antigravity.google/docs/cli/permissions`
  y probarla con un job que intente escribir.
- El margen entre `--print-timeout` y el plazo externo.
- El formato exacto de la tabla de `agy-budget`.
- Cómo partir el contenido del skill entre `SKILL.md` y `reference/`.
- Si hace falta un precalentamiento adicional: con base en la medición de 12 simultáneos, decidir si
  basta la llamada a `agy models` del pre-vuelo.

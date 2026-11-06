---
name: cheap-fanout
description: >-
  Usa este skill cuando el trabajo sea ANCHO Y SUPERFICIAL — muchas unidades independientes que
  no necesitan razonamiento frontier por unidad: investigación web (leer/resumir muchas fuentes),
  ediciones mecánicas en lote (mismo cambio en N archivos), búsqueda/auditoría amplia (barrer
  módulos por un patrón), resumen/extracción a gran escala. Dispara agentes baratos de OpenCode Go
  y/o Codex CLI (suscripción ChatGPT) en paralelo con bin/cheap-fanout; el orquestador planea,
  rutea, revisa y sintetiza. Triggers: "en paralelo", "fan out", "muchos archivos/fuentes",
  "barre/audita todo el repo", "resume estas N páginas", "cheap-fanout", "codex", "go-budget",
  cuota o modelos de OpenCode Go. NO para razonamiento frontier por unidad, una tarea secuencial
  profunda, ni cuando un resultado barato malo sea caro de detectar y no lo vayas a revisar.
---

# cheap-fanout

Orquestación en **tres niveles**: el frontier planea, hace spot-check y da el veredicto final;
el subteniente (un modelo rápido de Go; otro de familia distinta como segundo revisor) pre-revisa el lote; los baratos
absorben el ancho a centavos.

> **Si los precios de este archivo te llegan como `analiza.14`, `las.40` o palabras sueltas**, el
> cargador sustituyó cada `$N` por el argumento N con el que invocaste `/cheap-fanout …`. Por eso
> aquí **los precios van como números y "USD", nunca `$` pegado a un dígito**. Si ves la
> corrupción igual, relee el archivo desde disco: `~/.claude/skills/cheap-fanout/SKILL.md`.

> **Material de referencia bajo demanda** en `reference/` junto a este archivo
> (`~/.claude/skills/cheap-fanout/reference/` si lo instalaste con `install.sh`): catálogo completo
> y mediciones, cascada anti-bots, Codex, Kimi y troubleshooting. No los cargues de entrada;
> ábrelos solo cuando un caso lo pida.

**Regla de oro del ahorro:** los tokens del orquestador (el recurso escaso) solo en **planear +
revisar + síntesis final**. El ancho siempre barato. Si te sorprendes a punto de lanzar muchos
subagentes *caros* para búsqueda/lote → para y usa este flujo.

Aquí **tú ejecutas** los agentes en el mismo loop y **tú integras** el resultado — no le entregas
prompts al usuario para que él los corra a mano. (Si en esta máquina existe un skill `/cheap-orq`,
ése es el que hace lo segundo; no los confundas.)

## Roles

| Nivel | Quién | Hace | Nunca hace |
|---|---|---|---|
| **Orquestador** | Claude/tú (frontier: Opus 5.5 = II 59, Sonnet 5.5 = 55, Fable 5.1 = 49; AA v5.0.1, esfuerzo máx.) | Descompone, rutea, **spot-check**, veredicto y síntesis **final** | El ancho; re-revisar lo ya limpio |
| **Subteniente** | `deepseek-v4.1-flash` (el que menos pesa contra su límite; 100s, 7/7 el 2026-11-06) y, en lotes de alto impacto, `codex:gpt-6.1-terra` en paralelo (II 42-51, 30s, cuota ChatGPT); `codex:gpt-6.1-sol` si el impacto es muy alto, `gemini-4-argon` si el material es sensible | Pre-revisa el lote entero en 1 request (1M ctx); borrador de síntesis; cruza unidades | El ancho; planear/rutear; la unidad difícil ordinaria (ésa va a `claude-haiku-5-5`) |
| **Casi-frontier** | `codex:gpt-6.1-sol` (II 50-55; suscripción ChatGPT) y, sin Codex, `gemini-4-argon` (II 50; Go) | 1-2 unidades quirúrgicas por sesión | El ancho |
| **Ejecutores** | `deepseek-v4.1-flash` (default), `minimax-m3.1-flash`, `glm-5.3-flash`, `gpt-6-luna`… (Go) y `codex:gpt-6-luna` (Codex CLI) | El ancho: N unidades en paralelo | Decidir o preguntar nada |

## Flujo (6 pasos)

1. **Descomponer** en N unidades independientes. Ownership disjunto: dos jobs nunca tocan el mismo archivo.
2. **Rutear** cada unidad al mejor modelo barato (tabla abajo — decide TÚ, no un router LLM).
   La tabla de este archivo es la referencia de ruteo, pero **caduca**: la fuente de verdad de
   precios, cuotas y **topes por modelo** es `opencode.ai/docs/go`. Si vas a rutear por precio en
   una decisión cara, o si un número te parece raro, reléela ahí (y no la confundas con
   `opencode.ai/docs/zen`, que cotiza los mismos modelos a precio de pago-por-uso). Lo que el
   proveedor sirve hoy **no** te lo dice `opencode models` de forma confiable —esa lista viene
   desfasada—: la lista autoritativa de lo que Go sirve es el endpoint público
   `curl https://opencode.ai/inference/go/v1/models` (sin llave; 29 ids el 2026-11-05) y la prueba
   final sigue siendo `opencode run -m <ruta> "Responde exactamente: PONG"` (la tabla de la doc aún
   lista modelos que responden `has been deprecated`).
3. **Disparar en paralelo** con `bin/cheap-fanout` (prompts autocontenidos + jobs.tsv).
   Para ediciones que escriben, corre cada job en un git worktree aislado o usa `--dir`.
4. **Recolectar** los `out_file` (revisa siempre `out_file.status`; 0 = OK).
5. **Pre-revisión** (lotes ≥3): un job `deepseek-v4.1-flash` —y, si el lote es de alto impacto,
   otro `codex:gpt-6.1-terra` en paralelo— recibe, **por referencia**, no
   concatenados, las rutas de los pares prompt→`.out` y los lee con sus propias herramientas de
   archivo desde el cwd, y devuelve veredicto por unidad + datos de alto impacto + borrador de
   síntesis (plantilla abajo). Con 1-2 unidades, sáltatelo y revisa directo.
   **Por referencia, siempre:** concatenar prompts + `.out` en el prompt del job crece sin
   techo (172 KB medidos con un lote mediano) y el prompt viaja como argumento de la línea de
   comandos — en Windows topa en ~32 KB y mata el job (`Argument list too long`, exit 126; el
   helper ahora lo detecta antes y lo marca `.status=64`). Los agentes de opencode **SÍ leen
   archivos locales del cwd** — la nota de abajo de "solo tienen `webfetch`" habla de búsqueda
   web, no de archivos.
6. **Spot-check + síntesis final (TÚ):** verifica todas las DUDOSO/FALLO, 1-2 OK al azar y todo
   dato de alto impacto contra fuente primaria. Un falso-OK en la muestra invalida el veredicto
   del lote → revisión completa tuya. La síntesis final la escribes TÚ sobre el borrador (los
   baratos y el subteniente son materia prima, no la respuesta). En código: TÚ lees el diff y corres los tests.

## Paso 0 — scouts de contexto (opcional, antes de descomponer)

Cuando la tarea trae **ingesta masiva predecible**, dispara scouts baratos ANTES de tu análisis
profundo para que la lectura pesada nunca pase por tu ventana. Tú lees el prompt original SIEMPRE
primero; el micro-triage es tuyo y cuesta ≤200 tokens: `scouts: [lista de jobs] | skip`.

- **Disparadores** (si no se cumple ninguno → skip, que es el default): el prompt nombra ≥3
  fuentes/URLs concretas a leer · pide barrido de repo/módulos ("audita todo", "mapea") · el
  material a ingerir estimado supera ~30K tokens. NUNCA para prompts conceptuales o tarea
  secuencial profunda.
- **Contrato EXTRACTIVO del scout** (campos obligatorios): `{path/url, tamaño, afirmaciones con
  cita textual + línea/anchor, números con contexto, fuentes_que_cita, no_cubierto}`. El scout
  extrae; el juicio es tuyo. La salida del scout es materia prima con cita — cada afirmación sin
  cita se descarta en pre-revisión.
- **Cero contexto del caso en el prompt del scout:** ni la pregunta de decisión del usuario, ni
  cifras del caso (LOC, presupuesto, prisa), ni datos identificables del cliente. Si necesitas
  enfocar, usa lente temática neutra ("presta atención a X e Y"), nunca el framing de la decisión.
  Doble motivo: anti-eco (si el scout conoce tu pregunta, te la devuelve disfrazada de hallazgo y
  ya no puedes detectar la contaminación) y regla pericial (nada del cliente a servicios externos).
- **Consumo anti-anclaje:** esboza TU marco del problema (hipótesis + incógnitas) ANTES de abrir
  los digests; los digests entran después como materia prima no verificada, nunca como marco. Cap
  ~4K tokens de digest en tu ventana; el excedente se queda en archivos referenciados por ruta.
- **Lo que NO es paso 0:** baratos analizando/descomponiendo/debatiendo el prompt, u opinando qué
  hacer. Evidencia 2026: mezclar análisis débil contamina al fuerte (anclaje con amplificación
  6-10x) y no ahorra nada — el prompt corto ya era barato de leer. El instinto adversario va
  DESPUÉS, contra artefacto concreto (el subteniente, codex challenge), nunca antes del plan.

> ¿Decisión de alto impacto con incertidumbre real tuya? Eso no es fan-out: ver el skill
> **cheap-fanout-ultimate** (consejo multi-frontier, solo a petición explícita del usuario).

## Uso del helper

```bash
B=~/.claude/skills/cheap-fanout/bin/cheap-fanout
# JOBS.tsv — un job por línea, TAB:  <model>\t<prompt_file>\t<out_file>[\t<timeout>]
"$B" --parallel 6 jobs.tsv                        # investigación (solo lectura)
"$B" --dir /ruta/al/repo --parallel 6 jobs.tsv    # si leen/escriben un repo
"$B" --timeout 3m jobs.tsv                        # cambia el plazo default del lote
~/.claude/skills/cheap-fanout/bin/go-budget   # gasto por modelo en sus tres ventanas (5h/7d/30d)
```
- El `<model>` admite tres formas (verificadas 2026-11-05):
  - `deepseek-v4.1-flash` — sin prefijo ⇒ el helper le pone `opencode-go/` (plan Go).
  - `opencode/glm-5.3-flash-free` — cualquier ruta `<provider>/<id>` de opencode pasa **tal
    cual** (aquí, un gemelo gratuito de Zen; ver *Modelos gratuitos*). Las rutas de Kimi directo
    (`kimi-code-plan-cn/*`, suscripción Moonshot) están **pausadas** desde el 2026-11-05: no las
    rutees; K3 va por Go (`kimi-k3`). El helper aún traduce `kimi-for-coding/*` por si se reactiva.
  - `codex` o `codex:<model>` — corre por `codex exec` con la suscripción ChatGPT. En jobs codex,
    `out_file` trae SOLO el mensaje final; la traza completa queda en `out_file.log`.
- Concurrencia: en **Linux** el default 6 es razonable (medido 2026-08-09 hasta `--parallel 4`
  con lote mixto, 0 fallos). Los jobs codex no tocan el SQLite de opencode (corren
  `--ephemeral`): un lote mixto reparte mejor la concurrencia.

  **Lo que de verdad limita NO es la concurrencia sostenida, sino el ARRANQUE EN FRÍO**
  (diagnosticado 2026-09-11 sobre opencode 1.18.29; ver `Bugs/sqlite-arranque-en-frio.md`).
  Medido en esta máquina:

  | escenario | resultado |
  |---|---|
  | 16 `opencode` simultáneos, base ya creada y migrada | **16/16 OK** |
  | 6 arranques simultáneos sobre base FRÍA, ×5 ensayos | **15/30 murieron** |
  | lo mismo, precalentando la base antes | **0/30 murieron** |

  O sea: con la base caliente la concurrencia es inofensiva; la ventana de choque se abre solo
  cuando hay que CREAR o MIGRAR la base — primera corrida tras instalar, canal nuevo,
  `OPENCODE_DB` nuevo, o **el primer lote después de un upgrade que trae migraciones**. Por eso
  la receta ya no es "baja `--parallel` en Windows para siempre", sino **precalentar**, que el
  helper hace solo en pre-vuelo (`opencode db "SELECT 1"`, ~1s, cero tokens, con `flock` global
  para que dos lotes simultáneos tampoco se peleen). Si aun así un job choca, el helper lo
  reintenta con backoff exponencial + jitter — barato, porque el choque ocurre ANTES de llamar
  al modelo. Ajustes: `CHEAP_FANOUT_RETRIES` (3), `CHEAP_FANOUT_RETRY_BASE` (2s),
  `CHEAP_FANOUT_NO_WARMUP=1`.
- **Saturación del proveedor (desde el 2026-11-06).** Si un job de opencode termina con
  `Upstream request failed: [overloaded]` o `[prefill_cap_refused]` (lo que hizo DeepSeek el
  2026-11-05), el helper lo relanza entero tras 10s y luego 20s (+ jitter); si sigue saturado lo
  deja en **`.status=76`** para que lo relances en otro modelo. Los pasos que el job ya había hecho
  se vuelven a pagar. No reintenta timeouts (124/137): lento no es rechazado. Ajustes:
  `CHEAP_FANOUT_CAP_RETRIES` (2), `CHEAP_FANOUT_CAP_RETRY_BASE` (10s).

  **El choque tiene DOS caras y dan mensajes distintos** — si lo diagnosticas a mano, busca las
  dos: `database is locked` (perdió la conversión a WAL) y `Failed query: CREATE TABLE …` (dos
  procesos aplicaron la misma migración; el corredor de opencode hace check-then-act). Hay una
  **tercera, silenciosa**: `.status=0` con un `.out` que trae SOLO la cabecera `> build · <model>`
  (28 bytes). El helper marca esa como `.status=66` y también la reintenta.

  **`--print-logs --log-level DEBUG` NO sirve para este fallo:** el proceso muere antes de que
  exista el logger, así que no imprime ni una línea. Diagnostica por el contenido del `.out`.

  Los `.out` traen códigos ANSI (`\x1b[0m`) además de la cabecera: **cualquier detector tuyo debe
  limpiarlos primero** — un `grep '^Error:'` sobre el crudo no matchea nunca, porque la línea
  real es `\x1b[91m\x1b[1mError: \x1b[0mUnexpected error`.
- **Timeout por job (4ª columna, opcional).** El helper garantiza que termina: cada job corre bajo
  `timeout`, con **15m** por default y `--timeout T` para cambiar el default del lote. La 4ª
  columna manda sobre el default y es donde vive el criterio real, porque tus clases de job no
  comparten presupuesto de tiempo: un flash de investigación son ~20s, un asiento frontier son
  2-8min. Formatos: `90` (segundos), `30s`, `8m`, `1h`, o `none` para quitarle el límite a ese job.
  Al vencer: SIGTERM y, 15s después, SIGKILL; el `.status` queda en **124** (o 137 si necesitó
  KILL), se anexa una nota al `out_file` y el resumen final dice cuántos fueron por timeout.
  Un `jobs.tsv` de 3 columnas sigue funcionando igual — hereda el default.
  Plazos que uso: investigación barata `2m` · edición mecánica `5m` · asiento del consejo `8m`.
- Los agentes de opencode solo tienen `webfetch` (no buscador): para temas long-tail dale una URL
  de arranque. Los jobs codex NO tienen web search: nada de investigación web por codex.
  (Esto es sobre búsqueda **web**: los agentes de opencode SÍ leen archivos locales del cwd — es
  la base del modo por-referencia de la pre-revisión.)

## Páginas que bloquean bots — cascada de 3 escalones

El bloqueo es contra el **fetcher** (`webfetch` es un GET plano, sin JS ni rotación de IP), no
contra el modelo. Escala solo cuando el escalón previo falle: **1.** `webfetch` directo →
**2.** Jina Reader (`https://r.jina.ai/<URL>`: gratis, renderiza JS, **no es bypass**; si devuelve
cuerpo vacío o "requiring CAPTCHA", no falló el modelo) → **3.** ZenRows por GET con
`js_render=true&premium_proxy=true&response_type=markdown` (25 créditos por página, 200 al mes
gratis, ~75s por request ⇒ plazo `8m` y `--parallel 4`; la key va literal en el prompt file
temporal y **nunca** en el repo ni en este archivo). URL exacta, manejo de la key, números medidos
y lo que NO entra por esta puerta: `reference/bloqueo-bots.md`.

## Ruteo por caso — modelos verificados (OpenCode Go; releído 2026-11-05)

Precios en USD por 1M tokens (input/output). Cuota Go en requests por ventana de 5h. **`límite`** =
los dólares mensuales que ESE modelo puede consumir del plan; de él salen sus tres ventanas (ver
*Cuota Go*). **`II`** = Artificial Analysis Intelligence Index **v5.0.1** (tercero independiente,
leído en `artificialanalysis.ai/leaderboards/models` el 2026-11-05). **AA publica un valor por nivel
de esfuerzo** (Haiku 5.5: 25 medium, 30 high, 36 max) y opencode no te dice cuál usa por default:
cita el rango. **El índice se reescala entre versiones** (ya van tres: v4.1.1 → v4.3.2 → v5.0.1):
compáralo solo dentro de la misma, y no lo mezcles con cifras de este archivo anteriores al
2026-11-05 ni con el "57" que este skill citaba para `glm-5.3-flash` (v4.1.1, dicho por Z.ai; marcó
42 en la v4.3.2 y marca 28 en la v5.0.1). **`seg`** = tiempo de pared medido en esta máquina en una
extracción de ~6K tokens de archivo local (mediana de 5 corridas en dos rondas del 2026-11-05, con
6-9 procesos `opencode` simultáneos: las cifras absolutas se inflan unos segundos, el orden no).

> **El precio por token no es el costo por tarea, y la velocidad no es una propiedad fija del
> modelo.** El 2026-11-05 `deepseek-v4.1-flash` estuvo saturado (8 de 13 corridas de 117-216s,
> vencidas a los 300s o con `[prefill_cap_refused] the cell is at capacity` / `[overloaded]`) y el
> ancho pasó un día a `minimax-m3.1-flash`. **Re-medido el 2026-11-06** (off-peak, dos rondas de 6
> con 6-9 procesos simultáneos, misma extracción de la doc de Go): **12 de 12 correctas en 19-55s**
> (mediana 34.5s), contra 41-76s de `minimax-m3.1-flash` en la misma ronda. **DeepSeek vuelve a
> ser el DEFAULT del ancho** porque, a igual exactitud, es el que menos gasta del plan: límite 100 (vs
> 20 de minimax) y caché de 0.003 (vs 0.015). Medido: 13 jobs de DeepSeek = 0.09% de su mes; 4 de
> minimax = 0.28% del suyo (~10x más por job). Aun en peak (precio doble) rinde más. La saturación
> fue intermitente y del proveedor: el helper reintenta solo `[overloaded]` y `[prefill_cap_refused]`
> (ver *Uso del helper*), y si un lote entero de DeepSeek da 124 o errores de capacidad, relánzalo en
> `minimax-m3.1-flash`. **Los números de velocidad de AA son dato vivo y se mueven entre capturas**;
> los índices II no.

| Caso de uso | Primario | Fallback | Por qué |
|---|---|---|---|
| **Investigación web / fetch+resumen** | `deepseek-v4.1-flash` | `minimax-m3.1-flash` · `glm-5.3-flash` · `gpt-6-luna` | 0.15/0.60 (doble en peak), 43,330 req/5h, **límite 100**, II 29-33, 1M ctx con imagen, caché 0.003, 0 días de retención (acuerdo ZDR mensual). **DEFAULT del ancho** (re-medido 2026-11-06: 19-55s, 12/12). La prueba web con cita no se repitió el 2026-11-06 (el 2026-11-05, saturado, tardó 216s o falló); `minimax-m3.1-flash` hizo 11-27s, 9/9 |
| **Mecánico simple en lote** | `deepseek-v4.1-flash` | `minimax-m3.1-flash` · `glm-5.3-flash` · `codex:gpt-6-luna` | `mimo-v2.6-flash` es el más barato por token (0.14/0.28) pero 3x más lento (32-61s); codex lee y escribe archivos desde el 2026-10-01 (ver *Codex CLI*) |
| **Resumen/ingesta masiva o multimodal** | `glm-5.3-flash` | `minimax-m3.1-flash` (img/video) · `gpt-6-luna` o `claude-haiku-5-5` (PDF) · `gemini-4-argon` o `mimo-v2.6-flash` (audio) | Según el endpoint de Go: `glm-5.3-flash` ingiere texto+imagen+video (ya no lista PDF), 1M ctx, II 28, ~20s. PDF ("application"): solo `gpt-6-luna`, `claude-haiku-5-5` y `gemini-4-argon`. Audio: solo `gemini-4-argon` y `mimo-v2.6-*` (lentos) |
| **Contexto ultra-largo barato** (repo/paper completo) | `deepseek-v4.1-flash` | `minimax-m3.1-flash` · `mimo-v2.6-flash` | 1M ctx y el caché de lectura más barato (0.003; `mimo-v2.6-flash` 0.0028 pero lento; `minimax-m3.1-flash` 0.015). Si da 124 o error de capacidad tras los reintentos del helper, relánzala en el fallback |
| **Código acotado con spec cerrada** | `glm-5.3-flash` | `gpt-6-luna` · `minimax-m3.1-flash` · `claude-haiku-5-5` | II 28, ~20s estables, 0 días de retención. `hy3` (no está en AA v5; 31s) y `hy4-preview` (86s, errático) quedaron dominados |
| **Código agentic multi-paso (>5 tools)** | `claude-haiku-5-5` | `deepseek-v4.1-flash` · `glm-5.3-flash` · `gpt-6-luna` | Mayor índice entre los rápidos (II 30-36 contra 28-29; DeepSeek 29-33). **No medí agentic propio: la evidencia es el índice más la latencia.** Retiene 30 días |
| **Bug-fixing / SWE con repro claro** | `glm-5.3-flash` | `glm-5.3` · `claude-haiku-5-5` | AA v5: flash 28 vs `glm-5.3` 32 (máx.), a 1/10 del precio. `glm-5.2` queda fuera del ruteo (Z.ai lo enruta a 5.3) |
| **Razonamiento algorítmico / semi-quirúrgico** | `kimi-k3.1-pro` | `gemini-4-argon` · `glm-5.3` | II 46 (el más alto entre abiertos; `mimo-v2.6-pro` bajó a 30 y `glm-5.3` a 32), 2.00/10.00, 147 req/5h, límite 15. **Lento**: 31-38s en la extracción y **venció a los 8 min** en una pre-revisión de 110 KB: solo prompts cortos y plazo `8m`. `deepseek-v4-pro` (II 23) y `mimo-v2.6-pro` (50s) salen del ruteo |
| **Unidad difícil dentro del lote** (1-3 por lote) | `claude-haiku-5-5` | `glm-5.3` (0 días de retención) · `kimi-k3` | II 30-36 según esfuerzo (sobre los ejecutores, 27-29, y `glm-5.3`, 32), 0.10/0.50, ~17s estables, 3,850 req/5h. **Retiene 30 días**: con material sensible va `glm-5.3` (26s, 220 req/5h). Calidad en una unidad realmente difícil: **sin medir** |
| **Unidad casi-frontier quirúrgica** (1-2 por sesión) | `codex:gpt-6.1-sol` | `codex:gpt-6-astra` · `gemini-4-argon` | II 50-55 (Sol) y 55-57 (Astra) contra 50 de `gemini-4-argon` (Go; 0 días de retención; 440 req/5h; ~60s; **50% de descuento hasta el 2026-11-30**: 2/10 en vez de 4/20). Codex no gasta Go ni tokens de Anthropic y exige ≥ 0.159.1 para `gpt-6.1-sol` (ver *Codex CLI*). `kimi-k3.1-pro` queda para cuando importe su 1M de contexto o su visión |
| **Delicado / frontier** (arquitectura, seguridad, semántica, revisión y síntesis) | **orquestador (tú/Claude)** | — | NUNCA a un barato. AA v5.0.1 (esfuerzo máx.): Opus 5.5 = 59, Sonnet 5.5 = 55, Fable 5.1 = 49 |

**Material sensible o del cliente:** solo modelos de **0 días de retención** (`minimax-m3.1-flash`,
`glm-5.3-flash`, `glm-5.3`, `kimi-k3`, `gemini-4-argon`, y `deepseek-v4.1-flash` mientras siga vigente
su acuerdo ZDR mensual: hoy hasta el 2026-11-30; reléelo en la doc al cambiar de mes). `gpt-6-luna` y
`claude-haiku-5-5` retienen 30 días: úsalos solo con material no sensible. Los jobs `codex:*` siguen
los controles de datos de tu cuenta ChatGPT (no medidos aquí): para pre-revisar material del cliente
usa `gemini-4-argon`, no `codex:*`.
La tabla de arriba nombra a varios de ellos como fallback por velocidad, no por privacidad.

### Qué pre-revisa el lote — medido el 2026-11-06 (y el 2026-11-05 y 2026-10-01)

Tercer lote (2026-11-06; 5 unidades con 7 fallas sembradas: dos números alterados contra su propia
cita, una salida truncada, dos filas omitidas sin declararlo, un precio que desobedece la instrucción
y dígitos transpuestos): **los 7 candidatos detectaron las 7**. Tiempos: `codex:gpt-6.1-terra` **30s**,
`kimi-k3` (Go) 31s, `codex:gpt-6-luna` 72s, `codex:gpt-6.1-sol` 77s, `minimax-m3.1-flash` 83s,
`gemini-4-argon` 95s, `deepseek-v4.1-flash` 100s. Los tres `codex:*` marcaron DUDOSO/FALLO la unidad
limpia porque su columna de solicitudes no traía cita (la plantilla pide cita para *cada* número: es
lectura literal, no error). El lote no discrimina calidad: la elección sale del índice (Sol 50-55,
`gemini-4-argon` 50, Terra 42-51, K3 44 en v4.3.2, Luna 21-28) y de **qué presupuesto gasta**. Una
pre-revisión de K3 costó 0.19 USD (1.3% de su mes); una de Argon, 0.14 (0.5% del suyo).

Segundo lote medido (5 unidades reales con fallas conocidas: una truncada por timeout, una con 3
citas atribuidas a la versión equivocada, una que omitía los ids que su prompt exigía): `gpt-6-luna`
**86s**, `deepseek-v4.1-flash` 134s, `minimax-m3.1-flash` **163s** (el más exhaustivo) y `kimi-k3` por
Go 196s las detectaron; `claude-haiku-5-5` (203s) y `glm-5.3-flash` (215s) dieron **falsos OK**;
`kimi-k3.1-pro` venció a los 8 min. Lote del 2026-10-01 (19 unidades): `deepseek-v4.1-flash` 141s,
K3 271s. Tablas y detalle: `reference/catalogo-go.md`.

**Regla:** pre-revisor por default `deepseek-v4.1-flash` (casi no pesa contra su límite de 100;
`minimax-m3.1-flash` de respaldo). En lotes de alto impacto lanza **`codex:gpt-6.1-terra` en paralelo**
(30s, II 42-51, gasta cuota ChatGPT y no Go; tiempo de pared = el del más lento) y cruza los dos
veredictos; si el impacto es muy alto, `codex:gpt-6.1-sol` (II 50-55, cuota más corta); si el material
es sensible, `gemini-4-argon` (Go, 0 días de retención, límite 30). **`kimi-k3` ya no pre-revisa**:
sin Kimi directo gasta de su límite Go de 15 USD, el más caro por token del plan (3/15), y el
2026-11-05 un solo día de pre-revisiones y consejo lo llevó a ~40% de su semana; queda para el asiento
Kimi del consejo (`cheap-fanout-ultimate`).
`glm-5.3-flash` y `claude-haiku-5-5` **no sirven de pre-revisores** (dieron falsos OK) y los modelos de
índice alto (`kimi-k3.1-pro`, `glm-5.3`, `mimo-v2.6-pro`) tampoco: minutos de más y peor cobertura.
**Valida siempre que la salida traiga `===FIN===`** (la plantilla lo exige): el 2026-11-05 una revisión
semántica de 17K palabras dejó a `minimax-m3.1-flash` con status 0 y 7.5 KB de trazas **sin veredicto**
y a `kimi-k3` vencido a los 8 min. Sin `===FIN===` es un fallo aunque el `.status` sea 0: pasa al
siguiente pre-revisor (`codex:gpt-6.1-terra`; `gpt-6-luna` entregó en ~90s) o parte el lote en
unidades más chicas. Son **tres lotes, dos chicos**: evidencia delgada. Si vas a depender de esto,
repite la comparación.

### El escalón de la unidad difícil (reconfirmado 2026-11-05)

En un lote de ocho unidades casi siempre hay una o dos **más difíciles que el resto** —no de
frontier, pero más de lo que el ejecutor del ancho hace bien—. Hoy las cubre `claude-haiku-5-5`:
II 30-36 según esfuerzo (AA v5.0.1), 0.10/0.50, ~17s y 3,850 req/5h, con la salvedad de que retiene
datos 30 días (para material sensible, `glm-5.3`).

> **Lo que ya no se sostiene y lo que sigue siendo evidencia delgada.** Esta fila era de
> `glm-5.3-flash` porque "II 42 queda a 2-4 puntos de K3 y de `glm-5.3`" —cifra de la v4.3.2—. En la
> v5.0.1 `glm-5.3-flash` marca 28 y queda **por debajo** de `deepseek-v4.1-flash` (29-33) y de
> `glm-5.3` (32). Sigue sin haber un comparativo mío de calidad en una unidad *genuinamente* difícil:
> los benchmarks de extracción (84/84) y de web con cita (9/9) no discriminan. **Cómo validarlo:** la
> próxima unidad difícil real, mándala a `claude-haiku-5-5`, a `glm-5.3` y a `codex:gpt-6.1-sol` y
> compara.

### Catálogo completo del pool Go

Los 31 modelos que lista la doc (29 que sirve el endpoint) con cuota, límite, precio, contexto,
índice II y velocidad medida están en `reference/catalogo-go.md` (releído el 2026-11-05). La tabla
de arriba ya decide el ruteo: abre el catálogo solo para un caso que no cubra o para un número exacto.

> **Precio ≠ cuota ≠ límite ≠ velocidad.** Son cuatro cosas. El ancho va a los de cuota alta y buena
> velocidad: `deepseek-v4.1-flash` (43,330 req/5h, límite 100), `glm-5.3-flash` (6,320, límite 60),
> `minimax-m3.1-flash` (3,880, límite 20) y `gpt-6-luna` (4,230, límite 15). Los de <500 req/5h (`glm-5.3`, `qwen3.8-max`, `kimi-k3`, `kimi-k3.1-pro`, `gemini-4-argon`)
> son 1-2 unidades quirúrgicas por sesión, nunca el ancho.
> **Muertos hoy (no los rutees):** `deepseek-v4-flash`, `deepseek-v4-flash-vision-exp`, `kimi-k2.6`,
> `minimax-m2.7` y los free de Go `longcat-2.5-preview-free`, `space-bunny-free`,
> `step-5-preview-free` responden `UnknownError`; `mimo-v2.5` y `mimo-v2.5-pro` dan error duro
> (*"has been deprecated. Use mimo-v2.6-… instead"*) aunque la tabla de la doc aún los lista.
> Fuera de la doc desde el 2026-08-28: `glm-5.1`, `minimax-m2.5`, `qwen3.7-max`, `qwen3.6-plus`,
> `grok-4.5`. `opencode models` es una lista desfasada: la prueba real de que un modelo existe es
> `opencode run -m <ruta> "Responde exactamente: PONG"`.

### Peak/off-peak de DeepSeek (mecánica vigente)

Los dos modelos DeepSeek del plan (`v4.1-flash` y `v4-pro`) cuestan **el doble** en horas peak:
**01:00-04:00 y 06:00-10:00 UTC, lunes a viernes**; todo lo demás, fines de semana incluidos, es
off-peak. En hora de CDMX (UTC-6) el peak cae **domingo a jueves 19:00-22:00** y **lunes a viernes
00:00-04:00**. Un lote grande de `deepseek-v4.1-flash` corrido a las 20:00 de CDMX consume el doble de
límite que a las 10:00. Ningún otro modelo del pool lo hace (para un lote enorme en peak,
`glm-5.3-flash` cuesta lo mismo todo el día). `v4-flash` y `v4-flash-vision-exp` ya no existen
(Zen marca `V4 Flash` deprecado el 2026-10-26). El límite de `v4.1-flash` subió de 60 a 100 USD el
2026-10-30 (changelog de opencode v2.2.4: *"Raised OpenCode Go limits for DeepSeek V4.1 Flash"*). El
2026-11-05 estuvo saturado y el 2026-11-06 ya respondía bien (ver el aviso de *Ruteo por caso*).

### Privacidad de los modelos Go (tabla vigente de la doc, 2026-11-05)

Casi todo el pool es **sin entrenamiento y 0 días de retención**. Las excepciones importan:

| Modelo | Entrenamiento | Retención |
|---|---|---|
| `muse-spark-1.3-contributor`, `muse-spark-1.2-contributor`, `iceman-contributor-free` | **Sí, entrena con tus datos** | **No es ZDR** |
| `grok-4.7`, `gpt-6-luna`, `gpt-5.6-luna`, `claude-haiku-5-5`, `beam-free` | No | 30 días |
| DeepSeek (`v4.1-flash`, `v4-pro`) | No | 0 días* — *"el acuerdo ZDR se renueva cada mes; el vigente vale hasta el 30 de noviembre de 2026"* |
| Todos los demás (incluido `gemini-4-argon`) | No | 0 días |

**Defensa del servidor.** El workspace bloquea por default los endpoints de pago que entrenan
(*"By default, paid endpoints that train on request data are blocked"*): verificado el 2026-11-05,
`iceman-contributor-free` responde con error en vez de servir; los `muse-spark-*` caen bajo la misma
regla según la doc. Se desbloquean con *Allow paid endpoints that train on request data* en Settings ›
Privacy: **déjalo apagado**. Las regiones permitidas por default son Europa y EE. UU.; DeepSeek pide
*Global* en *Regions* según la doc y en esta cuenta ya responde (si algún día falla con un error de
región, es ese ajuste).

**LongCat — discrepancia que no pude cerrar.** La doc de OpenCode dice "sin entrenamiento, 0 días"
para su ruta, pero la política de privacidad **propia** de Meituan (`longcat.chat/privacy`) permite
usar datos desidentificados para entrenar y optimizar modelos y exige guardar ciertos logs ≥6
meses. Úsalo **solo vía OpenCode** y no con material sensible del cliente hasta confirmar el
acuerdo; nunca apuntes a la plataforma de Meituan directamente.

## Modelos vetados — decisión permanente de Antonio (2026-08-28; ampliada 2026-10-01 y 2026-11-05)

**Los modelos de esta tabla NO se usan, aunque los números inviten.** Es política del skill y el
helper la aplica sola (`bin/cheap-fanout` rechaza el job antes de lanzarlo). Están marcados 🚫 en
el catálogo a propósito, en vez de borrados, para que una relectura de la doc no los "redescubra"
por su cuota y los vuelva a meter al ruteo.

| Vetado | Por qué |
|---|---|
| `muse-spark-1.2-contributor` y `muse-spark-1.3-contributor` **y sus gemelos free** | Trato explícito "cuota gigante a cambio de tus datos": 12x menos en input que `muse-spark-1.3` (1.25/4.25) porque Meta usa lo que le mandes para entrenar. Entrena y no es ZDR. Que tenga la cuota más alta del pool (45,300 req/5h) es el anzuelo. **El 1.3 se añadió el 2026-10-01 por analogía exacta (mismo texto de la doc) y Antonio lo confirmó ese día** |
| `iceman-contributor-free` | **Veto del 2026-11-05, pedido por Antonio.** Mismo trato que muse-spark: gratis *"in exchange for permission to use your prompts and completions to improve the model"*, sin ZDR. El workspace ya lo bloquea por default (casilla de privacidad apagada); el veto lo rechaza además en el helper, por si alguien la enciende |
| `grok-4.6` | Su **agentic coding regresó** frente a 4.5 y su time-to-first-token pasó de 8.7s a 31.2s; AA hoy lo marca "deprecated". Retiene datos 30 días |
| `grok-4.7` | **Ampliación del 2026-10-01, confirmada por Antonio ese día.** Mismo precio y "misma velocidad" que 4.6 según xAI; AA le mide un TTFT de **30 a 79s según la captura** (la mediana del leaderboard es ~4s) y yo medí 67.5s en una extracción que los rápidos hacen en 17s. Retiene 30 días. La familia Grok sigue fuera del ruteo |

**Con qué se cubren sus casos:** el volumen bruto que habría ido a muse-spark va a
`deepseek-v4.1-flash` (43,330 req/5h), `minimax-m3.1-flash`, `glm-5.3-flash` y `gpt-6-luna` (0 días de
retención los tres primeros); el asiento quirúrgico que habría ido a
grok va a `codex:gpt-6.1-sol` o `gemini-4-argon`.

Dato nuevo sobre grok-4.7 (2026-11-05): AA v5.0.1 le da II 35 y 32.67-52.94s de
respuesta según esfuerzo; el veto se mantiene.

**Si alguna vez quieres saltarte el veto** (una prueba puntual, material 100% público): el helper
lo permite con `CHEAP_FANOUT_ALLOW_VETOED=1` en esa invocación. No lo pongas en tu perfil.

## Modelos gratuitos (limited time) — cuáles sí y cuáles no

Hay dos cosas distintas y se confunden: **gemelos free** (`opencode/<id>-free`, el mismo modelo gratis,
por la puerta Zen) y **modelos gratuitos por derecho propio**. La doc de Zen avisa de varios:
*"During its free period, collected data may be used to improve the model"*. Releído y probado con
`opencode run` el 2026-11-05 (los modelos free solo sirven desde OpenCode: otros clientes reciben 403):

| Ruta | ¿Responde? | ¿Entrena con tus prompts? | Veredicto |
|---|---|---|---|
| `opencode/glm-5.3-flash-free`, `opencode/deepseek-v4.1-flash-free` | ✅ PONG ~8s | **No**: *"Its provider follows a zero-retention policy and does not use your data for model training"* | **Sí. Son gemelos free seguros otra vez** (los de 2026-10-01 murieron o entrenaban). "Limited time" |
| `beam-free` (Go) · `opencode/beam-free` | ✅ ~20s | No entrena; **retiene 30 días**; no disponible en una lista de países que no incluye México | **Sí**, material no sensible; AA "Beam 1.0" marca II 18: solo tareas triviales |
| `iceman-contributor-free` (Go) | ❌ lo **bloquea el servidor** | **Sí** ("in exchange for permission to use your prompts and completions"), no ZDR | **No. VETADO** (ver *Modelos vetados*). Error: *"This Go model trains on request data. Turn on 'Allow paid endpoints that train on request data'…"* |
| `opencode/mimo-v2.6-flash-free` | ✅ ~10s | **Puede** ("collected data may be used") | No para material del cliente |
| `opencode/big-pickle`, `pulse-alpha-free`, `flint-40b-free` | sin probar | **Puede** | No para material del cliente |
| `opencode/nemotron-3-ultra-free`, `nemotron-3.5-lightning-free`, `nemotron-3.5-super-vl-free` | sin probar | NVIDIA: "Trial use only — do not submit personal or confidential data" | No |
| `longcat-2.5-preview-free`, `space-bunny-free`, `step-5-preview-free` (Go) | ❌ `UnknownError` | — | **Muertos**: salieron de Go aunque models.dev aún los lista |

**Consecuencia para el helper:** el rescate automático por cuota sigue **apagado** (`SAFE_FREE_TWINS`
vacío en `bin/cheap-fanout`) porque cuando se decidió los gemelos entrenaban con tus prompts. Hoy
`glm-5.3-flash-free` y `deepseek-v4.1-flash-free` no lo hacen; habilitarlos es un cambio de una línea
que queda **pendiente de OK de Antonio**. Mientras tanto, sin gemelo seguro el job queda en
`.status=77` y decides tú; los gratuitos buenos se eligen a mano. Override solo con material público:
`CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1`.

## Cuota Go: límites por modelo (vigente desde el 2026-10-01; releído 2026-11-05)

Hasta el 2026-08-28 el plan tenía un pozo global (12 USD/5h, 30 USD/semana, 60 USD/mes) **y** un tope por
modelo. **La doc ya no menciona el pozo global**: define todo por modelo.

> *"Each model has the following usage limits: 5-hour — 20% of the monthly limit; weekly — 50%; and
> monthly — 100%."* — `opencode.ai/docs/go`

Cada modelo trae un **límite mensual** (columna `límite` del catálogo: 100, 60, 30, 20 o 15 USD en el
plan Go). Un modelo de 60 permite 12 USD/5h, 30 USD/semana y 60 USD/mes; uno de 100
(`deepseek-v4.1-flash`) permite 20/50/100; uno de 15 permite 3 USD/5h, 7.50 USD/semana y 15 USD/mes.
La doc lo explica en *"Why some models have lower usage"*: donde hubo descuento con el proveedor el
límite es alto; donde no (modelo nuevo o precio público ya rebajado) baja.

Hay **dos planes más**: **Go Plus de 40 USD/mes** (límites mayores por modelo: `glm-5.3-flash` 180,
`deepseek-v4.1-flash` 200, `kimi-k3` 60) y **Go Teams de 20 USD/miembro/mes** (nuevo; cada miembro
con sus propios límites, **5 USD más que Go en cada modelo**; solo para workspaces de varios
miembros, y arranca con Extra Usage encendido). Antonio está en Go y gasta unos 3.5 USD al mes
(incluidas las mediciones del 2026-11-05): no necesita ninguno. Cada respuesta de Go informa cuánto
contó la petición en `opencode.allowance` (dólares del límite mensual del plan).

**Consecuencia operativa:** agotar un modelo no agota a los demás; **cambiar de modelo siempre
consigue presupuesto**. Lo que no puedes saber desde el helper es *cuál* modelo cambiar: eso es una
decisión de calidad y es tuya.

```bash
~/.claude/skills/cheap-fanout/bin/go-budget      # por modelo, en sus tres ventanas
GO_PLUS=1 ~/.claude/skills/cheap-fanout/bin/go-budget   # contra los límites de Go Plus
GO_TEAMS=1 ~/.claude/skills/cheap-fanout/bin/go-budget  # contra los de Go Teams (Go + 5 USD)
```

- **Un modelo apretado o agotado** → cambia ESE job a otro modelo Go (el catálogo te dice a cuál
  según el caso), a un free sin entrenamiento o a `codex`.
- `go-budget` sigue mostrando una fila agregada "informativa" (suma de todos los modelos contra
  12/30/60). **Ya no es un límite documentado y no mueve el exit code**: si algún día resulta que
  el proveedor sí aplica un global, esa fila es la que lo mostraría.

**Lo que sí está automatizado:**

1. **Antes de un lote grande, mide.** `go-budget` lee la base local de opencode y te da el gasto
   por modelo contra sus tres ventanas. Exit code: `0` holgado · `1` apretado (≥80% en una ventana
   de algún modelo) · `2` el `--model` pedido agotó una de sus ventanas.
2. **Durante el lote, el helper detecta la cuota.** Al ver la firma `Provider rate limit exceeded`
   intenta el gemelo free del mismo modelo **solo si no entrena** (hoy ninguno está habilitado en el
   helper: ver *Modelos gratuitos*). `--on-quota off` lo desactiva del todo.
3. **Si no hay gemelo seguro, el helper NO sustituye el modelo.** Deja el job en `.status=77`
   ("SIN CUOTA") y te lo reporta, para que decidas tú.

**Los tres presupuestos activos, independientes entre sí** (el cuarto, Kimi directo, está pausado):

| Puerta | En `jobs.tsv` | Presupuesto | Para qué |
|---|---|---|---|
| Go | `deepseek-v4.1-flash` | límite por modelo (100/60/30/20/15 USD, ventanas 20%/50%/100%) | el ancho, por default |
| Free | `opencode/glm-5.3-flash-free`, `opencode/deepseek-v4.1-flash-free`, `beam-free` | gratis, "limited time" | el ancho sin entrenamiento cuando Go aprieta (a mano; no hay rescate automático) |
| ChatGPT | `codex:gpt-6.1-sol` / `codex:<m>` | ventana 5h + semanal de ChatGPT | casi-frontier, código, mecánico; **no** investigación web |
| ~~Allegretto~~ | ~~`kimi-code-plan-cn/k3`~~ | **pausada por Antonio (2026-11-05)** | no rutear; K3 va por Go |

> **Ojo con "Extra Usage"** (antes "Use balance"): en la página de Go de la consola hay una opción
> que, al agotarse el plan, sigue sirviendo requests cobrando a tu saldo de la consola — o sea,
> **dinero real** (en Go Teams viene encendida de fábrica; en Go es opt-in). Si no la has activado a
> propósito, déjala apagada; el fallback bueno es un free sin entrenamiento, no el de pago.

## Codex CLI — segundo presupuesto (suscripción ChatGPT)

`codex exec` corre **no-interactivo con el login de ChatGPT** (sin API key). En `jobs.tsv` usa
`codex:<model>`; el helper lo lanza como `codex exec --skip-git-repo-check --ephemeral -s read-only
-o out_file` (y `-C <dir>` con `--dir`). Verificado el 2026-11-05 con codex-cli **0.166.0** (la última;
ya estaba instalada).

- **Modelos con login ChatGPT y su cuota en Plus (mensajes/5h, OpenAI 2026-11-05):** `gpt-6-astra`
  (II 55-57; 5-45), `gpt-6.1-sol` (II 50-55; 15-160; exige Codex ≥ 0.159.1), `gpt-6.1-terra` (**nuevo**,
  II 42-51; 35-285; no es asiento: ver `cheap-fanout-ultimate`), `gpt-6-sol` (AA v5 ya no lo lista;
  15-150) y `gpt-6-luna` (II 21-28; 350-3,000). II = AA v5.0.1 de high a max. GPT-5.5 salió de Codex el
  2026-10-14. **El default de `~/.codex/config.toml` hoy es `gpt-6-luna` con esfuerzo high** (antes
  `gpt-6-astra`): un job `codex` pelado usa Luna. **Pide siempre el modelo explícito**:
  `codex:gpt-6.1-sol`, `codex:gpt-6-luna`.
- **Para qué:** el asiento casi-frontier (`gpt-6.1-sol`) y código/mecánico cuando Go escasea
  (`gpt-6-luna`, que también está en Go con 4,230 req/5h y límite 15: codex no suma un modelo,
  suma **cuota** aparte; el ancho con Luna va por Go, `codex` es desborde). **Para qué NO:**
  investigación web (sin web search) — eso siempre a opencode. En jobs codex, `out_file` trae solo
  el mensaje final; la traza va a `out_file.log`.
- **Sandbox:** `read-only` por default; los jobs que **editan** usan
  `CHEAP_FANOUT_CODEX_SANDBOX=workspace-write` con `--dir` a un worktree aislado, y revisas el diff.
  En Ubuntu 24.04 el sandbox necesita el perfil AppArmor `bwrap-userns-restrict`: sin él, **ni
  `read-only` lee archivos** (`bwrap … Failed RTM_NEWADDR`). En esta máquina ya está cargado
  (2026-10-01; reverificado el 2026-11-05: 84/84 leyendo archivos en `read-only`). Procedimiento
  oficial, verificación de contención, reversión e historial de versiones: `reference/codex.md`.

## K3 y Kimi — hoy solo por Go (Kimi directo pausado desde 2026-11-05)

> **La suscripción directa de Kimi (Allegretto, `kimi-code-plan-cn/*`) está pausada por Antonio:
> no la rutees ni la cuentes como presupuesto.** Verificado el 2026-11-05: las tres rutas (`k3`,
> `k3.1-pro`, `k3.1-pro-highspeed`) responden *"Your current subscription does not have access to Kimi
> Code right now"*. K3 y K3.1 Pro siguen disponibles **por Go** (`kimi-k3`, `kimi-k3.1-pro`, con cuota
> Go). El detalle de la puerta directa (credencial, ids, plan antiguo, velocidades) se conserva en
> `reference/kimi.md` por si se reactiva.

- **Guardrails:** K3 NUNCA en el ancho · máx 1-2 unidades por fan-out · **ya no es pre-revisor**
  (desde el 2026-11-06: ese puesto es de `codex:gpt-6.1-terra`) · su uso normal es el asiento Kimi del
  consejo · **no es el asiento casi-frontier** (eso es `codex:gpt-6.1-sol`). Por Go es el modelo más
  caro por token (3/15) con el límite más bajo (15 USD ⇒ 3 USD/5h, 7.50/semana): cada job de opencode
  arranca con ~22.5K tokens de instrucciones y herramientas (~0.07 USD en K3 antes de hacer nada).
  Mide con `go-budget` antes de repetirlo.
  `kimi-k3.1-pro` (II 46, 2.00/10.00, 147 req/5h) es el más inteligente entre abiertos pero **lento**
  (31-38s en la extracción; 8+ min sin veredicto en una pre-revisión): solo prompts cortos, plazo `8m`.
- **Guardrail de latencia (vigente):** si un job K3 tarda >5 min, mátalo: un job cortado por plazo
  **se cobra pero opencode no lo registra** (`go-budget` lo subestima; el 2026-11-05 faltaron
  ~0.3-0.45 USD de un K3 vencido). Ningún job caro se cae a ti: veredicto imparseable o 429 → otro
  pre-revisor, y solo si ese también falla, revisión completa tuya.
- **Plantilla de pre-revisión** (sirve para cualquier pre-revisor; la línea de webfetch es clave —
  en el dry-run K3 verificó fuentes por iniciativa propia). **Modo por referencia:** el prompt NO
  lleva los contenidos, solo las RUTAS de los pares prompt→salida; el agente los abre con sus
  herramientas de archivo desde el cwd (los agentes de opencode sí leen archivos locales). La
  versión con todo concatenado es inutilizable en Windows con lotes medianos (~32 KB de argv). Dos
  mejoras del 2026-10-01: la sección `DISCREPANCIAS` (aquí fue lo que más valor dio) y **exigir
  explícitamente cita textual**, que `deepseek-v4.1-flash` pasó por alto y K3 no. Mejora del
  2026-11-05: preguntar **(d) si la unidad omite algo que su prompt exigía** y **(e) si quedó
  truncada**; con eso los pre-revisores detectaron los ids omitidos y el timeout:

  ```
  Eres pre-revisor de un lote. Abajo va la lista de N unidades como pares de RUTAS de archivo
  (prompt original → salida del agente barato). Abre cada archivo con tus herramientas de
  lectura desde el directorio actual; no asumas su contenido. Las salidas traen códigos ANSI y
  una cabecera '> build · modelo': ignóralos.
  Algunas unidades están duplicadas a propósito (.A/.B: dos modelos, mismo prompt): compáralas y
  reporta toda discrepancia numérica.
  ===PARES===
  U01: _fanout/prompt-U01.md → _fanout/U01.out
  U02: _fanout/prompt-U02.md → _fanout/U02.out
  ...
  Para cada unidad verifica: (a) ¿CADA número y hecho trae cita TEXTUAL entre comillas + URL (una
  URL sin cita no cuenta)?; (b) ¿contradice a otra unidad?; (c) ¿hay afirmaciones sin cita,
  inventadas o con fecha posterior a hoy?; (d) ¿qué quedó en NO_CUBIERTO, y la unidad omite algo
  que su prompt exigía sin declararlo?; (e) ¿la salida está completa o quedó truncada (timeout)?
  Puedes usar webfetch o abrir las fuentes locales para verificar una cita.
  Responde EXACTAMENTE en este formato:
  ===VEREDICTOS===
  U01: OK|DUDOSO|FALLO — razón breve con el dato clave
  ===DISCREPANCIAS===
  - unidad A vs B: dato → valor A vs valor B
  ===ALTO_IMPACTO===
  - dato → por qué el orquestador debe verificarlo en primaria
  ===BORRADOR===
  (síntesis solo de unidades OK, con URL fuente por dato)
  ===FIN===
  ```
- **Tres presupuestos activos, misma disciplina:** Go (el ancho barato; cada modelo con su propio
  límite) · free (solo los que no entrenan, a mano) · ChatGPT/codex (casi-frontier y desborde).
  Kimi directo está pausado. El orquestador alterna por job en el campo `model` y conserva el
  veredicto final.

## Reglas de oro (lecciones caras)

1. **Ningún output barato aterriza sin revisión.** Revisión = el subteniente pre-revisa el lote + TÚ haces
   spot-check (DUDOSO/FALLO, 1-2 OK al azar, todo alto impacto contra fuente primaria); un
   falso-OK muestreado invalida el veredicto del lote entero. La síntesis final la escribes TÚ
   (baratos y el subteniente son materia prima, no la respuesta). Para código, TÚ lees el diff y corres los
   tests siempre.
2. **La `confidence` auto-reportada del agente no es señal** — casi siempre dice "high". Ignórala.
3. **Extracción factual: verifica contra la FUENTE PRIMARIA**, no por votos ni por tu prior. El
   consenso puede ser un prior compartido. Pide URL + cita textual; para valores raros/alto impacto,
   ve TÚ a la fuente oficial.
4. **Tu propio conocimiento de entrenamiento caduca.** Un dato *sourced* que te parezca "alucinación"
   puede ser correcto y tú estar desactualizado. Verifica en la primaria; no lo descartes por corazonada.
   *(Ejemplo real: DeepSeek-V4, MiMo-V2.5 y MiniMax-M3 —jul-2026— parecían inventados y eran reales.)*
5. **Los números de ESTE archivo caducan de verdad — relee la doc antes de una decisión cara.**
   Entre el 2026-08-09 y el 2026-08-28 cambió el ruteo entero: DeepSeek subió de precio (el alza
   que DeepSeek había anunciado "sin fecha" **se cumplió**), `deepseek-v4-flash` pasó de 31,650 a
   7,600 req/5h y perdió su gemelo free, aparecieron los **topes mensuales por modelo** y entraron
   seis modelos nuevos. **Y entre el 2026-08-28 y el 2026-10-01 volvió a cambiar:** desapareció el
   pozo global (límites por modelo), `glm-5.3-flash` pasó de límite 15 a 60, entraron `gpt-6-luna`,
   `deepseek-v4.1-flash` y `mimo-v2.6-*`, murieron los gemelos free de rescate, el proveedor de
   Kimi se renombró y rompió la ruta de K3, y el índice de benchmark se reescaló. **Y entre el
   2026-10-01 y el 2026-11-05, otra vez:** plan nuevo Go Teams; entraron `claude-haiku-5-5`,
   `gemini-4-argon`, `kimi-k3.1-pro`, `minimax-m3.1-flash`, `step-5-preview`, `hy4` y dos gratuitos;
   murieron `mimo-v2.5*`, `deepseek-v4-flash*` y tres free de Go; `deepseek-v4.1-flash` subió su
   límite a 100 **y a la vez se saturó**; el índice se reescaló por tercera vez (v5.0.1); y Kimi
   directo se pausó. Nada de eso se avisa: se descubre releyendo.
   Hay además **DOS tablas de precios**. `opencode.ai/docs/go` = tu plan (10 USD/mes): sus precios no
   se te cobran, son la tarifa contable que consume los límites. `opencode.ai/docs/zen` =
   pay-as-you-go, dinero real. Pueden divergir mucho (el caso clásico era v4-pro, 4x más caro en
   Zen — al 2026-08-28 ya convergieron, así que ni siquiera el ejemplo aguanta). Esta tabla usa
   **Go**. Si un número te parece raro, revisa de cuál de las dos páginas viene antes de
   "corregirlo". *(Lección 2026-08-09: un borrador de este skill traía la cifra Zen de v4-pro en
   una tabla de ruteo Go — el número era real, el producto era el equivocado.)*
6. **Disciplina de tokens.** El orquestador solo en planear+revisar+síntesis final; el ancho, siempre barato.
7. **Mide la velocidad, no solo el precio.** Un modelo "barato por token" puede ser el caro por
   tarea: `mimo-v2.6-flash` (0.14/0.28) tarda 32-61s en lo que `minimax-m3.1-flash` (0.15/0.60) hace
   en 13s, y un pre-revisor de índice alto tardó 17 minutos (2026-10-01) y otro venció a los 8
   (2026-11-05) donde uno rápido tardó 2. **La velocidad es dato vivo, no del modelo:**
   `deepseek-v4.1-flash` se saturó el 2026-11-05 (8 de 13 corridas lentas o fallidas) y al día siguiente
   respondía en 19-55s. Y **cuando un modelo se vuelve lento, el costo real es que su trabajo cae en el
   orquestador** (Anthropic): la lentitud se atiende cambiando de modelo, no esperando; pero **re-mide
   antes de dejar el cambio fijo**, porque el modelo que dejaste puede ser el que menos gasta.
8. **Un índice de benchmark solo se compara dentro de su versión.** El "57" de `glm-5.3-flash`
   era Artificial Analysis v4.1.1; en la v4.3.2 el mismo modelo marca 42 y en la v5.0.1
   (2026-11-05) marca 28. Cita siempre la versión
   y no copies cifras de un laboratorio sobre su propio modelo como si fueran de un tercero.
9. **Un texto que *menciona* un error no es ese error.** Un informe que citaba "database is
   locked" no era un choque de arranque: el detector del helper lo tomó por uno y reintentó tres
   veces un job sano (2026-10-01). Acota las firmas de error por forma y tamaño, no por la mera
   presencia de la frase.
10. **Mira contra qué límite pesa cada job, no solo cuánto cuesta.** En Go cada modelo tiene su
   propio límite mensual (15 a 100 USD): 1 USD en `kimi-k3` es 6.7% de su mes; en `deepseek-v4.1-flash`,
   1%. El 2026-11-05 un día de pre-revisiones y consejo con K3 por Go (antes iba por Kimi directo) lo
   llevó a ~40% de su semana y la consola de Go lo mostró como si el plan entero se agotara: la
   barra parece reflejar el **modelo más cargado**, no la suma (inferido de los números, no
   confirmado). Por eso el pre-revisor caro va por `codex:*` (otra cuota) y `go-budget` pone arriba
   al modelo más cargado.

## Troubleshooting

La tabla **síntoma → arreglo** (SQLite, timeouts, cuota, vetos, bots, codex, Kimi, precios
corruptos por `$N`) está en `reference/troubleshooting.md`: ábrela cuando un job falle. Los
`.status` del helper: `0` OK · `124`/`137` timeout · `77` sin cuota · `66` salida vacía · `64` prompt
> argv · `75` SQLite bloqueado tras reintentos · `76` proveedor saturado tras reintentos; exit `2` del helper sin correr nada = modelo vetado
o `jobs.tsv` inválido.

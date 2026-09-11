---
name: cheap-fanout
description: >-
  Orquestación en tres niveles: orquestador frontier (Opus/tú) + subteniente K3 (pre-revisión
  vía suscripción Kimi For Coding) + ejecutores baratos en paralelo.
  Úsalo cuando el trabajo sea ANCHO Y SUPERFICIAL — muchas unidades independientes sin
  razonamiento frontier por unidad: investigación web (leer/resumir muchas fuentes), ediciones
  mecánicas en lote (mismo cambio en N archivos), búsqueda/auditoría amplia (barrer módulos por un
  patrón), o resumen/extracción a gran escala. Dispara N agentes baratos de OpenCode Go y/o
  Codex CLI (suscripción ChatGPT, jobs "codex") con el helper bin/cheap-fanout, y tú
  (orquestador) planeas, ruteas, revisas y sintetizas. Triggers: "en paralelo", "fan out",
  "muchos archivos/fuentes", "barre/audita todo el repo", "resume estas N páginas",
  "cheap-fanout", "codex". NO lo uses para razonamiento frontier por unidad, una tarea
  secuencial profunda, o cuando un resultado barato malo sea caro de detectar y no lo vayas a revisar.
---

# cheap-fanout

Orquestación en **tres niveles**: el frontier planea, hace spot-check y da el veredicto final;
K3 (subteniente) pre-revisa el lote; los baratos absorben el ancho a centavos.

**Regla de oro del ahorro:** los tokens del orquestador (el recurso escaso) solo en **planear +
revisar + síntesis final**. El ancho siempre barato. Si te sorprendes a punto de lanzar muchos
subagentes *caros* para búsqueda/lote → para y usa este flujo.

Aquí **tú ejecutas** los agentes en el mismo loop y **tú integras** el resultado — no le entregas
prompts al usuario para que él los corra a mano. (Si en esta máquina existe un skill `/cheap-orq`,
ése es el que hace lo segundo; no los confundas.)

## Roles

| Nivel | Quién | Hace | Nunca hace |
|---|---|---|---|
| **Orquestador** | Claude/tú (frontier, Opus) | Descompone, rutea, **spot-check**, veredicto y síntesis **final** | El ancho; re-revisar lo ya limpio |
| **Subteniente** | `kimi-for-coding/k3` (suscripción Allegretto) | Pre-revisa el lote entero en 1 request (1M ctx); 1-2 unidades **casi-frontier**; borrador de síntesis | El ancho; planear/rutear; la unidad difícil ordinaria (ésa va a `glm-5.3-flash`) |
| **Ejecutores** | `mimo-v2.5`, `hy3`, `longcat-2.0`, `qwen3.8-flash`… (Go) y `codex` (Codex CLI) | El ancho: N unidades en paralelo | Decidir o preguntar nada |

## Flujo (6 pasos)

1. **Descomponer** en N unidades independientes. Ownership disjunto: dos jobs nunca tocan el mismo archivo.
2. **Rutear** cada unidad al mejor modelo barato (tabla abajo — decide TÚ, no un router LLM).
   La tabla de este archivo es la referencia de ruteo, pero **caduca**: la fuente de verdad de
   precios, cuotas y **topes por modelo** es `opencode.ai/docs/go`. Si vas a rutear por precio en
   una decisión cara, o si un número te parece raro, reléela ahí (y no la confundas con
   `opencode.ai/docs/zen`, que cotiza los mismos modelos a precio de pago-por-uso). Lo que el
   proveedor sirve hoy **no** te lo dice `opencode models` de forma confiable —esa lista viene
   desfasada—: pruébalo con `opencode run -m <ruta> "Responde exactamente: PONG"`.
3. **Disparar en paralelo** con `bin/cheap-fanout` (prompts autocontenidos + jobs.tsv).
   Para ediciones que escriben, corre cada job en un git worktree aislado o usa `--dir`.
4. **Recolectar** los `out_file` (revisa siempre `out_file.status`; 0 = OK).
5. **Pre-revisión K3** (lotes ≥3): un job `kimi-for-coding/k3` recibe —**por referencia**, no
   concatenados— las rutas de los pares prompt→`.out` y los lee con sus propias herramientas de
   archivo desde el cwd, y devuelve veredicto por unidad + datos de alto impacto + borrador de
   síntesis (plantilla abajo). Con 1-2 unidades, sáltatelo y revisa directo.
   **Por referencia, siempre:** concatenar prompts + `.out` en el prompt del job K3 crece sin
   techo (172 KB medidos con un lote mediano) y el prompt viaja como argumento de la línea de
   comandos — en Windows topa en ~32 KB y mata el job (`Argument list too long`, exit 126; el
   helper ahora lo detecta antes y lo marca `.status=64`). Los agentes de opencode **SÍ leen
   archivos locales del cwd** — la nota de abajo de "solo tienen `webfetch`" habla de búsqueda
   web, no de archivos.
6. **Spot-check + síntesis final (TÚ):** verifica todas las DUDOSO/FALLO, 1-2 OK al azar y todo
   dato de alto impacto contra fuente primaria. Un falso-OK en la muestra invalida el veredicto
   del lote → revisión completa tuya. La síntesis final la escribes TÚ sobre el borrador (los
   baratos y K3 son materia prima, no la respuesta). En código: TÚ lees el diff y corres los tests.

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
  DESPUÉS, contra artefacto concreto (subteniente K3, codex challenge), nunca antes del plan.

> ¿Decisión de alto impacto con incertidumbre real tuya? Eso no es fan-out: ver el skill
> **cheap-fanout-ultimate** (consejo multi-frontier, solo a petición explícita del usuario).

## Uso del helper

```bash
B=~/.claude/skills/cheap-fanout/bin/cheap-fanout
# JOBS.tsv — un job por línea, TAB:  <model>\t<prompt_file>\t<out_file>[\t<timeout>]
"$B" --parallel 6 jobs.tsv                        # investigación (solo lectura)
"$B" --dir /ruta/al/repo --parallel 6 jobs.tsv    # si leen/escriben un repo
"$B" --timeout 3m jobs.tsv                        # cambia el plazo default del lote
~/.claude/skills/cheap-fanout/bin/go-budget   # ventanas globales + gasto del mes por modelo
```
- El `<model>` admite tres formas (verificadas 2026-08-09):
  - `mimo-v2.5` — sin prefijo ⇒ el helper le pone `opencode-go/` (plan Go).
  - `kimi-for-coding/k3` — cualquier ruta `<provider>/<id>` de opencode pasa **tal cual**
    (suscripción directa Moonshot; no gasta cuota Go).
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
  la base del modo por-referencia de la pre-revisión K3.)

## Páginas que bloquean bots — cascada de 3 escalones (verificado 2026-08-09)

El bloqueo NO es contra el modelo barato: es contra el fetcher. `webfetch` es un GET plano, sin
JS, sin rotación de IP — Cloudflare/DataDome lo tumban. Como el agente barato no tiene shell, la
solución tiene que caber **en una URL**. Escala solo cuando el escalón previo falle:

1. **`webfetch` directo** — el default.
2. **Jina Reader — `https://r.jina.ai/<URL>`.** Gratis, sin key, 20 req/min (500 con key gratis);
   devuelve markdown limpio y **sí renderiza JS**, así que arregla SPAs y bloqueos leves de
   user-agent. **NO es bypass** y no finjas que lo es: *"Reader does not actively circumvent or
   bypass any website defense mechanisms"* (jina.ai/reader). Medido: g2.com devolvió 200 pero
   **cuerpo vacío** con `"This page maybe requiring CAPTCHA"`, y x.com dio 403. Si el `.out` trae
   markdown vacío o esa advertencia, **no es que el modelo falló** — escala al 3.
3. **ZenRows (unlocker con endpoint GET).** Se elige porque autentica por **query param**, o sea
   el agente barato lo llama con su `webfetch` tal cual:

   ```
   https://api.zenrows.com/v1/?apikey=KEY&url=<URL_ENCODED>&js_render=true&premium_proxy=true&response_type=markdown
   ```

   Créditos: base 1 · `js_render` 5 · `premium_proxy` 10 · ambos 25. Plan gratis 5,000 créditos/mes
   ⇒ **200 requests con anti-bot completo al mes, gratis**. Úsalo solo en las unidades que de
   verdad lo necesiten. Docs: `docs.zenrows.com/universal-scraper-api/api-reference`.

   **`response_type=markdown` no es opcional — es lo que hace viable el escalón.** Medido en
   g2.com: HTML crudo **1,227 KB** vs markdown **104 KB** (12x menos) por **el mismo costo de
   créditos**. Sin él, una sola página le revienta la ventana al modelo barato y te cobra los
   tokens de todo el DOM.

   **Tres números medidos el 2026-08-09 que cambian cómo armas el lote:**
   - **Latencia ~75s por request** con `js_render+premium_proxy` (vs 0.4s en modo base). El plazo
     de `2m` de investigación barata NO alcanza: dale **`8m`** a cualquier job que use ZenRows,
     y `none` si hace varias páginas duras.
   - **`Concurrency-Limit: 5`** en el plan gratis. Si N jobs pegan a ZenRows a la vez, baja
     `--parallel` a **4** o reparte: los jobs de sitios abiertos van en paralelo normal, los de
     ZenRows en un lote aparte.
   - Verifica el header **`X-Request-Cost`** cuando dudes de cuánto llevas gastado.

**Manejo de la key (regla dura).** El `webfetch` del agente NO lee variables de entorno: la key
tiene que ir **literal en la URL dentro del prompt file**. Por eso:
- La key vive **fuera del repo**: en tu archivo de credenciales o en `ZENROWS_API_KEY`. Léela al
  vuelo al armar los prompts, p.ej. `K="${ZENROWS_API_KEY:-$(grep -oE '[0-9a-f]{40}' RUTA_A_TUS_CREDENCIALES)}"`.
  Si la guardas en un `.md` propio, ojo con el encabezado exacto que uses al buscarla.
- **TÚ (orquestador) la lees y la inyectas** al generar los prompt files, que son temporales y
  viven en el scratchpad. Nunca la escribas en este SKILL.md, en un `jobs.tsv` versionado, ni en
  ningún archivo dentro de un repo.
- URL-encodea el `url=` destino (los `?` y `&` del target rompen el query si van crudos).

**Lo que NO entra por esta puerta:** ScrapingBee deprecó `api_key` en query y ahora exige header
`Authorization` — inalcanzable desde `webfetch`. Bright Data Web Unlocker es el más potente
(30+ tipos de CAPTCHA, $1.5/1K, 5K gratis/mes) pero su API directa es POST: solo por MCP, no por
un agente barato. Crawl4AI self-host (Apache 2.0, undetected browser) es el escalón 4 si algún día
200 req/mes se quedan cortas — es infra que mantener, no lo montes antes de necesitarlo.

## Ruteo por caso — modelos verificados (OpenCode Go; releído 2026-08-28)

Precios per 1M tokens (input/output). Cuota Go en requests por ventana de 5h. **`tope`** = los
dólares mensuales que ESE modelo puede consumir del plan — mecánica **nueva**, léela abajo antes
de rutear.

| Caso de uso | Primario | Fallback | Por qué |
|---|---|---|---|
| **Investigación web / fetch+resumen** | `mimo-v2.5` | `longcat-2.0` | $0.14/$0.28, 1M ctx, 30,100 req/5h, tope $60 y **gemelo free vivo**. **DEFAULT del ancho.** |
| **Mecánico simple en lote** | `mimo-v2.5` | `qwen3.8-flash` · `codex` | Mismo caballo; `qwen3.8-flash` ($0.15/$0.47, 5,400/5h) si quieres no tocar el tope de mimo; codex si prefieres gastar ChatGPT |
| **Resumen/ingesta masiva o multimodal** (img/audio/video) | `mimo-v2.5` | `deepseek-v4-flash-vision-exp` · `mimo-v2.5-pro` | mimo es multimodal nativo, 1M ctx y el más barato con tope $60. El vision-exp factura las imágenes como tokens de input y solo tiene tope $15 |
| **Contexto ultra-largo barato** (repo/paper completo) | `mimo-v2.5` | `longcat-2.0` · `minimax-m3` | Los tres con 1M ctx y tope $60; longcat cachea a $0.006/1M (lo más barato del pool para releer lo mismo) |
| **Código acotado con spec cerrada** | `hy3` | `qwen3.7-plus` | $0.14/$0.58, 4,300 req/5h, 256K, tope $60 y **ahora sí tiene gemelo free** (`opencode/hy3-free`) |
| **Código agentic multi-paso (>5 tools)** | `deepseek-v4-flash` | `gpt-5.6-luna` · `kimi-k2.7-code` | Sigue siendo el mejor agentic barato, pero **ya no es el default**: subió a $0.22/$0.66 (el doble en horas peak), cayó a 7,600 req/5h, su tope es $30 y **perdió su gemelo free**. Úsalo cuando de verdad necesites el agentic, fuera de peak |
| **Bug-fixing / SWE con repro claro** | `glm-5.2` | `hy3` | SWE bug-fix + artefactos UI, tope $60. Caro ($1.40/$4.40): 880 req/5h |
| **Código con razonamiento algorítmico** | `deepseek-v4-pro` | `kimi-k2.7-code` | Coding de élite, pero se encareció fuerte: $0.66/$1.98 off-peak, 1,050 req/5h y tope **$15**. Ya no es "barato en $" — trátalo como semi-quirúrgico |
| **Unidad difícil dentro del lote** (1-3 por lote) | `glm-5.3-flash` | `kimi-for-coding/k3` | Índice de Inteligencia 57 (= Opus 4.8, = K3) a $0.15/$0.50: calidad de escalón K3 a precio de escalón mimo. El tope $15 lo acota a esto. **Evidencia delgada — lee la nota debajo de la tabla** |
| **Unidad casi-frontier quirúrgica** (1-2 por sesión) | `kimi-for-coding/k3` | `kimi-k3` (Go) · `qwen3.8-max` · `glm-5.3` | K3 por la suscripción directa Moonshot (Allegretto) NO gasta cuota Go; la vía Go (110 req/5h, tope $15 ⇒ ~490 req/mes) queda de fallback. Nunca en el ancho |
| **Delicado / frontier** (arquitectura, seguridad, semántica, revisión y síntesis) | **orquestador (tú/Claude, Opus)** | — | NUNCA a un barato |

### El escalón de la unidad difícil (nuevo, 2026-08-28)

Entre el ancho y lo quirúrgico faltaba un peldaño. En un lote de ocho unidades casi siempre hay
una o dos **más difíciles que el resto** —no de frontier, pero más de lo que `mimo-v2.5` hace
bien— y sin ese peldaño solo había dos salidas, las dos malas: mandarla a un barato igual y
confiar en que la pre-revisión la cache, o quemar uno de los dos asientos de K3 de la sesión en
algo que no era tan grave.

`glm-5.3-flash` cubre ese hueco: Índice de Inteligencia de Artificial Analysis **57** —el mismo
que Kimi K3 y que Claude Opus 4.8, por encima de DeepSeek V4 Pro (53)— a **$0.15/$0.50**, o sea
el precio del ancho, no el de K3 ($3/$15). Su tope de $15/mes parece la pega y es justo la parte
buena: hace **físicamente imposible** usarlo como caballo del ancho, que es la disciplina que este
escalón necesita.

> **La evidencia es delgada y hay que tratarla como tal.** El modelo salió el **2026-08-26**, dos
> días antes de entrar aquí: no tiene historial. Casi todos sus benchmarks los reporta Z.ai, su
> propio lab; el Índice 57 es la excepción y por eso es el número en el que se apoya esta fila. Y
> el uso propio medido es de **una sola unidad** (la investigación de modelos del 2026-08-28, que
> la pre-revisión de K3 marcó OK). Uno de diez no prueba nada.
>
> **Cómo validarlo sin discutirlo:** la próxima vez que un lote traiga una unidad genuinamente
> difícil, mándala a los dos —`glm-5.3-flash` y `kimi-for-coding/k3`— y compara las salidas.
> Cuesta centavos y un asiento de K3 que ibas a gastar de todas formas. Con dos o tres
> comparaciones sabes si el escalón se gana su lugar; si no, **borra la fila**.
>
> **Pendiente que abre:** si el escalón se confirma, la fila de bug-fixing (`glm-5.2`,
> $1.40/$4.40, 880 req/5h) queda difícil de justificar — Z.ai afirma que 5.3-flash lo supera en
> toda la línea a ~1/10 del precio. Pero eso lo dice el propio Z.ai: verifícalo antes de mover
> esa fila.

### Catálogo completo del pool Go (cuota → tope → precio → contexto)

Cuotas, topes y precios releídos en `opencode.ai/docs/go` el **2026-08-28**; contextos de
`models.dev/api.json`; la columna "free" se probó con `opencode run` ese mismo día.

| id | req/5h | tope $/mes | $/1M in/out | ctx | free | Nota |
|----|-------:|:----------:|---|:--:|:--:|------|
| ~~`muse-spark-1.2-contributor`~~ | 45,300 | $60 | $0.10/$0.20 | 1M | ✅ | 🚫 **VETADO** — entrena con tus datos y no es ZDR. Tiene la cuota más alta del pool; no importa. Ver *Modelos vetados* |
| `mimo-v2.5` | 30,100 | $60 | $0.14/$0.28 | 1M | ✅ | **DEFAULT.** Multimodal nativo, cuota altísima, tope completo, gemelo free |
| `longcat-2.0` | 11,400 | $60 | $0.30/$1.20 | 1M | — | Segunda cuota más alta con ZDR. Cache a $0.006/1M |
| `deepseek-v4-flash` | 7,600 | **$30** | $0.22/$0.66 · peak $0.44/$1.32 | 1M | — | Ex-default. Agentic fuerte, pero 4x menos cuota que antes y sin free |
| `qwen3.8-flash` | 5,400 | $30 | $0.15/$0.47 | 1M | — | Barato y 1M ctx; buen segundo del ancho |
| `hy3` | 4,300 | $60 | $0.14/$0.58 | 256K | ✅ | Tencent 295B/21B act. Razonamiento/SWE altos, baratísimo, **ahora con gemelo free** |
| `qwen3.7-plus` | 4,300 | $60 | $0.40/$1.60 | 1M | — | Tool-calling+MCP. **Escalón: >256K tokens factura $1.20/$4.80** |
| `deepseek-v4-flash-vision-exp` | 3,800 | **$15** | $0.22/$0.66 · peak $0.44/$1.32 | 1M | — | Visión: las imágenes se facturan como tokens de input |
| `minimax-m2.7` | 3,400 | $60 | $0.30/$1.20 | 200K | — | Gen previa de M3 |
| `qwen3.6-plus` | 3,300 | $60 | $0.50/$3.00 | 1M | — | **Escalón >256K: $2.00/$6.00** |
| `mimo-v2.5-pro` | 3,250 | **$15** | $0.435/$0.87 | 1M | — | Multimodal reforzado |
| `minimax-m3` | 3,200 | $60 | $0.30/$1.20 | 1M | — | Frontier-coding barato, agentic ctx largo |
| `gpt-5.6-luna` | 2,050 | **$15** | $0.20/$1.20 | 1.05M | — | **Escalón >272K: $0.40/$1.80.** Retiene datos 30 días. Mismo modelo que puede correr Codex CLI |
| `glm-5.3-flash` | 1,580 | **$15** | $0.15/$0.50 | 1M | — | "Ox Alpha", 320B/18B, MIT. Índice 57 (= Opus 4.8). **El escalón de la unidad difícil**; el tope bajo lo mantiene fuera del ancho |
| `kimi-k2.7-code` | 1,350 | $60 | $0.95/$4.00 | 256K | — | Coding agentic multi-paso |
| `kimi-k2.6` | 1,150 | $60 | $0.95/$4.00 | 256K | — | Gen previa de k2.7 |
| `deepseek-v4-pro` | 1,050 | **$15** | $0.66/$1.98 · peak $1.32/$3.96 | 1M | — | Coding de élite. Ya NO es barato: 3x menos cuota y tope $15 |
| `glm-5.2` | 880 | $60 | $1.40/$4.40 | 1M | — | SWE bug-fixing, artefactos UI |
| `glm-5.1` | 880 | $60 | $1.40/$4.40 | 200K | — | Gen previa de 5.2 |
| `qwen3.7-max` | 340 | $60 | $2.50/$7.50 | 1M | — | Quirúrgico |
| `glm-5.3` | 220 | **$15** | $1.40/$4.40 | 1M | — | Quirúrgico |
| ~~`grok-4.6`~~ | 169 | **$15** | $2.00/$6.00 | 500K | — | 🚫 **VETADO** — regresión agentic y TTFT de 31s. Ver *Modelos vetados* |
| `qwen3.8-max` | 160 | **$15** | $2.00/$6.00 | 1M | — | 2.4T multimodal flagship. Quirúrgico |
| `kimi-k3` | 110 | **$15** | $3.00/$15.00 | 1M | — | Casi-frontier abierto. **Preferir la puerta `kimi-for-coding/k3`** (suscripción directa, no gasta Go) |

**Notas del catálogo:**
- `minimax-m2.5` sale en la tabla de precios ($0.30/$1.20, tope $60, 200K) pero no en la de cuotas.
- `hy4-preview` está en la doc (1,350 req/5h, $0.834/$2.501, tope $30) pero **hoy no responde**
  desde esta cuenta (`UnknownError`, dos intentos 2026-08-28). No lo rutees hasta que conteste.
- `grok-4.5` desapareció de la doc y `grok-4.6` está vetado: **la familia Grok entera queda fuera del ruteo.**
- **`opencode models` está desactualizado y NO es la autoridad**: el 2026-08-28 no listaba
  `grok-4.6`, `longcat-2.0`, `glm-5.3-flash` ni `qwen3.8-flash`, y los cuatro responden; en
  cambio sí listaba `ox-alpha-free` y `x-preview-f-free`, que fallan. La prueba real de que un
  modelo existe es un `opencode run -m <ruta> "Responde exactamente: PONG"`.

> **Precio ≠ cuota ≠ tope.** Son tres cosas: `deepseek-v4-pro` cuesta $0.66 pero solo da 1,050
> req/5h y no puede pasar de $15/mes. El ancho va a los de cuota alta **con tope $60**
> (`mimo-v2.5`, `hy3`, `longcat-2.0`); los de <400 req/5h (`qwen3.7-max`, `glm-5.3`, `qwen3.8-max`,
> `kimi-k3`) son 1-2 unidades quirúrgicas por sesión, nunca el ancho.

### Peak/off-peak de DeepSeek (mecánica nueva)

Los tres modelos DeepSeek (`v4-flash`, `v4-flash-vision-exp`, `v4-pro`) cuestan **el doble** en
horas peak: **01:00-04:00 y 06:00-10:00 UTC, lunes a viernes**; todo lo demás, fines de semana
incluidos, es off-peak. En hora de CDMX (UTC-6) el peak cae **domingo a jueves 19:00-22:00** y
**lunes a viernes 00:00-04:00**. Un lote grande de DeepSeek corrido a las 20:00 de CDMX consume el
doble de tope que el mismo lote a las 10:00. Ningún otro modelo del pool tiene esta mecánica.

### Privacidad de los modelos Go (tabla nueva en la doc)

Casi todo el pool es **sin entrenamiento y 0 días de retención**. Las excepciones importan:

| Modelo | Entrenamiento | Retención |
|---|---|---|
| `muse-spark-1.2-contributor` | **Sí, entrena con tus datos** | **No es ZDR** |
| `grok-4.6`, `gpt-5.6-luna` | No | 30 días |
| DeepSeek (`v4-pro`, `v4-flash`, `v4-flash-vision-exp`) | No | 0 días* |
| Todos los demás | No | 0 días |

Esa tabla es la razón del primer veto: ver abajo.

## Modelos vetados — decisión permanente de Antonio (2026-08-28)

**Dos modelos del pool NO se usan, aunque los números inviten.** No es una preferencia de esta
sesión: es política del skill, y el helper la aplica sola (`bin/cheap-fanout` rechaza el job antes
de lanzarlo). Están marcados 🚫 en el catálogo a propósito, en vez de borrados, para que una
relectura futura de la doc no los "redescubra" por su cuota y los vuelva a meter al ruteo.

| Vetado | Por qué |
|---|---|
| `muse-spark-1.2-contributor` **y su gemelo free** | Es un trato explícito "cuota gigante a cambio de tus datos": mismos pesos que `muse-spark-1.2` ($1.25/$4.25) a 12x menos en input porque Meta usa lo que le mandes para mejorar sus productos. Entrena y no es ZDR. Que tenga la cuota más alta del pool (45,300 req/5h) es justamente el anzuelo |
| `grok-4.6` | Sustituyó a `grok-4.5` subiendo 5 puntos de índice de inteligencia, pero su **agentic coding regresó** (LiveBench 54.2 vs 56.5 de 4.5) y su time-to-first-token pasó de 8.7s a 31.2s — 3.5x peor. En un lote con plazo por job, eso mata asientos sanos. Además retiene datos 30 días |

**Con qué se cubren sus casos:** el volumen bruto que habría ido a muse-spark va a `mimo-v2.5`
(30,100 req/5h, mismo tope $60, 0 días de retención) y a `longcat-2.0`; el asiento quirúrgico que
habría ido a grok va a `kimi-for-coding/k3`, `qwen3.8-max` o `glm-5.3`.

**Si alguna vez quieres saltarte el veto** (una prueba puntual, material 100% público): el helper
lo permite con `CHEAP_FANOUT_ALLOW_VETOED=1` en esa invocación. No lo pongas en tu perfil.

## Cuota Go: DOS límites, no uno (cambió en agosto 2026)

Hasta hace poco el plan Go era un **pozo único** de dólares y cambiar de modelo no conseguía ni un
dólar más. **Eso ya no es cierto.** Hoy hay dos límites simultáneos:

1. **El pozo global**, sin cambios: **$12/5h · $30/semana · $60/mes**, compartido por todos los modelos.
2. **Un tope mensual POR MODELO** (columna `tope` del catálogo): **$60, $30 o $15** según el modelo.
   La doc lo explica en *"Why some models have lower usage"*: pagas $10 y apuntan a darte 6x en uso
   ($60); donde no consiguieron descuento con el proveedor, el multiplicador baja a 3x ($30) o
   1.5x ($15).

**Consecuencia operativa, y es la que cambia tu comportamiento:** agotar un modelo ya **no** agota
el plan. Si `deepseek-v4-flash` topó sus $30 del mes, `mimo-v2.5` todavía tiene su propio carril
de $60 — mientras el pozo global aguante. **Cambiar de modelo ahora sí consigue presupuesto.**
Lo que ya no consigue nada es cambiar de modelo cuando lo que se agotó fue el pozo global.

Por eso, ante un fallo de cuota, el diagnóstico es primero y la sustitución después:

```bash
~/.claude/skills/cheap-fanout/bin/go-budget      # ventanas globales + gasto mensual por modelo
```

- **Pozo global apretado/agotado** (5h, 7d o 30d en rojo) → cambiar de modelo Go no sirve: vete a
  los free, a `codex` o a `kimi-for-coding/k3`.
- **Solo el tope de UN modelo agotado** (el global holgado) → cambia ese job a otro modelo Go con
  tope disponible. Es una decisión de calidad, así que la tomas tú: el helper nunca sustituye un
  modelo por otro solo.

**Lo que sí está automatizado:**

1. **Antes de un lote grande, mide.** `go-budget` lee la base local de opencode y te da las tres
   ventanas globales **y el gasto del mes por modelo contra su tope**. Exit code: `0` holgado ·
   `1` apretado (≥80% en una ventana, o algún modelo pasado de su tope) · `2` global agotado.
2. **Durante el lote, el helper detecta y rescata.** Al ver la firma `Provider rate limit exceeded`
   reintenta el job **una vez en el gemelo gratuito del mismo modelo** (`opencode/<id>-free`), que
   la doc de Go señala explícitamente: *"If you reach the usage limit, you can continue using the
   free models"*. Mismo modelo, presupuesto distinto, misma calidad. `--on-quota off` lo desactiva.
3. **Si no hay gemelo free, el helper NO sustituye el modelo.** Deja el job en `.status=77`
   ("SIN CUOTA") y te lo reporta, para que decidas tú entre otro modelo Go, un free, codex o K3.

**Gemelos free — la lista cambió, revísala (probados con `opencode run` el 2026-08-28):**

| Modelo Go | Gemelo free | Estado |
|---|---|---|
| `mimo-v2.5` | `opencode/mimo-v2.5-free` | ✅ responde |
| `hy3` | `opencode/hy3-free` | ✅ responde (**nuevo**; antes no tenía) |
| ~~`muse-spark-1.2-contributor`~~ | ~~`opencode/muse-spark-1.2-contributor-free`~~ | 🚫 responde, pero está **vetado** — el gemelo free entrena igual |
| `deepseek-v4-flash` | ~~`opencode/deepseek-v4-flash-free`~~ | ❌ **muerto** (`UnknownError`, dos intentos) |

Ese último renglón es la razón principal para haber movido el default a `mimo-v2.5`: el
ex-default se quedó sin red de rescate automático. Otros `*-free` que aparecen en `models.dev`
(`longcat-2.0-free`, `minimax-m3-free`, `qwen3.6-plus-free`, `x-preview-f-free`, `ox-alpha-free`)
**no responden** desde esta cuenta — no los pongas en un jobs.tsv sin probarlos. Free sin gemelo
que sí responde: `opencode/big-pickle`. `opencode/nemotron-3-ultra-free` contestó vacío.

**Los cuatro presupuestos, independientes entre sí:**

| Puerta | En `jobs.tsv` | Presupuesto | Para qué |
|---|---|---|---|
| Go | `mimo-v2.5` | $12/5h · $30/sem · $60/mes globales **+ tope por modelo** | el ancho, por default |
| Free | `opencode/mimo-v2.5-free` | gratis | el ancho cuando Go aprieta; fallback automático |
| ChatGPT | `codex` / `codex:<m>` | ventana ChatGPT | código/mecánico; **no** investigación web |
| Allegretto | `kimi-for-coding/k3` | suscripción Moonshot | pre-revisión y quirúrgico |

> **Ojo con "Use balance":** la consola de OpenCode tiene una opción que, al agotarse Go, sigue
> sirviendo requests cobrando a tu saldo Zen — o sea, **dinero real**. Si no la has activado a
> propósito, déjala apagada; el fallback bueno es el free, no el de pago.

## Codex CLI — segundo presupuesto (suscripción ChatGPT)

Verificado 2026-08-09 con codex-cli 0.147.0: `codex exec` corre **no-interactivo con el login de
ChatGPT** (sin API key). En `jobs.tsv` usa `codex` (modelo default) o `codex:<model>`; el helper
lo lanza como `codex exec --skip-git-repo-check --ephemeral -s read-only -o out_file`
(y `-C <dir>` si pasaste `--dir`).

- **El modelo default de `codex` sale de `~/.codex/config.toml`**, hoy `model = "gpt-5.5"` con
  `model_reasoning_effort = "xhigh"` — NO es Luna por default. Si quieres Luna (o Sol), pídelo
  explícito: `codex:gpt-5.6-luna` / `codex:gpt-5.6-sol`. Ambos probados OK.
- **Para qué:** unidades de código/mecánico/razonamiento sobre archivos locales, cuando la cuota
  Go escasea o para repartir un lote grande entre **dos presupuestos independientes** (Go +
  ChatGPT). Nota: `gpt-5.6-luna` también está EN el pool Go — codex no suma un modelo nuevo,
  suma **cuota** aparte.
- **Para qué NO:** investigación web (`codex exec` no trae web search) — eso siempre a opencode.
- **Límites:** los de la suscripción ChatGPT — ventana de 5h + tope semanal, medidos en créditos
  por tokens (Plus ≈ 50-280 mensajes Luna/5h; Pro ×20). Independientes de la cuota Go.
- **Escritura — ojo, en esta máquina el sandbox de codex está roto:** el default es `read-only`
  (probado: codex NO escribe, correcto). Pero `CHEAP_FANOUT_CODEX_SANDBOX=workspace-write`
  **falla** aquí con `bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted` — Ubuntu trae
  `kernel.apparmor_restrict_unprivileged_userns=1` y bubblewrap no puede crear su namespace, así
  que codex reporta el error y no escribe nada (verificado 2026-08-09, dentro y fuera del sandbox
  de Claude Code). Lo que SÍ funciona para jobs codex que editan:
  `CHEAP_FANOUT_CODEX_SANDBOX=danger-full-access` **+ worktree git aislado con `--dir`**. Ahí el
  worktree ES la contención: codex corre sin ninguna barrera de filesystem, así que nunca lo
  apuntes al repo real y revisa el diff antes de mergear. (Arreglo de fondo, decisión del usuario:
  perfil AppArmor para bwrap o bajar ese sysctl — es un ajuste de seguridad de todo el sistema.)
- **Luna por dos puertas — cómo alternar suscripciones:** la puerta se elige por job en el campo
  `model` del jobs.tsv: `gpt-5.6-luna` → `opencode run` → cuota **Go** (2,050 req/5h, pero tope
  **$15/mes** ⇒ ~10,250 req/mes y se acaba mucho antes que el pozo global);
  `codex:gpt-5.6-luna` → `codex exec` → cuota **ChatGPT**. Mismo modelo, presupuestos
  independientes; un mismo lote puede mezclar ambas. Regla: el ancho con Luna va por **Go** (su
  cuota es mucho mayor); `codex` es desborde — úsalo cuando Go dé 429 o quieras reservar la
  ventana Go para jobs que SOLO pueden ir por opencode (web research). Reintento típico: los
  jobs con `.status`≠0 por cuota se relanzan cambiando solo el campo `model` a `codex`.

## K3 subteniente — vía Kimi For Coding (suscripción Allegretto, Moonshot directo)

El proveedor `kimi-for-coding` de opencode (endpoint `https://api.kimi.com/coding/v1`) expone
`k3` (default), `k3-256k`, `kimi-for-coding` y `kimi-for-coding-highspeed`. En `jobs.tsv` van con
la ruta completa (el helper la pasa tal cual). Suscripción **Allegretto** ($39/mes, contexto 1M,
uso ≈5× el plan base; Moonshot no publica cifras exactas).

- **Credencial:** vive en `~/.local/share/opencode/auth.json` bajo la llave `kimi-for-coding`
  (alternativa: exportar `KIMI_API_KEY`). Es la misma llave `sk-kimi-…` de la suscripción.
  Smoke: `opencode run -m kimi-for-coding/k3 "Responde solo: PONG"` (medido 8s, 2026-08-09).
  Si devuelve `UnknownError` genérico → falta la credencial, no es congestión.
- **Guardrails:** pre-revisión solo con lotes ≥3 · K3 NUNCA en el ancho · máx 1-2 unidades
  difíciles por fan-out, y desde el 2026-08-28 **ese cupo se reserva para lo casi-frontier**: la
  unidad difícil ordinaria va antes a `glm-5.3-flash` (ver *El escalón de la unidad difícil*), que
  no gasta ni cuota Go relevante ni asiento de Allegretto · puerta primaria `kimi-for-coding/k3`
  (no gasta cuota Go), fallback
  `opencode-go/kimi-k3` (110 req/5h y tope **$15/mes** ⇒ ~490 req al mes en total) solo si
  Allegretto falla.
- **Guardrail de latencia (lección jul-2026):** si la pre-revisión tarda >5 min, mátala y revisa
  TÚ el lote completo; si reincide en la sesión, cae de vuelta a dos niveles. El flujo NUNCA se
  bloquea por K3: veredicto imparseable o 429 → revisión completa tuya.
- **Plantilla de pre-revisión** (el prompt del job K3; la línea de webfetch es clave — en el
  dry-run K3 verificó fuentes por iniciativa propia). **Modo por referencia:** el prompt NO lleva
  los contenidos, solo las RUTAS de los pares prompt→salida; K3 los abre con sus herramientas de
  archivo desde el cwd (los agentes de opencode sí leen archivos locales). La versión con todo
  concatenado es inutilizable en Windows con lotes medianos/grandes (límite ~32 KB de argv,
  hallazgo 2026-08-11):

  ```
  Eres pre-revisor de un lote. Abajo va la lista de N unidades como pares de RUTAS de archivo
  (prompt original → salida del agente barato). Abre cada archivo con tus herramientas de
  lectura desde el directorio actual; no asumas su contenido.
  ===PARES===
  U01: _fanout/prompt-U01.md → _fanout/U01.out
  U02: _fanout/prompt-U02.md → _fanout/U02.out
  ...
  Puedes usar webfetch para verificar fuentes. Responde EXACTAMENTE en este formato:
  ===VEREDICTOS===
  U01: OK|DUDOSO|FALLO — razón breve con el dato clave
  ===ALTO_IMPACTO===
  - dato → por qué el orquestador debe verificarlo en primaria
  ===BORRADOR===
  (síntesis solo de unidades OK, con URL fuente por dato)
  ===FIN===
  ```
- **Cuatro presupuestos, misma disciplina:** Go (el ancho barato; recuerda que dentro de Go cada
  modelo tiene además su propio tope mensual) · free (`opencode/*-free`, el ancho cuando Go
  aprieta; también el rescate automático) · ChatGPT/codex (desborde de
  código/mecánico) · Allegretto (K3: pre-revisión + quirúrgico). El orquestador alterna por job
  en el campo `model` y conserva el veredicto final.

## Reglas de oro (lecciones caras)

1. **Ningún output barato aterriza sin revisión.** Revisión = K3 pre-revisa el lote + TÚ haces
   spot-check (DUDOSO/FALLO, 1-2 OK al azar, todo alto impacto contra fuente primaria); un
   falso-OK muestreado invalida el veredicto del lote entero. La síntesis final la escribes TÚ
   (baratos y K3 son materia prima, no la respuesta). Para código, TÚ lees el diff y corres los
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
   seis modelos nuevos. Nada de eso se avisa: se descubre releyendo.
   Hay además **DOS tablas de precios**. `opencode.ai/docs/go` = tu plan ($10/mes): sus precios no
   se te cobran, son la tarifa contable que consume los límites. `opencode.ai/docs/zen` =
   pay-as-you-go, dinero real. Pueden divergir mucho (el caso clásico era v4-pro, 4x más caro en
   Zen — al 2026-08-28 ya convergieron, así que ni siquiera el ejemplo aguanta). Esta tabla usa
   **Go**. Si un número te parece raro, revisa de cuál de las dos páginas viene antes de
   "corregirlo". *(Lección 2026-08-09: un borrador de este skill traía la cifra Zen de v4-pro en
   una tabla de ruteo Go — el número era real, el producto era el equivocado.)*
6. **Disciplina de tokens.** El orquestador solo en planear+revisar+síntesis final; el ancho, siempre barato.

## Troubleshooting

| Síntoma | Arreglo |
|---|---|
| Solo corre el primer lote de `--parallel` | Falta el `< /dev/null` del helper — usa bin/cheap-fanout tal cual |
| `database is locked` | Carrera de ARRANQUE, no de concurrencia sostenida: opencode instala `busy_timeout` DESPUÉS de convertir la base a WAL, así que solo muerde con la base fría. El helper ya precalienta y reintenta; si llega hasta ti (`.status=75`), corre `opencode db "SELECT 1"` a mano y relanza, o sube `CHEAP_FANOUT_RETRIES` |
| `.status` = 75 / "SQLITE BLOQUEADO" | Agotó los reintentos. Misma receta: precalentar a mano y relanzar. Bajar `--parallel` ayuda poco si la base sigue fría |
| `Failed query: CREATE TABLE …` | La otra cara de la misma carrera: dos procesos fríos aplicaron la misma migración. Reintentar es seguro (DDL transaccional); el helper ya lo hace |
| `.status` = 66 / "SALIDA VACÍA" | Tercera cara, silenciosa: exit 0 pero el `.out` solo traía cabecera. El helper la reintenta; si persiste, es que el modelo de verdad no dijo nada |
| `.status` = 64 / "PROMPT DEMASIADO LARGO" | El prompt excede el argv del sistema (~28 KB en Windows). El job NO se lanzó: reházlo por referencia (rutas de archivos en un prompt corto) o sube `CHEAP_FANOUT_ARGV_MAX` si sabes lo que haces |
| exit 126 `Argument list too long` (corrido a mano) | El prompt viaja como argumento y Windows topa en ~32 KB. Pásalo por el helper (que lo detecta antes con status 64) o usa prompt por referencia |
| Salida con basura al inicio | Cabecera de opencode (`> build · <model>`) **más códigos ANSI** (`\x1b[0m`): limpia ambos antes de parsear o medir si está vacía |
| Job devolvió null/basura | Rehazlo o reasígnalo a un modelo mejor; no lo integres a ciegas |
| `.status` = 124 o 137 | El job venció su plazo y el helper lo mató. Sube la 4ª columna de ESE job (o `none`) y relánzalo; si vence otra vez, el modelo se está atorando: reasigna |
| `timeout inválido: 'X'` | La 4ª columna solo admite `90`, `30s`, `8m`, `1h` o `none` |
| `.status` = 77 / "SIN CUOTA" | Ese modelo se quedó sin presupuesto y no tiene gemelo free. Corre `go-budget` **antes de decidir**: si lo agotado es el tope de ESE modelo (global holgado), mándalo a otro modelo Go con tope disponible; si lo agotado es el pozo global, cambiar de modelo Go no sirve — vete a `codex`, `kimi-for-coding/k3` o un free |
| `This model collects data used to improve its quality and requires explicit opt in` | Es `muse-spark-1.2-contributor`, que está **vetado**: no lo actives en la consola. Rutea a `mimo-v2.5` |
| `MODELO VETADO` (exit 2, no corrió nada) | El helper rechaza el lote **entero en pre-vuelo** si algún job usa un modelo vetado — mejor que gastar cuota en los demás y descubrirlo al final. Cambia el modelo de esa línea (ver *Modelos vetados*), no la variable de entorno |
| Un modelo de la doc no aparece en `opencode models` | Esa lista viene desfasada; no es autoridad. Pruébalo con `opencode run -m opencode-go/<id> "Responde exactamente: PONG"` antes de descartarlo |
| Lote DeepSeek gastó el doble de lo esperado | Horas peak (dom-jue 19:00-22:00 y lun-vie 00:00-04:00 CDMX): los tres modelos DeepSeek cuestan 2x. Córrelo fuera de esa franja o usa `mimo-v2.5` |
| "cuota Go agotada → servido por opencode/…-free" | No es un error: el helper rescató ese job en el gemelo gratuito del mismo modelo. Corre `go-budget` para ver cuánto falta para que se libere la ventana |
| El agente "no puede buscar" | opencode solo tiene `webfetch`: dale una URL de arranque. codex no tiene web search: reasigna a opencode |
| El agente reporta 403 / "bloqueado" / página vacía | No es culpa del modelo: el fetcher está bloqueado. Sube la cascada de 3 escalones (`r.jina.ai` → ZenRows GET) |
| `r.jina.ai` da 200 pero el `.out` viene vacío | Cloudflare/CAPTCHA — Jina respeta el bloqueo por diseño. Escala a ZenRows con `premium_proxy=true` |
| Job con ZenRows muere en 124 (timeout) | Normal: una request `js_render+premium_proxy` tarda ~75s. Sube la 4ª columna a `8m` o `none` |
| `r.jina.ai` da 403 `AbuseAlleviationError` | El dominio está vetado para acceso anónimo (p.ej. x.com). Con API key de Jina o directo a ZenRows |
| Job codex colgado (corrido a mano) | `codex exec` lee stdin: añade `< /dev/null` (el helper ya lo hace) |
| codex "not logged in" | Corre `codex login` una vez en sesión interactiva (auth ChatGPT) |
| Job codex no escribe: `bwrap: loopback: Failed RTM_NEWADDR` | El sandbox `workspace-write` no sirve en esta máquina (AppArmor bloquea userns). Ver la viñeta **Escritura** de la sección de Codex CLI |
| `Invalid Authentication` con `moonshotai/*` | Esa llave es de Kimi For Coding, no de api.moonshot.ai: usa la ruta `kimi-for-coding/k3` |
| `kimi-for-coding/k3` da `UnknownError` | Falta credencial: añade `kimi-for-coding` a `~/.local/share/opencode/auth.json` o exporta `KIMI_API_KEY` |
| K3 devuelve veredicto imparseable | No reintentes: revisa TÚ el lote completo (flujo de 2 niveles) |
| K3 429/cuota o >5 min | Mata el job y revisa TÚ; si reincide en la sesión, 2 niveles el resto |

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
| **Subteniente** | `kimi-for-coding/k3` (suscripción Allegretto) | Pre-revisa el lote entero en 1 request (1M ctx); 1-2 unidades difíciles; borrador de síntesis | El ancho; planear/rutear |
| **Ejecutores** | `deepseek-v4-flash`, `mimo-v2.5`, `hy3`, `gpt-5.6-luna`… (Go) y `codex` (Codex CLI) | El ancho: N unidades en paralelo | Decidir o preguntar nada |

## Flujo (6 pasos)

1. **Descomponer** en N unidades independientes. Ownership disjunto: dos jobs nunca tocan el mismo archivo.
2. **Rutear** cada unidad al mejor modelo barato (tabla abajo — decide TÚ, no un router LLM).
   La tabla de este archivo es la referencia de ruteo, pero **caduca**: la fuente de verdad de
   precios y cuotas es `opencode.ai/docs/go`. Si vas a rutear por precio en una decisión cara, o
   si un número te parece raro, reléela ahí (y no la confundas con `opencode.ai/docs/zen`, que
   cotiza los mismos modelos a precio de pago-por-uso). Lo que el proveedor sirve hoy te lo dice
   `opencode models`.
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
~/.claude/skills/cheap-fanout/bin/go-budget   # cuánto llevas de la cuota Go
```
- El `<model>` admite tres formas (verificadas 2026-08-09):
  - `deepseek-v4-flash` — sin prefijo ⇒ el helper le pone `opencode-go/` (plan Go).
  - `kimi-for-coding/k3` — cualquier ruta `<provider>/<id>` de opencode pasa **tal cual**
    (suscripción directa Moonshot; no gasta cuota Go).
  - `codex` o `codex:<model>` — corre por `codex exec` con la suscripción ChatGPT. En jobs codex,
    `out_file` trae SOLO el mensaje final; la traza completa queda en `out_file.log`.
- Concurrencia: en **Linux** el default 6 es razonable (lo medido el 2026-08-09 llega hasta
  `--parallel 4` con lote mixto de 5 jobs, 0 fallos; arriba de eso no está probado aquí).
  En **Windows** baja a 2-3 → varias instancias concurrentes de
  `opencode` chocan con `database is locked` (SQLite) y el job falla silencioso; por eso revisa
  siempre `.status` y reintenta los status≠0 con menos concurrencia. Los jobs codex no usan ese
  SQLite (corren `--ephemeral`): un lote mixto reparte mejor la concurrencia.
  **El límite de Windows (2-3) es GLOBAL por máquina, no por lote:** todas las invocaciones de
  cheap-fanout comparten el MISMO SQLite de opencode — dos lotes `--parallel 2` a la vez son 4
  instancias y ya estás en zona de fallo (medido 2026-08-11). No lances dos lotes simultáneos en
  Windows; y si ya hay un lote corriendo, cuenta sus jobs contra tu `--parallel`.
  **Ojo con la variante silenciosa del choque:** también puede terminar con **`.status=0` y un
  `.out` que trae SOLO la cabecera** `> build · <model>` (28 bytes) — pasa el check de status.
  El helper ya la detecta y la marca `.status=66` ("SALIDA VACÍA"), y los `.out` traen códigos
  ANSI (`\x1b[0m`) además de la cabecera: cualquier parser tuyo debe limpiarlos antes de medir.
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

## Ruteo por caso — modelos verificados (OpenCode Go/Zen; precios releídos 2026-08-09)

Precios per 1M tokens (input/output). Cuota Go en requests por ventana de 5h.

| Caso de uso | Primario | Fallback | Por qué |
|---|---|---|---|
| **Investigación web / fetch+resumen** | `deepseek-v4-flash` | `mimo-v2.5` | Más barato ($0.14/$0.28), 1M ctx, cuota altísima. **DEFAULT.** |
| **Mecánico simple en lote** | `deepseek-v4-flash` | `mimo-v2.5` · `codex` | Barato + alta cuota; codex si quieres gastar el presupuesto ChatGPT en vez del Go |
| **Resumen/ingesta masiva o multimodal** (img/audio/video) | `mimo-v2.5` | `mimo-v2.5-pro` | Multimodal nativo, 1M ctx, mismo precio que flash ($0.14/$0.28) y 30,100 req/5h; el pro ($0.435/$0.87, 3,250/5h) para unidades multimodales difíciles |
| **Contexto ultra-largo barato** (repo/paper completo) | `deepseek-v4-flash` | `minimax-m3` | flash 1M y baratísimo; M3 si necesitas coding/agentic en ese ctx ($0.30/$1.20) |
| **Código acotado con spec cerrada** | `hy3` | `qwen3.7-plus` | $0.14/$0.58, 4,300 req/5h, 256K, SWE-bench ~74% con solo 21B activos (295B MoE Tencent) |
| **Código con razonamiento algorítmico** | `deepseek-v4-pro` | `hy3` | Coding de élite a $0.435/$0.87 — solo cuesta cuota (3,450 req/5h, ~10x menos que flash) |
| **Código agentic multi-paso (>5 tools)** | `deepseek-v4-flash` | `gpt-5.6-luna` · `kimi-k2.7-code` | El build 0731 de flash fue re-post-entrenado: gana a V4-Pro-Preview en los 9 benchmarks de agente (Terminal Bench 2.1 82.7, DeepSWE 54.4) al mismo precio. Luna gana a flash en DeepSWE/Terminal-Bench y es multimodal ($0.20/$1.20, 2,050/5h) |
| **Bug-fixing / SWE con repro claro** | `glm-5.2` | `hy3` | SWE bug-fix + artefactos UI. Caro ($1.40/$4.40); hy3 alternativa barata con SWE alto |
| **Unidad casi-frontier quirúrgica** (1-2 por sesión) | `kimi-for-coding/k3` | `kimi-k3` (Go) · `qwen3.8-max` · `grok-4.5` | K3 por la suscripción directa Moonshot (Allegretto) NO gasta cuota Go; la vía Go (110 req/5h) queda de fallback. Nunca en el ancho |
| **Delicado / frontier** (arquitectura, seguridad, semántica, revisión y síntesis) | **orquestador (tú/Claude, Opus)** | — | NUNCA a un barato |

### Catálogo completo del pool Go (cuota → precio → contexto)

Cuotas y precios releídos en `opencode.ai/docs/go` el **2026-08-09**; los contextos vienen de la
documentación de cada proveedor (esa página no los publica).

| id | req/5h | $/1M in/out | ctx | Nota |
|----|-------:|---|:--:|------|
| `deepseek-v4-flash` | 31,650 | $0.14/$0.28 | 1M | DEFAULT. Build **0731**: agentic al nivel de pro |
| `mimo-v2.5` | 30,100 | $0.14/$0.28 | 1M | Multimodal nativo, cuota altísima, precio de flash |
| `hy3` | 4,300 | $0.14/$0.58 | 256K | Tencent 295B/21B act. Razonamiento/SWE altos, baratísimo |
| `qwen3.7-plus` | 4,300 | $0.40/$1.60 | 256K | Tool-calling+MCP, think/no_think. **Escalón: >256K tokens factura $1.20/$4.80** |
| `deepseek-v4-pro` | 3,450 | $0.435/$0.87 | 1M | Coding de élite, 3 modos. Barato en $, caro en cuota. (En Zen cuesta $1.74/$3.48 — no confundir, ver regla 5) |
| `minimax-m2.7` | 3,400 | $0.30/$1.20 | 192K | Gen previa de M3 |
| `qwen3.6-plus` | 3,300 | $0.50/$3.00 | — | Gen previa de 3.7-plus. **Escalón >256K: $2.00/$6.00** |
| `mimo-v2.5-pro` | 3,250 | $0.435/$0.87 | 1M | Multimodal reforzado |
| `minimax-m3` | 3,200 | $0.30/$1.20 | 1M | Frontier-coding barato, agentic ctx largo |
| `gpt-5.6-luna` | 2,050 | $0.20/$1.20 | 1.05M | OpenAI tier barato; agentic/multimodal fuerte. **Escalón: >272K tokens factura $0.40/$1.80.** Mismo modelo que puede correr Codex CLI |
| `kimi-k2.7-code` | 1,350 | $0.95/$4.00 | 262K | Coding agentic multi-paso |
| `kimi-k2.6` | 1,150 | $0.95/$4.00 | 262K | Gen previa de k2.7 |
| `glm-5.2` | 880 | $1.40/$4.40 | 1M | SWE bug-fixing, artefactos UI |
| `glm-5.1` | 880 | $1.40/$4.40 | 200K | Gen previa de 5.2 |
| `qwen3.7-max` | 340 | $2.50/$7.50 | — | Quirúrgico |
| `qwen3.8-max` | 160 | $2.00/$6.00 | 1M | 2.4T multimodal flagship. Quirúrgico |
| `grok-4.5` | 120 | $2.00/$6.00 | 500K | Quirúrgico. **Escalón punitivo: ≥200K tokens factura TODO el request a $4.00/$12.00** |
| `kimi-k3` | 110 | $3.00/$15.00 | 1M | Casi-frontier abierto. Quirúrgico. **Preferir la puerta `kimi-for-coding/k3`** (suscripción directa, no gasta Go) |

> **Precio ≠ cuota.** La regla "más barato ⇒ más cuota" es aproximada, no exacta:
> `deepseek-v4-pro` cuesta $0.435 pero solo da 3,450 req/5h. Lo que se agota es la **cuota**, así
> que el ancho va a los de cuota alta (`flash`/`mimo`/`hy3`); los de <400 req/5h
> (`qwen3.7-max`, `qwen3.8-max`, `grok-4.5`, `kimi-k3`) son para 1-2 unidades quirúrgicas por
> sesión, nunca para el ancho.

## Cuota Go agotada — el helper lo maneja solo

**Nunca prohíbas un modelo a mano por cuota.** No hace falta y además no sirve: el plan Go limita
por **dólares** con un **pozo único compartido** ($12/5h · $30/semana · $60/mes, verificado en
`opencode.ai/docs/go`: *"Limits are defined in dollar value"*). Cambiar de `deepseek-v4-flash` a
`mimo-v2.5` no consigue un dólar más — comen del mismo pozo.

**Lo que sí funciona, y ya está automatizado:**

1. **Antes de un lote grande, mide.** `bin/go-budget` lee la base local de opencode y te dice el
   consumo de las tres ventanas. Exit code: `0` holgado · `1` ≥80% · `2` agotado. Si marca 1 o 2,
   manda el ancho directo a los modelos free y reserva Go para lo que no tenga gemelo.
2. **Durante el lote, el helper detecta y rescata.** Al ver la firma
   `Provider rate limit exceeded` en la salida de un job, lo reintenta **una vez en el gemelo
   gratuito del mismo modelo** (`opencode/<id>-free`), que la doc de Go señala explícitamente:
   *"If you reach the usage limit, you can continue using the free models"*. Es el **mismo modelo**,
   presupuesto distinto — no cambia la calidad. `--on-quota off` lo desactiva.
3. **Si no hay gemelo free, el helper NO sustituye el modelo.** Deja el job en `.status=77`
   ("SIN CUOTA") y te lo reporta. Cambiar `kimi-k3` por otra cosa es una decisión de calidad y
   es tuya, no del script.

Gemelos free verificados (2026-08-09, responden y cuestan $0): `deepseek-v4-flash` y `mimo-v2.5`
— justo los dos caballos de batalla del ancho. `hy3`, `kimi-k3`, `glm-5.2` y los demás no tienen.
Hay más modelos free sin gemelo Go (`opencode/big-pickle`, `longcat-2.0-free`, `nemotron-3-ultra-free`…)
que puedes usar a propósito para el ancho cuando quieras no gastar cuota en absoluto.

**Los cuatro presupuestos, independientes entre sí:**

| Puerta | En `jobs.tsv` | Presupuesto | Para qué |
|---|---|---|---|
| Go | `deepseek-v4-flash` | $12/5h compartido | el ancho, por default |
| Free | `opencode/deepseek-v4-flash-free` | gratis | el ancho cuando Go aprieta; fallback automático |
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
  `model` del jobs.tsv: `gpt-5.6-luna` → `opencode run` → cuota **Go** (2,050 req/5h);
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
  difíciles por fan-out · puerta primaria `kimi-for-coding/k3` (no gasta cuota Go), fallback
  `opencode-go/kimi-k3` (110 req/5h) solo si Allegretto falla.
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
- **Cuatro presupuestos, misma disciplina:** Go (el ancho barato) · free (`opencode/*-free`, el
  ancho cuando Go aprieta; también el rescate automático) · ChatGPT/codex (desborde de
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
5. **Los números de ESTE archivo también caducan, y hay DOS tablas de precios de opencode.**
   `opencode.ai/docs/go` = tu plan ($10/mes): sus precios no se te cobran, son la tarifa contable
   que consume los límites ($12/5h, $30/sem, $60/mes). `opencode.ai/docs/zen` = pay-as-you-go,
   dinero real. **No son iguales:** `deepseek-v4-pro` vale $0.435/$0.87 en Go y $1.74/$3.48 en Zen
   (4x); `deepseek-v4-flash` vale $0.14/$0.28 en las dos. Esta tabla usa **Go**, que es lo que
   gobierna cuándo te quedas sin ventana. Si un número te parece raro, revisa de cuál de las dos
   páginas viene antes de "corregirlo". *(Lección 2026-08-09: un borrador de este skill traía la
   cifra Zen de v4-pro en una tabla de ruteo Go — el número era real, el producto era el
   equivocado.)*
   **Alza anunciada:** DeepSeek dice en la nota al pie 2 de `api-docs.deepseek.com/quick_start/pricing/`
   (leída 2026-08-09): *"We plan to raise the overall pricing for DeepSeek API services in the near
   future, with a significant increase expected."* Sin fecha. Lo anunció DeepSeek, no OpenCode.
6. **Disciplina de tokens.** El orquestador solo en planear+revisar+síntesis final; el ancho, siempre barato.

## Troubleshooting

| Síntoma | Arreglo |
|---|---|
| Solo corre el primer lote de `--parallel` | Falta el `< /dev/null` del helper — usa bin/cheap-fanout tal cual |
| `database is locked` (Windows) | Baja `--parallel` a 2-3; reintenta los status≠0. El límite es GLOBAL por máquina: no corras dos lotes cheap-fanout a la vez |
| `.status` = 66 / "SALIDA VACÍA" | Variante silenciosa del choque de SQLite: exit 0 pero el `.out` solo traía cabecera. Reintenta ese job con menos concurrencia y sin otros lotes corriendo |
| `.status` = 64 / "PROMPT DEMASIADO LARGO" | El prompt excede el argv del sistema (~28 KB en Windows). El job NO se lanzó: reházlo por referencia (rutas de archivos en un prompt corto) o sube `CHEAP_FANOUT_ARGV_MAX` si sabes lo que haces |
| exit 126 `Argument list too long` (corrido a mano) | El prompt viaja como argumento y Windows topa en ~32 KB. Pásalo por el helper (que lo detecta antes con status 64) o usa prompt por referencia |
| Salida con basura al inicio | Cabecera de opencode (`> build · <model>`) **más códigos ANSI** (`\x1b[0m`): limpia ambos antes de parsear o medir si está vacía |
| Job devolvió null/basura | Rehazlo o reasígnalo a un modelo mejor; no lo integres a ciegas |
| `.status` = 124 o 137 | El job venció su plazo y el helper lo mató. Sube la 4ª columna de ESE job (o `none`) y relánzalo; si vence otra vez, el modelo se está atorando: reasigna |
| `timeout inválido: 'X'` | La 4ª columna solo admite `90`, `30s`, `8m`, `1h` o `none` |
| `.status` = 77 / "SIN CUOTA" | Go agotado y ese modelo no tiene gemelo free. NO lo cambies por otro modelo Go (mismo pozo): mándalo a `codex`, a `kimi-for-coding/k3`, o a un free a propósito |
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

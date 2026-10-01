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
el subteniente (un modelo rápido; K3 como segundo revisor) pre-revisa el lote; los baratos
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
| **Orquestador** | Claude/tú (frontier: Opus 5.5 = II 58, Sonnet 5.5 = 56) | Descompone, rutea, **spot-check**, veredicto y síntesis **final** | El ancho; re-revisar lo ya limpio |
| **Subteniente** | `deepseek-v4.1-flash` (rápido: 141s medido) y, en lotes de alto impacto, `kimi-code-plan-cn/k3` en paralelo (271s) | Pre-revisa el lote entero en 1 request (1M ctx); borrador de síntesis; cruza unidades | El ancho; planear/rutear; la unidad difícil ordinaria (ésa va a `glm-5.3-flash`) |
| **Casi-frontier** | `codex:gpt-6.1-sol` (II 52; suscripción ChatGPT) | 1-2 unidades quirúrgicas por sesión | El ancho |
| **Ejecutores** | `deepseek-v4.1-flash`, `glm-5.3-flash`… (Go) y `codex:gpt-6-luna` (Codex CLI) | El ancho: N unidades en paralelo | Decidir o preguntar nada |

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
5. **Pre-revisión** (lotes ≥3): un job `deepseek-v4.1-flash` —y, si el lote es de alto impacto,
   otro `kimi-code-plan-cn/k3` en paralelo— recibe, **por referencia**, no
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
   baratos, el subteniente y K3 son materia prima, no la respuesta). En código: TÚ lees el diff y corres los tests.

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
- El `<model>` admite tres formas (verificadas 2026-10-01):
  - `deepseek-v4.1-flash` — sin prefijo ⇒ el helper le pone `opencode-go/` (plan Go).
  - `kimi-code-plan-cn/k3` — cualquier ruta `<provider>/<id>` de opencode pasa **tal cual**
    (suscripción directa Moonshot; no gasta cuota Go; necesita `KIMI_API_KEY` o la credencial
    bajo ese nombre: ver *K3 y Kimi*). La ruta vieja `kimi-for-coding/*` se traduce sola.
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

## Páginas que bloquean bots — cascada de 3 escalones

El bloqueo es contra el **fetcher** (`webfetch` es un GET plano, sin JS ni rotación de IP), no
contra el modelo. Escala solo cuando el escalón previo falle: **1.** `webfetch` directo →
**2.** Jina Reader (`https://r.jina.ai/<URL>`: gratis, renderiza JS, **no es bypass**; si devuelve
cuerpo vacío o "requiring CAPTCHA", no falló el modelo) → **3.** ZenRows por GET con
`js_render=true&premium_proxy=true&response_type=markdown` (25 créditos por página, 200 al mes
gratis, ~75s por request ⇒ plazo `8m` y `--parallel 4`; la key va literal en el prompt file
temporal y **nunca** en el repo ni en este archivo). URL exacta, manejo de la key, números medidos
y lo que NO entra por esta puerta: `reference/bloqueo-bots.md`.

## Ruteo por caso — modelos verificados (OpenCode Go; releído 2026-10-01)

Precios en USD por 1M tokens (input/output). Cuota Go en requests por ventana de 5h. **`límite`** =
los dólares mensuales que ESE modelo puede consumir del plan; de él salen sus tres ventanas (ver
*Cuota Go*). **`II`** = Artificial Analysis Intelligence Index **v4.3.2** (tercero independiente,
leído en `artificialanalysis.ai/leaderboards/models` el 2026-10-01). **El índice se reescala entre
versiones**: compáralo solo dentro de la misma, y no lo mezcles con el "57" que este skill citaba
para `glm-5.3-flash` (era la v4.1.1, citada por Z.ai; el mismo modelo hoy marca 42). **`seg`** =
tiempo de pared medido en esta máquina en una extracción de ~6K tokens de entrada (mediana de 2
corridas, con ~9 procesos `opencode` simultáneos: las cifras absolutas se inflan unos segundos,
el orden no).

> **El precio por token no es el costo por tarea.** `mimo-v2.5` cuesta 0.14/0.28 y tardó 50s;
> `deepseek-v4.1-flash` cuesta 0.15/0.60 y tardó 17s. Con la misma exactitud (los 14 modelos
> de opencode que probé sacaron 84/84 en una extracción con trampas), la velocidad decide el
> caballo del ancho. **Los números de velocidad de AA son dato vivo y se mueven entre capturas**
> (TTFT de Grok 4.7: 78.69s → 42.40s en minutos); los índices II no se movieron.

| Caso de uso | Primario | Fallback | Por qué |
|---|---|---|---|
| **Investigación web / fetch+resumen** | `deepseek-v4.1-flash` | `glm-5.3-flash` · `longcat-2.0` | 0.15/0.60, 26,000 req/5h, límite 60, II 39, 1M ctx con imagen, 17s medido y 209 tokens/s según AA. Duplica en horas peak (ver abajo). **DEFAULT del ancho.** |
| **Mecánico simple en lote** | `deepseek-v4.1-flash` | `glm-5.3-flash` · `mimo-v2.6-flash` · `codex:gpt-6-luna` | `mimo-v2.6-flash` es el más barato por token (0.14/0.28) pero 4x más lento; codex lee y escribe archivos desde el 2026-10-01 (sandbox arreglado; ver *Codex CLI*) |
| **Resumen/ingesta masiva o multimodal** (img/video/PDF/audio) | `glm-5.3-flash` | `mimo-v2.6-flash` · `deepseek-v4.1-flash` | `glm-5.3-flash` ingiere texto+imagen+video+PDF, 1M ctx, II 42, 17.5s. Solo `mimo-v2.6-*` acepta audio (y es lento). `deepseek-v4.1-flash` solo imagen |
| **Contexto ultra-largo barato** (repo/paper completo) | `deepseek-v4.1-flash` | `mimo-v2.6-flash` · `glm-5.3-flash` | 1M ctx y el caché de lectura más barato del pool junto con mimo (0.003 vs 0.0028 por 1M); `longcat-2.0` ya no compite (0.006 y II 19) |
| **Código acotado con spec cerrada** | `deepseek-v4.1-flash` | `glm-5.3-flash` · `hy3` | `hy3` (II 25, 256K) quedó dominado: menor índice y 6x menos cuota por casi el mismo precio. Su única ventaja es no tener recargo peak |
| **Código agentic multi-paso (>5 tools)** | `deepseek-v4.1-flash` | `glm-5.3-flash` · `gpt-6-luna` | DeepSeek declara V4.1-Flash por encima de V4-Pro en rendimiento, costo y velocidad y AA lo confirma (39 vs 36). **No medí agentic propio: la evidencia es el índice más lo que dice el proveedor** |
| **Bug-fixing / SWE con repro claro** | `glm-5.3-flash` | `glm-5.3` | AA: flash 42 vs `glm-5.3` 45, a 1/10 del precio. Que supere a `glm-5.2` es dicho de Z.ai (AA ya no lista 5.2); `glm-5.2` y `glm-5.1` quedan fuera del ruteo, Z.ai los enruta a 5.3 |
| **Razonamiento algorítmico / semi-quirúrgico** | `mimo-v2.6-pro` | `glm-5.3` | II 46 (el más alto entre abiertos, según AA) a 0.435/0.87. **Lento**: 147s en la extracción. `deepseek-v4-pro` salió del ruteo: II 36 y DeepSeek lo está retirando |
| **Unidad difícil dentro del lote** (1-3 por lote) | `glm-5.3-flash` | `mimo-v2.6-pro` · `glm-5.3` | II 42: a 2-4 puntos de K3 (44), `glm-5.3` (45) y `mimo-v2.6-pro` (46), a una fracción del precio (1/3 a 1/30) y más rápido que K3 y que `mimo-v2.6-pro` en mi medición |
| **Unidad casi-frontier quirúrgica** (1-2 por sesión) | `codex:gpt-6.1-sol` | `codex:gpt-6-astra` · `kimi-code-plan-cn/k3` | II 52 y 53 contra 44 de K3. Suscripción ChatGPT: no gasta Go ni tokens de Anthropic. Exige Codex ≥ 0.159.1 para `gpt-6.1-sol` (aquí ya está en 0.159.3 y responde; ver *Codex CLI*). K3 queda para cuando importe su 1M de contexto o su visión |
| **Delicado / frontier** (arquitectura, seguridad, semántica, revisión y síntesis) | **orquestador (tú/Claude)** | — | NUNCA a un barato. AA: Opus 5.5 = 58, Sonnet 5.5 = 56, Fable 5.1 = 53 |

### Qué pre-revisa el lote — medido el 2026-10-01

Sobre las **mismas 19 unidades** (por referencia): `deepseek-v4.1-flash` **141s**, 19/19, cruza
unidades (13 discrepancias) pero dio OK a un informe sin citas; `kimi-code-plan-cn/k3` **271s**,
19/19, hace cumplir la regla de citas; `glm-5.3-flash` 367s y `glm-5.3` 802s con 15/19; K2.8
Preview 584s sin seguir el formato; `mimo-v2.6-pro` 17 minutos; K3 `--variant low` 349s y peor.
Tabla completa y qué problema detectó cada uno: `reference/catalogo-go.md`.

**Regla:** pre-revisor por default `deepseek-v4.1-flash`; en lotes de alto impacto lanza **a K3 en
paralelo** (tiempo de pared = el de K3, no la suma, y no gasta Go ni Anthropic) y cruza los dos
veredictos: se complementan (el rápido cruza unidades, K3 hace cumplir la regla de citas; con la
plantilla nueva de abajo la cita textual ya va explícita). Los modelos de índice alto (`glm-5.3`,
`mimo-v2.6-pro`) **no sirven de pre-revisores**: 13-17 minutos y peor cobertura. Es **un solo
lote**: evidencia delgada. Si vas a depender de esto, repite la comparación con otro lote.

### El escalón de la unidad difícil (reconfirmado 2026-10-01)

En un lote de ocho unidades casi siempre hay una o dos **más difíciles que el resto** —no de
frontier, pero más de lo que `deepseek-v4.1-flash` hace bien—. `glm-5.3-flash` las cubre: II 42
medido por un tercero, a 0.15/0.50, 17.5s, y **desde hoy con límite 60** (antes 15, que lo dejaba
"físicamente fuera del ancho"; ahora es también un segundo caballo viable del ancho).

> **Lo que ya no se sostiene y lo que sigue siendo evidencia delgada.** El "índice 57 = Opus 4.8
> = K3" era de otra versión del índice: hoy es 42 contra 44 de K3 y 58 de Opus 5.5. La
> equivalencia con K3 vale (2 puntos); la que había con un frontier de Anthropic, no. Y sigue
> sin haber un comparativo mío de calidad en una unidad *genuinamente* difícil: el benchmark de hoy
> (extracción con trampas) no discrimina, los 14 modelos sacaron 84/84. **Cómo validarlo:** la
> próxima unidad difícil real, mándala a `glm-5.3-flash` y a `codex:gpt-6.1-sol` y compara.

### Catálogo completo del pool Go

Los 30 modelos del plan con cuota, límite, precio, contexto, índice II y velocidad medida están en
`reference/catalogo-go.md` (releído el 2026-10-01). La tabla de arriba ya decide el ruteo: abre el
catálogo solo para un caso que no cubra o para un número exacto.

> **Precio ≠ cuota ≠ límite ≠ velocidad.** Son cuatro cosas. El ancho va a los de cuota alta
> **con límite 60** y buena velocidad (`deepseek-v4.1-flash`, `glm-5.3-flash`); los de <400 req/5h
> (`glm-5.3`, `qwen3.8-max`, `kimi-k3`) son 1-2 unidades quirúrgicas por sesión, nunca el ancho.
> Fuera de la doc desde el 2026-08-28 (no los rutees): `glm-5.1`, `minimax-m2.5`, `qwen3.7-max`,
> `qwen3.6-plus`, `grok-4.5`. `opencode models` es una lista desfasada: la prueba real de que un
> modelo existe es `opencode run -m <ruta> "Responde exactamente: PONG"`.

### Peak/off-peak de DeepSeek (mecánica vigente)

Los cuatro modelos DeepSeek (`v4.1-flash`, `v4-flash`, `v4-flash-vision-exp`, `v4-pro`) cuestan
**el doble** en horas peak: **01:00-04:00 y 06:00-10:00 UTC, lunes a viernes**; todo lo demás,
fines de semana incluidos, es off-peak. En hora de CDMX (UTC-6) el peak cae **domingo a jueves
19:00-22:00** y **lunes a viernes 00:00-04:00**. Un lote grande de `deepseek-v4.1-flash` corrido a
las 20:00 de CDMX consume el doble de límite que a las 10:00. Ningún otro modelo del pool lo hace
(para un lote enorme en peak, `glm-5.3-flash` cuesta lo mismo todo el día).

### Privacidad de los modelos Go (tabla vigente de la doc, 2026-10-01)

Casi todo el pool es **sin entrenamiento y 0 días de retención**. Las excepciones importan:

| Modelo | Entrenamiento | Retención |
|---|---|---|
| `muse-spark-1.3-contributor`, `muse-spark-1.2-contributor` | **Sí, entrena con tus datos** | **No es ZDR** |
| `grok-4.7`, `grok-4.6`, `gpt-6-luna`, `gpt-5.6-luna` | No | 30 días |
| DeepSeek (los cuatro) | No | 0 días* — *"el acuerdo ZDR se renueva cada mes; el vigente vale hasta el 31 de octubre de 2026"* |
| Todos los demás | No | 0 días |

**LongCat — discrepancia que no pude cerrar.** La doc de OpenCode dice "sin entrenamiento, 0 días"
para su ruta, pero la política de privacidad **propia** de Meituan (`longcat.chat/privacy`) permite
usar datos desidentificados para entrenar y optimizar modelos y exige guardar ciertos logs ≥6
meses. Úsalo **solo vía OpenCode** y no con material sensible del cliente hasta confirmar el
acuerdo; nunca apuntes a la plataforma de Meituan directamente.

## Modelos vetados — decisión permanente de Antonio (2026-08-28; ampliada y confirmada 2026-10-01)

**Los modelos de esta tabla NO se usan, aunque los números inviten.** Es política del skill y el
helper la aplica sola (`bin/cheap-fanout` rechaza el job antes de lanzarlo). Están marcados 🚫 en
el catálogo a propósito, en vez de borrados, para que una relectura de la doc no los "redescubra"
por su cuota y los vuelva a meter al ruteo.

| Vetado | Por qué |
|---|---|
| `muse-spark-1.2-contributor` y `muse-spark-1.3-contributor` **y sus gemelos free** | Trato explícito "cuota gigante a cambio de tus datos": 12x menos en input que `muse-spark-1.3` (1.25/4.25) porque Meta usa lo que le mandes para entrenar. Entrena y no es ZDR. Que tenga la cuota más alta del pool (45,300 req/5h) es el anzuelo. **El 1.3 se añadió el 2026-10-01 por analogía exacta (mismo texto de la doc) y Antonio lo confirmó ese día** |
| `grok-4.6` | Su **agentic coding regresó** frente a 4.5 y su time-to-first-token pasó de 8.7s a 31.2s; AA hoy lo marca "deprecated". Retiene datos 30 días |
| `grok-4.7` | **Ampliación del 2026-10-01, confirmada por Antonio ese día.** Mismo precio y "misma velocidad" que 4.6 según xAI; AA le mide un TTFT de **30 a 79s según la captura** (la mediana del leaderboard es ~4s) y yo medí 67.5s en una extracción que los rápidos hacen en 17s. Retiene 30 días. La familia Grok sigue fuera del ruteo |

**Con qué se cubren sus casos:** el volumen bruto que habría ido a muse-spark va a
`deepseek-v4.1-flash` (26,000 req/5h, 0 días de retención) y a `glm-5.3-flash`; el asiento
quirúrgico que habría ido a grok va a `codex:gpt-6.1-sol` o `glm-5.3`.

**Si alguna vez quieres saltarte el veto** (una prueba puntual, material 100% público): el helper
lo permite con `CHEAP_FANOUT_ALLOW_VETOED=1` en esa invocación. No lo pongas en tu perfil.

## Modelos gratuitos (limited time) — cuáles sí y cuáles no

Hay dos cosas distintas y se confunden: **gemelos free** (`opencode/<id>-free`, el mismo modelo
gratis) y **modelos gratuitos por derecho propio**. El 2026-10-01 la doc de Zen avisa de varios:
*"During its free period, collected data may be used to improve the model"*. Probados con
`opencode run` ese día:

| Ruta | ¿Responde? | ¿Entrena con tus prompts? | Veredicto |
|---|---|---|---|
| `longcat-2.5-preview-free` (Go) | ✅ | OpenCode: no, 0 días (pero ver discrepancia LongCat) | **Sí**, material no sensible |
| `space-bunny-free` (Go) | ✅ | "Its provider follows a zero-retention policy and does not use your data for model training" | **Sí**; modelo "stealth" sin índice AA, 84/84 en el benchmark, 22s |
| `opencode/mimo-v2.6-flash-free` | ✅ | **Puede** ("collected data may be used") | No para material del cliente |
| `opencode/big-pickle`, `ling-3.0-flash-fin-free` | ✅ / sin probar | **Puede** | No para material del cliente |
| `opencode/nemotron-3-ultra-free`, `nemotron-3.5-lightning-free` | sin probar | NVIDIA: "Trial use only — do not submit personal or confidential data" | No |
| `opencode/mimo-v2.5-free`, `hy3-free`, `deepseek-v4-flash-free`, `minimax-m3-free`, `longcat-2.0-free` | ❌ `UnknownError` | — | **Muertos**: antes eran los gemelos de rescate |

**Consecuencia para el helper:** su rescate automático por cuota mandaba el job al gemelo free del
mismo modelo, y esos gemelos entrenan. Es el mismo motivo por el que `muse-spark` está vetado, así
que **el rescate quedó apagado** (`SAFE_FREE_TWINS` vacío en `bin/cheap-fanout`). Sin gemelo seguro
el job queda en `.status=77` y decides tú; los dos gratuitos buenos se eligen a mano. Override solo
con material público: `CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1`.

## Cuota Go: límites por modelo (cambió el 2026-10-01)

Hasta el 2026-08-28 el plan tenía un pozo global (12 USD/5h, 30 USD/semana, 60 USD/mes) **y** un tope por
modelo. **La doc de hoy ya no menciona el pozo global**: define todo por modelo.

> *"Each model has the following usage limits: 5-hour — 20% of the monthly limit; weekly — 50%; and
> monthly — 100%."* — `opencode.ai/docs/go`

Cada modelo trae un **límite mensual** (columna `límite` del catálogo: 60, 30 o 15 USD en el plan
Go). Un modelo de 60 permite 12 USD/5h, 30 USD/semana y 60 USD/mes (los números que antes eran "el
pozo global"); uno de 15 permite 3 USD/5h, 7.50 USD/semana y 15 USD/mes. La doc lo explica en *"Why
some models have lower usage"*: donde hubo descuento con el proveedor el límite es 60; donde no
(modelo nuevo o precio público ya rebajado) baja a 30 o 15.

Hay además un **plan Go Plus de 40 USD/mes** con otros límites por modelo (por ejemplo
`mimo-v2.6-flash` 120, `glm-5.3-flash` 180, `kimi-k3` 60). Antonio está en Go y gasta ~3 de 60: no
lo necesita.

**Consecuencia operativa:** agotar un modelo no agota a los demás; **cambiar de modelo siempre
consigue presupuesto**. Lo que no puedes saber desde el helper es *cuál* modelo cambiar: eso es una
decisión de calidad y es tuya.

```bash
~/.claude/skills/cheap-fanout/bin/go-budget      # por modelo, en sus tres ventanas
GO_PLUS=1 ~/.claude/skills/cheap-fanout/bin/go-budget   # contra los límites de Go Plus
```

- **Un modelo apretado o agotado** → cambia ESE job a otro modelo Go (el catálogo te dice a cuál
  según el caso), a un free sin entrenamiento, a `codex` o a `kimi-code-plan-cn/k3`.
- `go-budget` sigue mostrando una fila agregada "informativa" (suma de todos los modelos contra
  12/30/60). **Ya no es un límite documentado y no mueve el exit code**: si algún día resulta que
  el proveedor sí aplica un global, esa fila es la que lo mostraría.

**Lo que sí está automatizado:**

1. **Antes de un lote grande, mide.** `go-budget` lee la base local de opencode y te da el gasto
   por modelo contra sus tres ventanas. Exit code: `0` holgado · `1` apretado (≥80% en una ventana
   de algún modelo) · `2` el `--model` pedido agotó una de sus ventanas.
2. **Durante el lote, el helper detecta la cuota.** Al ver la firma `Provider rate limit exceeded`
   intenta el gemelo free del mismo modelo **solo si no entrena** (hoy ninguno: ver *Modelos
   gratuitos*). `--on-quota off` lo desactiva del todo.
3. **Si no hay gemelo seguro, el helper NO sustituye el modelo.** Deja el job en `.status=77`
   ("SIN CUOTA") y te lo reporta, para que decidas tú.

**Los cuatro presupuestos, independientes entre sí:**

| Puerta | En `jobs.tsv` | Presupuesto | Para qué |
|---|---|---|---|
| Go | `deepseek-v4.1-flash` | límite por modelo (60/30/15 USD, ventanas 20%/50%/100%) | el ancho, por default |
| Free | `longcat-2.5-preview-free`, `space-bunny-free` | gratis, "limited time" | el ancho sin entrenamiento cuando Go aprieta (a mano; no hay rescate automático) |
| ChatGPT | `codex:gpt-6.1-sol` / `codex:<m>` | ventana 5h + semanal de ChatGPT | casi-frontier, código, mecánico; **no** investigación web |
| Allegretto | `kimi-code-plan-cn/k3` | suscripción Moonshot (ventana 5h + cuota semanal, plan antiguo) | segundo pre-revisor y unidad con 1M de contexto o visión |

> **Ojo con "Use balance":** la consola de OpenCode tiene una opción que, al agotarse Go, sigue
> sirviendo requests cobrando a tu saldo Zen — o sea, **dinero real**. Si no la has activado a
> propósito, déjala apagada; el fallback bueno es un free sin entrenamiento, no el de pago.

## Codex CLI — segundo presupuesto (suscripción ChatGPT)

`codex exec` corre **no-interactivo con el login de ChatGPT** (sin API key). En `jobs.tsv` usa
`codex:<model>`; el helper lo lanza como `codex exec --skip-git-repo-check --ephemeral -s read-only
-o out_file` (y `-C <dir>` con `--dir`). Verificado el 2026-10-01 con codex-cli **0.159.3**.

- **Modelos con login ChatGPT y su cuota en Plus (mensajes/5h):** `gpt-6-astra` (II 53; 5-45; es el
  default de `~/.codex/config.toml`, o sea el más caro), `gpt-6.1-sol` (II 52; 15-160; exige Codex
  ≥ 0.159.1), `gpt-6-sol` (II 48; 15-150), `gpt-6-luna` (II 37; 350-3,000). GPT-5.5 sale de Codex el
  2026-10-14. **Pide siempre el modelo explícito**: `codex:gpt-6.1-sol`, `codex:gpt-6-luna`.
- **Para qué:** el asiento casi-frontier (`gpt-6.1-sol`) y código/mecánico cuando Go escasea
  (`gpt-6-luna`, que también está en Go con 4,230 req/5h y límite 15: codex no suma un modelo,
  suma **cuota** aparte; el ancho con Luna va por Go, `codex` es desborde). **Para qué NO:**
  investigación web (sin web search) — eso siempre a opencode. En jobs codex, `out_file` trae solo
  el mensaje final; la traza va a `out_file.log`.
- **Sandbox:** `read-only` por default; los jobs que **editan** usan
  `CHEAP_FANOUT_CODEX_SANDBOX=workspace-write` con `--dir` a un worktree aislado, y revisas el diff.
  En Ubuntu 24.04 el sandbox necesita el perfil AppArmor `bwrap-userns-restrict`: sin él, **ni
  `read-only` lee archivos** (`bwrap … Failed RTM_NEWADDR`). En esta máquina ya está cargado
  (2026-10-01). Procedimiento oficial, verificación de contención, reversión e historial de
  versiones: `reference/codex.md`.

## K3 y Kimi — vía Kimi For Coding (suscripción Allegretto, Moonshot directo)

> **La ruta cambió y rompió la vieja (2026-09/10).** El proveedor se llama ahora
> **`kimi-code-plan-cn`** (`api.kimi.com`, la misma suscripción): `kimi-for-coding/k3` daba
> `UnknownError` porque opencode 1.18.31 busca la credencial bajo el nombre nuevo, aunque la llave
> fuera válida. El helper traduce la ruta vieja y **en esta máquina la credencial ya está copiada
> bajo el nombre nuevo** (2026-10-01). En otra máquina: copia la entrada en `auth.json` o exporta
> `KIMI_API_KEY` solo para la sesión. Smoke: `opencode run -m kimi-code-plan-cn/k3 "Responde
> exactamente: PONG"`. Ids del proveedor (`k3` 1M, `k3-256k`, `kimi-for-coding` = K2.8 Preview,
> `kimi-for-coding-highspeed` = K2.7 Code a 3x de cuota), reglas del plan antiguo, velocidades
> medidas (K3 43.5s por Allegretto, 31.5s por Go; AA: 34 tokens/s) y por qué `--variant low` no
> sirve: `reference/kimi.md`.

- **Guardrails:** K3 NUNCA en el ancho · máx 1-2 unidades por fan-out · **ya no es el pre-revisor
  por default** (ver *Qué pre-revisa el lote*) ni el asiento casi-frontier (eso es
  `codex:gpt-6.1-sol`: II 52 contra 44) · puerta primaria `kimi-code-plan-cn/k3`, fallback
  `opencode-go/kimi-k3` (110 req/5h, límite 15 USD ⇒ ~490 req/mes; **más rápida** en mi prueba,
  pero gasta Go).
- **Guardrail de latencia (reforzado 2026-10-01):** si un job K3 tarda >5 min, mátalo. **Ya no se
  cae a ti**: se cae al siguiente pre-revisor rápido (`deepseek-v4.1-flash`) —que es justo lo que
  el usuario no quiere gastar en Anthropic—. El flujo NUNCA se bloquea por K3: veredicto
  imparseable o 429 → otro pre-revisor, y solo si ese también falla, revisión completa tuya.
- **Plantilla de pre-revisión** (sirve para cualquier pre-revisor; la línea de webfetch es clave —
  en el dry-run K3 verificó fuentes por iniciativa propia). **Modo por referencia:** el prompt NO
  lleva los contenidos, solo las RUTAS de los pares prompt→salida; el agente los abre con sus
  herramientas de archivo desde el cwd (los agentes de opencode sí leen archivos locales). La
  versión con todo concatenado es inutilizable en Windows con lotes medianos (~32 KB de argv). Dos
  mejoras del 2026-10-01: la sección `DISCREPANCIAS` (aquí fue lo que más valor dio) y **exigir
  explícitamente cita textual**, que `deepseek-v4.1-flash` pasó por alto y K3 no:

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
  inventadas o con fecha posterior a hoy?; (d) ¿qué quedó en NO_CUBIERTO? Puedes usar webfetch.
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
- **Cuatro presupuestos, misma disciplina:** Go (el ancho barato; cada modelo con su propio
  límite) · free (solo los que no entrenan, a mano) · ChatGPT/codex (casi-frontier y desborde) ·
  Allegretto (K3: segundo pre-revisor y unidades de 1M de contexto o visión). El orquestador
  alterna por job en el campo `model` y conserva el veredicto final.

## Reglas de oro (lecciones caras)

1. **Ningún output barato aterriza sin revisión.** Revisión = el subteniente pre-revisa el lote + TÚ haces
   spot-check (DUDOSO/FALLO, 1-2 OK al azar, todo alto impacto contra fuente primaria); un
   falso-OK muestreado invalida el veredicto del lote entero. La síntesis final la escribes TÚ
   (baratos, el subteniente y K3 son materia prima, no la respuesta). Para código, TÚ lees el diff y corres los
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
   Kimi se renombró y rompió la ruta de K3, y el índice de benchmark se reescaló. Nada de eso se
   avisa: se descubre releyendo.
   Hay además **DOS tablas de precios**. `opencode.ai/docs/go` = tu plan (10 USD/mes): sus precios no
   se te cobran, son la tarifa contable que consume los límites. `opencode.ai/docs/zen` =
   pay-as-you-go, dinero real. Pueden divergir mucho (el caso clásico era v4-pro, 4x más caro en
   Zen — al 2026-08-28 ya convergieron, así que ni siquiera el ejemplo aguanta). Esta tabla usa
   **Go**. Si un número te parece raro, revisa de cuál de las dos páginas viene antes de
   "corregirlo". *(Lección 2026-08-09: un borrador de este skill traía la cifra Zen de v4-pro en
   una tabla de ruteo Go — el número era real, el producto era el equivocado.)*
6. **Disciplina de tokens.** El orquestador solo en planear+revisar+síntesis final; el ancho, siempre barato.
7. **Mide la velocidad, no solo el precio.** Un modelo "barato por token" puede ser el caro por
   tarea: `mimo-v2.5` (0.14/0.28) tardó 50s en lo que `deepseek-v4.1-flash` (0.15/0.60) hace en
   17s, y un pre-revisor de índice alto tardó 17 minutos donde uno rápido tardó 2. Y **cuando un
   modelo se vuelve lento, el costo real es que su trabajo cae en el orquestador** (Anthropic):
   por eso la lentitud de K3 se atiende cambiando de modelo, no esperando.
8. **Un índice de benchmark solo se compara dentro de su versión.** El "57" de `glm-5.3-flash`
   era Artificial Analysis v4.1.1; en la v4.3.2 el mismo modelo marca 42. Cita siempre la versión
   y no copies cifras de un laboratorio sobre su propio modelo como si fueran de un tercero.
9. **Un texto que *menciona* un error no es ese error.** Un informe que citaba "database is
   locked" no era un choque de arranque: el detector del helper lo tomó por uno y reintentó tres
   veces un job sano (2026-10-01). Acota las firmas de error por forma y tamaño, no por la mera
   presencia de la frase.

## Troubleshooting

La tabla **síntoma → arreglo** (SQLite, timeouts, cuota, vetos, bots, codex, Kimi, precios
corruptos por `$N`) está en `reference/troubleshooting.md`: ábrela cuando un job falle. Los
`.status` del helper: `0` OK · `124`/`137` timeout · `77` sin cuota · `66` salida vacía · `64` prompt
> argv · `75` SQLite bloqueado tras reintentos; exit `2` del helper sin correr nada = modelo vetado
o `jobs.tsv` inválido.

# Catálogo y mediciones del pool Go (releído y re-medido el 2026-11-20)

> Material de referencia del skill `cheap-fanout`. Ábrelo cuando la tabla de ruteo por caso del
> `SKILL.md` no cubra un modelo o necesites el número exacto. Fuentes de verdad: las reglas del plan
> en `opencode.ai/docs/go`; precios, solicitudes estimadas y límites en `opencode.ai/console/go` y en
> el endpoint `https://opencode.ai/inference/go/v1/models` (la doc dejó de traer esa tabla). No las
> confundas con `/docs/zen`, que cotiza a pago por uso. Las cifras caducan: en quince días
> (2026-11-05 → 2026-11-20) cambió el esquema de cuota entero.

## Catálogo completo del pool Go (cuota → límite → precio → contexto → índice → velocidad → peso)

Solicitudes estimadas y límites de la consola y del endpoint del **2026-11-20** (plan Go de 10
USD/mes). **límite** = cuánto cubre la bolsa compartida si usas solo ese modelo; un dólar gastado en
él consume 1/límite de la bolsa mensual (ver *Cuota Go* en el SKILL.md). **II** = Artificial Analysis
Intelligence Index **v5.0.1** (releído el 2026-11-20; rango = niveles de esfuerzo, — = AA no lo
lista). **seg** = las dos corridas del 2026-11-20 de una extracción de 31 filas con cita desde un
archivo local (viernes 21:00 CDMX, 6 procesos `opencode` simultáneos); † = no se re-midió, dato del
2026-11-05 (otra extracción: comparable en orden, no en absoluto). Las 26 corridas de hoy dieron
31/31 salvo una de `claude-haiku-5-5` (30/31): la extracción no discrimina calidad, mide tiempo y
costo. **peso** = % de la bolsa mensual que gastó una extracción (costo que registra opencode ÷
límite).

| id | req/5h | límite | USD/1M in/out | ctx | II (v5.0.1) | seg | peso | Nota |
|----|-------:|:------:|---|:--:|:--:|:--:|:--:|------|
| `deepseek-v4.1-flash` | 43,300 | 100 | 0.15/0.60 | 1M | 29-33 | 14, 17 | 0.0045% | **DEFAULT del ancho y pre-revisor.** El más rápido y el que menos pesa. Texto+imagen. Caché 0.003. Doble precio en peak. ZDR pactado hasta 2026-11-30 |
| `hy4-flash-free` | diario | libre | gratis | 1M | — | 17, 19 | 0 | **Nuevo (2026-11-16). El gratuito bueno:** no entrena, 0 días. Texto+imagen. Pre-revisó 8/8 en 44s. Tope diario sin cifra publicada; "limited time" |
| `glm-5.3-flash` | 6,320 | 60 | 0.15/0.50 | 1M | 28 | 18, 20 | 0.008% | Segundo caballo de pago. Texto+imagen+video. Dio falsos OK como pre-revisor (2026-11-05) |
| `gpt-6-luna` | 4,230 | 15 | 0.10/0.50 | 1.05M | 21-28 | 12, 17 | 0.024% | Rápido; pre-revisó 8/8 en 39s. Retiene 30 días. PDF. Mismo modelo en Codex |
| `claude-haiku-5-5` | 3,850 | 15 | 0.10/0.50 | 1M | 25-36 | 15, 17 | 0.016-0.046% | Unidad difícil por default. PDF+imagen. Retiene 30 días. 0.10/0.50 hasta 100K de contexto, 0.50/2.50 después |
| `minimax-m3.1-flash` | 3,880 | 20 | 0.15/0.60 | 1M | 29 | 17, 24 | 0.027% | Rápido y exhaustivo como pre-revisor (52s, 8/8), pero pesa 6x DeepSeek. Texto+imagen+video |
| `hy3` | 4,300 | 60 | 0.14/0.58 | 256K | — | 24, 30 | 0.010% | Barato de peso, pero 256K de contexto y sin índice |
| `glm-5.3` | 6,600* | 500* | 1.40/4.40 | 1M | 23-32 | 34, 34 | 0.010%* | *Promoción hasta el **2026-11-22**; el 2026-11-05 eran 220 req/5h y límite 15 (peso 0.32%). Unidad difícil con material sensible (0 días) |
| `qwen3.8-flash` | 5,400 | 30 | 0.15/0.47 | 1M | — | 62, 64 | 0.025% | Se volvió lento (28s el 2026-11-05). AA solo lista "Qwen3.8-Flash-Next" (29) |
| `hy4` | 2,710 | 60 | 0.834/2.501 | 1M | 35 | 53, 81 | 0.066% | II 35 con límite 60, pero lento y errático. Texto+imagen |
| `mimo-v2.6-flash` | 30,100 | 60 | 0.14/0.28 | 1M | 27 | 77, 83 | 0.007% | El más barato por token; 5x más lento que DeepSeek. Omni (audio) |
| `qwen4-max` | 463 | 15 | 1.50/4.50 | 1M | 43 | 62 | 0.44% | **Nuevo (2026-11-16).** Semi-quirúrgico por Go: 0 días, texto+imagen+video; pre-revisó 8/8 en 98s (0.76% de la bolsa). Una sola corrida de extracción |
| `gemini-4-argon` | 566 | 30 | 2.00/10.00 | 1M | 50 | 68† | ~0.22% | Casi-frontier en Go: audio+video+imagen+PDF. **Retiene hasta 55 días** (antes 0). **Precio ×2 desde 2026-12-01** (4/20). Pre-revisó 8/8 en 103s (0.67%) |
| `kimi-k3.1-pro` | 147 | 15 | 2.00/10.00 | 1M | 46 | 35† | — | II más alto entre abiertos. Lento: venció a los 8 min como pre-revisor |
| `kimi-k3` | 98 | 15 | 3.00/15.00 | 1M | — | 22† | — | Asiento Kimi del consejo. El más caro por token con límite 15: ~0.45% de la bolsa solo por arrancar un job |
| `longcat-2.5-free` | 100/día | libre | gratis | 1M | — | 47 | 0 | **Nuevo.** Gratis, 0 días según la doc, **alojado en China**; texto+imagen. Ver discrepancia LongCat en SKILL.md |
| `beam-free` | diario | libre | gratis | 1M | 18 | 25† | 0 | Gratis, no entrena, retiene 30 días; no disponible en varios países (México no está) |
| `gpt-5.6-luna` | 2,050 | 15 | 0.20/1.20 | 1.05M | — | 15† | — | Superado por `gpt-6-luna` |
| `qwen3.7-plus` | 4,310 | 60 | 0.40/1.60 | 1M | — | 41† | — | Sin índice |
| `kimi-k2.7-code` | 994 | 60 | 0.95/4.00 | 262K | — | 42† | — | Sin índice |
| `mimo-v2.6-pro` | 3,260 | 15 | 0.435/0.87 | 1M | 30 | 50† | — | Lento. Omni (audio) |
| `longcat-2.0` | 11,400 | 60 | 0.30/1.20 | 1M | — | 51† | — | Lento. Solo texto |
| `minimax-m3` | 3,210 | 60 | 0.30/1.20 | 1M | 19 | 38† | — | Errático (14-63s) |
| `deepseek-v4-pro` | 1,040 | 15 | 0.66/1.98 | 1M | 23 | 41† | — | II 23. Fuera del ruteo |
| `step-5-preview` | 426 | 15 | 1.00/2.70 | 1M | 29 | — | — | Flaky el 2026-11-05 (dos corridas, dos fallos); sin re-medir |
| `hy4-preview` | 1,350 | 30 | 0.834/2.501 | 1M | — | 86† | — | Errático. No lo rutees |
| `qwen3.8-max` | 162 | 15 | 2.00/6.00 | 1M | 34 | 59† | — | Dominado por `qwen4-max` (II 43, más barato, 3x solicitudes) |
| ~~`glm-5.2`~~ | 792 | 60 | 1.40/4.40 | — | — | — | — | 💀 `UnknownError` el 2026-11-20: salió del endpoint aunque la consola y la tabla de privacidad aún lo listan |
| ~~`iceman-contributor-free`~~ | — | libre | gratis | 262K | — | — | — | 🚫 **VETADO** (2026-11-05): ENTRENA con tus prompts (no ZDR); además el workspace lo bloquea |
| ~~`grok-4.7`~~ | 169 | 15 | 2.00/6.00 | 500K | 31-35 | — | — | 🚫 **VETADO** (ver SKILL.md). Retiene 30 días |
| ~~`muse-spark-1.3-contributor`~~ | 45,300 | 60 | 0.10/0.20 | 1M | — | — | — | 🚫 **VETADO** — entrena con tus datos |
| ~~`muse-spark-1.2-contributor`~~ | 45,300 | 60 | 0.10/0.20 | 1M | — | — | — | 🚫 **VETADO** — entrena con tus datos |

**Notas del catálogo:**
- **El endpoint sirve 31 ids** (2026-11-20). Nuevos desde el 2026-11-05: `qwen4-max`,
  `hy4-flash-free`, `longcat-2.5-free`. Salieron: `glm-5.2`. Trae por modelo el límite de cada plan
  (`go.monthly_usage`: `go`, `go-plus`, `go-teams`), si entrena (`go.training`), si es ZDR (`go.zdr`),
  modalidades, niveles de esfuerzo y multiplicadores de precio (`cost.multipliers`: el peak de
  DeepSeek y el alza de Argon del 2026-12-01). `go-budget` lee de ahí los límites.
- **Responden error hoy:** `glm-5.2` y `opencode/glm-5.3-flash-free` (PONG del 2026-11-20). Zen marca
  retirados `GLM-5.3-Flash Free` (2026-11-18) y `MiniMax M3.1 Flash Free` (2026-11-17). Del
  2026-11-05: `deepseek-v4-flash`, `deepseek-v4-flash-vision-exp`, `kimi-k2.6`, `minimax-m2.7`,
  `mimo-v2.5*`, `longcat-2.5-preview-free`, `space-bunny-free`, `step-5-preview-free`. Desde el
  2026-08-28 ya no estaban: `glm-5.1`, `minimax-m2.5`, `qwen3.7-max`, `qwen3.6-plus`, `grok-4.5`.
- **Cambios de cuota estimada desde el 2026-11-05:** `kimi-k3` 110 → 98 req/5h, `gemini-4-argon`
  440 → 566, `glm-5.3` 220 → 6,600 (promoción), `kimi-k2.7-code` 1,350 → 994, `glm-5.2` 880 → 792.
- Kimi directo (`kimi-code-plan-cn/*`): pausado por Antonio desde el 2026-11-05; no se re-probó.
- **AA v5.0.1, tope del leaderboard el 2026-11-20** (esfuerzo máx.): Claude Fable 5.2 **65** · GPT-6.2
  Astra **62** · Gemini 4 Neon 61 · Gemini 4 Carbon 60 · Claude Opus 5.5 59 · GPT-6.2 Sol **57** ·
  Claude Sonnet 5.5 55 · Gemini 4 Hydrogen 54 · GPT-6.1 Terra 51 · Gemini 4 Argon 50 · Kimi K3.1 Pro
  46 · Qwen4 Max **43** · Claude Haiku 5.5 36 · Hy4 35 · Grok 4.7 35 · DeepSeek V4.1 Flash 33 ·
  GLM-5.3 32. De esos, a tu alcance sin pagar por token: Fable/Opus/Sonnet (plan Max), los GPT por
  Codex (ChatGPT) y Argon, K3.1 Pro, Qwen4 Max, Haiku, Hy4, DeepSeek y GLM por Go. Los Gemini 4
  Neon, Carbon e Hydrogen no están en Go.
- Faltan en AA v5: `kimi-k3`, `hy4-flash-free`, `longcat-2.0`, `longcat-2.5-free`, `hy3`,
  `hy4-preview`, `kimi-k2.7-code`, `qwen3.7-plus`, `qwen3.8-flash`. Que no tengan índice no los
  descalifica.
- Modalidades según el endpoint: PDF ("application") solo `gpt-6-luna`, `gpt-5.6-luna`,
  `claude-haiku-5-5`, `gemini-4-argon`, `grok-4.7` y los `muse-spark`; audio solo `gemini-4-argon`,
  `mimo-v2.6-*` y `muse-spark`.

> **Precio ≠ cuota ≠ límite ≠ velocidad.** Son cuatro cosas. El ancho va a los de límite alto y buena
> velocidad (`deepseek-v4.1-flash`, `glm-5.3-flash`) y a los gratuitos que no entrenan
> (`hy4-flash-free`, `opencode/deepseek-v4.1-flash-free`); los de <600 req/5h (`qwen4-max`,
> `gemini-4-argon`, `qwen3.8-max`, `kimi-k3.1-pro`, `kimi-k3`) son 1-2 unidades quirúrgicas por
> sesión, nunca el ancho.

## Pre-revisión — lote de 8 unidades con fallas sembradas, medido el 2026-11-20

Unidades: 8 salidas de la extracción de arriba (31 filas × solicitudes y límite del plan Go, con
cita), por referencia y con la fuente a la mano. Fallas sembradas por mí: **U01** y **U08** limpias;
**U02** un número contra su propia cita (147 → 174); **U03** dos valores de la columna Go Plus dados
como Go, con cita textual real; **U04** dos filas intercambiadas junto con sus citas (4,300 ↔ 4,310);
**U05** dos filas omitidas con `===FIN===` presente; **U06** una fila inventada (`Qwen4 Flash`) con
cita fabricada; **U07** truncada a media fila. Nueve pre-revisores en paralelo:

| Pre-revisor | Tiempo | Unidades (8) | Costo (% de la bolsa de Go) | Gasta de |
|---|--:|:--:|:--:|---|
| `codex:gpt-6.1-terra` | **17s** | 8/8 | — | ChatGPT |
| `gpt-6-luna` | 39s | 8/8 | ~0.011 USD (0.07%) | Go, límite 15 |
| `hy4-flash-free` | 44s | 8/8 (con conteos de filas imprecisos en las razones) | 0 | gratis |
| `codex:gpt-6.2-astra` | 48s | 8/8 | — | ChatGPT (6-50 msgs/5h) |
| `minimax-m3.1-flash` | 52s | 8/8 | ~0.018 USD (0.09%) | Go, límite 20 |
| `codex:gpt-6.2-sol` | 61s | 8/8 | — | ChatGPT (17-180 msgs/5h) |
| `deepseek-v4.1-flash` | 91s | 8/8 | ~0.017 USD (0.02%) | Go, límite 100 |
| `qwen4-max` | 98s | 8/8 | ~0.11 USD (0.76%) | Go, límite 15 |
| `gemini-4-argon` | 103s | 8/8 | ~0.20 USD (0.67%) | Go, límite 30 |

Ninguna falsa alarma en las dos limpias y ninguna falla sin detectar: **otra vez el lote no
discrimina calidad**, aun con fallas que exigían abrir la fuente (U03, U04, U06). Lo que sí separa
es tiempo y costo: Qwen4 Max y Argon cuestan 40 veces lo que DeepSeek por el mismo veredicto.
Decisión: default `deepseek-v4.1-flash` (cuatro lotes sin falsos OK); gratis, `hy4-flash-free`;
segundo en alto impacto `codex:gpt-6.1-terra`; `codex:gpt-6.2-sol` si es muy alto y
`codex:gpt-6.2-astra` si es crítico; con material sensible `qwen4-max` o `hy4-flash-free` (Argon
perdió los 0 días de retención). Para discriminar de verdad hace falta un lote con fallas
**semánticas** (conclusión que no se sigue de la cita, causa equivocada), no de tabla.

## Histórico — catálogo y mediciones del 2026-11-05 / 2026-11-06

Los límites de entonces se leían como carriles independientes por modelo; desde el 2026-11-20 son
pesos de una bolsa compartida. Las mediciones de abajo se conservan tal cual.

## `deepseek-v4.1-flash` el 2026-11-05: latencia bimodal y saturación

La extracción de 6K tokens (la misma que el 2026-10-01 hacía en 17s), 7 corridas de las rondas 1-2: **21, 24, 25s**
(las rápidas) y **117s, 122s**, un **timeout a los 300s** con salida vacía y una corrida que maté a
los 3 min sin respuesta. En la prueba web (leer `docs/go` con `webfetch` y devolver JSON con citas):
una corrida de **216s** correcta (9/9) y otra que murió con
`Upstream request failed: [prefill_cap_refused] the cell is at capacity; retry shortly (after 5 s)`.
En la pre-revisión de 5 unidades respondió bien en 134s. **Repetición ~1 h después** (21:33-21:39
UTC, el modelo solo, 3 extracciones): `Error: Upstream request failed: [overloaded] the server is
overloaded; retry shortly` a los 17s, una corrida correcta de **70s** y un **timeout a los 300s**.
Total: 8 de 13 corridas de ≥117s, vencidas o fallidas (solo 3 respondieron en ≤25s), con el PONG sano
(11-17s), fuera de las horas peak (20:45-21:40 UTC, jueves) y con otros modelos sanos al mismo
tiempo ⇒ saturación del proveedor, no del equipo. Un PONG por el helper con opencode ya en 1.19.5
(más de una hora después) también dio `[overloaded]`: no es cosa de la versión del CLI. Un job `124` en
el helper puede ser esto.

**Re-medido el 2026-11-06** (viernes 19:08-19:20 UTC, off-peak): misma extracción contra un
fragmento de 11 KB de la doc de Go (10 modelos × precio, límite y req/5h, con cita). Ronda 1, 6
DeepSeek + 3 minimax simultáneos: DeepSeek **29, 35, 36, 48, 54, 55s**, minimax 41, 76, 76s. Ronda 2,
6 DeepSeek solos: **19, 25, 26, 30, 34, 43s**. Las 15 salidas, 10/10 correctas. Ningún
`[overloaded]` ni `[prefill_cap_refused]`. Le devolví el puesto de caballo del ancho; el helper ahora
reintenta esas dos firmas (`.status=76` si persisten). Evidencia de una tarde: si vuelve a saturarse,
el respaldo es `minimax-m3.1-flash`.

## Pre-revisión — lote de 5 unidades con fallas sembradas, medido el 2026-11-06

Unidades: 5 copias de una extracción correcta (10 modelos × precio, límite, req/5h, con cita), con
fallas sembradas por mí: **U01** limpia; **U02** dos números alterados contra su propia cita (límite
de Kimi K3 15→30, output de Qwen3.8 Flash 0.47→0.74); **U03** truncada a media fila y sin `===FIN===`;
**U04** dos filas omitidas sin declararlo; **U05** Argon a precio de lista (el prompt pedía el de
descuento) y dígitos transpuestos (3,850→3,580). Siete pre-revisores en paralelo, plazo 10m:

| Pre-revisor | Tiempo | Fallas (7) | U01 limpia | Gasta de |
|---|--:|:--:|:--:|---|
| `codex:gpt-6.1-terra` | **30s** | 7/7 | FALLO (exige cita a la columna de solicitudes) | ChatGPT |
| `kimi-k3` | 31s | 7/7 | OK | Go, límite 15 (0.19 USD = 1.3% de su mes) |
| `codex:gpt-6-luna` | 72s | 7/7 | DUDOSO (ídem) | ChatGPT |
| `codex:gpt-6.1-sol` | 77s | 7/7 | DUDOSO (ídem) | ChatGPT |
| `minimax-m3.1-flash` | 83s | 7/7 | OK (verificó cada cita como subcadena literal) | Go, límite 20 |
| `gemini-4-argon` | 95s | 7/7 | OK | Go, límite 30 (0.14 USD) |
| `deepseek-v4.1-flash` | 100s | 7/7 | OK | Go, límite 100 |

El lote **no discrimina calidad** (todos 7/7); lo de U01 es lectura literal de la plantilla ("¿CADA
número trae cita?"), no error. Decisión: pre-revisor `deepseek-v4.1-flash`; segundo en alto impacto
`codex:gpt-6.1-terra` (sale de Go y es el más rápido; II 42-51 contra 21-28 de Luna); `codex:gpt-6.1-sol`
si el impacto es muy alto; `gemini-4-argon` con material sensible. K3 deja el puesto por costo.

## Pre-revisión — lote de 5 unidades, medido el 2026-11-05

Unidades reales de esta actualización, por referencia, 7 pre-revisores en paralelo (plantilla del
SKILL.md con (e) "¿truncada?" añadido). Fallas del lote, conocidas o verificadas por mí:
**U01** (`deepseek-v4.1-flash`, changelog) truncada por timeout con solo trazas; **U02** (`glm-5.3-flash`)
con 3 citas reales atribuidas a la versión equivocada (`v2.2.1` en vez de `v2.2.3`, `v2.1.0` por
`v2.2.0`, `v1.19.2` por `v2.1.3`) y un bullet corrupto (`no hay这笔`); **U04** (réplica B de la
extracción de la doc de Zen) omitía los ids exactos de modelo que su prompt exigía, sin declararlo.

| Pre-revisor | Tiempo | Formato | U01 | U02 | U04 (ids omitidos) |
|---|--:|:--:|:--:|:--:|:--:|
| `gpt-6-luna` | **86s** | ✅ | FALLO ✅ | FALLO (exagerado, ✅) | DUDOSO ✅ |
| `deepseek-v4.1-flash` | 134s | ✅ | FALLO ✅ | DUDOSO ✅ | DUDOSO ✅ |
| `minimax-m3.1-flash` | **163s** | ✅ | FALLO ✅ | DUDOSO ✅ (3 errores + bullet corrupto) | DUDOSO ✅ |
| `kimi-k3` (Go) | 196s | ✅ | FALLO ✅ | DUDOSO ✅ (2 errores) | DUDOSO ✅ |
| `claude-haiku-5-5` | 203s | ✅ | FALLO ✅ | DUDOSO ✅ (3 errores) | **OK ❌** |
| `glm-5.3-flash` | 215s | ✅ | FALLO ✅ | **OK ❌** | **OK ❌** |
| `kimi-k3.1-pro` | venció a 480s | sin veredicto | — | — | — |

`minimax-m3.1-flash` fue el más exhaustivo (verificó una por una las 100 filas de precios y 165 pares
nombre→id contra la fuente y encontró los tres errores de versión y el bullet corrupto); `gpt-6-luna`
el más rápido pero menos profundo (4 KB de salida; marcó U05 como DUDOSO por omitir condiciones del
campo `cost`, hallazgo menor). **Es un lote chico:** evidencia delgada. Repite con otro antes de
depender de ello.

## Prueba web con cita (2026-11-05)

Leer `https://opencode.ai/docs/go` con `webfetch` y devolver un JSON con 9 valores (límites, precios,
fechas) más su cita: `minimax-m3.1-flash` 27s/11s, `claude-haiku-5-5` 18s/19s, `glm-5.3-flash` 22s/22s,
`gpt-6-luna` 28s/22s (todas 9/9 con las fechas del 30 de noviembre de 2026 correctas;
`claude-haiku-5-5` devolvió solo 3 citas en una de las dos corridas, los demás 14) y
`deepseek-v4.1-flash` 216s correcta / falla de capacidad.

### Primer lote — 19 unidades, medido el 2026-10-01

K3 dejó de ser el subteniente por default ese día: sobre las **mismas 19 unidades** (por referencia) los
candidatos tardaron:

"Problemas reales" del lote, verificados por mí: **U04** (una réplica se contradice con su propia
cita sobre los niveles de esfuerzo `max`) y **U19** (un informe con **0 de 31** números con cita
textual). Además **U15**: dos réplicas dieron cifras distintas de AA para Grok 4.7 y es una
discrepancia legítima de marcar, pero **no era un error de la réplica**: el leaderboard de AA es
dato vivo y su TTFT se movió entre capturas (Grok 4.7 xhigh: 78.69s → 42.40s en ~10 minutos; los
índices no se movieron).

| Pre-revisor | Tiempo | Unidades | ¿Marcó U04 / U19 / U15? |
|---|---|:--:|---|
| `deepseek-v4.1-flash` | **141s** | 19/19 | ✅ / ❌ (dio OK a un informe sin citas) / ✅ pero lo declaró FALLO (exagerado). 13 discrepancias cruzadas |
| `kimi-code-plan-cn/k3` (esfuerzo default) | 271s | 19/19 | **✅ / ✅ / ✅**. 6 discrepancias cruzadas |
| `kimi-code-plan-cn/k3 --variant low` | 349s | 19/19 | ❌ / ❌ / ❌, y volcó 300 KB de trazas. **Bajar el esfuerzo no arregla a K3** |
| `glm-5.3-flash` | 367s | **15/19** (no separó réplicas) | — / ❌ (dio OK al informe sin citas) / — |
| `kimi-code-plan-cn/kimi-for-coding` (K2.8 Preview) | 584s | no siguió el formato | ❌ / ❌ / ✅ |
| `glm-5.3` | 802s | **15/19** (no separó réplicas) | — / ✅ / — |
| `mimo-v2.6-pro` | 1,009s (17 min) | 19/19 | ❌ / ❌ / ✅ |

## Historia: las dos señales de que K3 estaba lento (2026-10-01)

- **AA lo mide en 34 tokens/s** y 79s por respuesta del Index; `glm-5.3-flash` 45 t/s y 59s,
  `deepseek-v4.1-flash` 209 t/s y 13s. Su TTFT (4.5s) está bien: lo lento es producir.
- **Mi extracción chica**: 43.5s por Allegretto y 31.5s por la puerta Go (`opencode-go/kimi-k3`),
  contra 17s de los rápidos. La diferencia de 12s entre puertas fue consistente en 2 corridas.

La causa más probable es esfuerzo de razonamiento + 34 t/s, no congestión (el endpoint respondió
HTTP 200 directo). Detalle y alternativas dentro de Kimi en `reference/kimi.md`.

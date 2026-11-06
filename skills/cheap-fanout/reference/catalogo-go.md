# Catálogo y mediciones del pool Go (releído 2026-11-05; límites reconfirmados y DeepSeek re-medido el 2026-11-06)

> Material de referencia del skill `cheap-fanout`. Ábrelo cuando la tabla de ruteo por caso del
> `SKILL.md` no cubra un modelo o necesites el número exacto. Fuente de verdad: `opencode.ai/docs/go`
> (no la confundas con `/docs/zen`, hoy la página *Models* de la consola, que cotiza a pago por uso).
> Las cifras caducan: el 2026-10-01 → 2026-11-05 cambió casi todo.

## Catálogo completo del pool Go (cuota → límite → precio → contexto → índice → velocidad)

Cuotas, límites y precios de `opencode.ai/docs/go` del **2026-11-05** (plan Go de 10 USD/mes; Go Plus
de 40 y Go Teams de 20 por miembro los suben, ver *Cuota Go* en el SKILL.md). Contextos del endpoint
público `https://opencode.ai/inference/go/v1/models`. **II** = Artificial Analysis Intelligence Index
**v5.0.1**, leído el 2026-11-05 en el HTML del leaderboard; AA publica un valor **por nivel de
esfuerzo**, así que va como rango (— = AA no lo lista; el índice se reescaló: nada de lo citado antes
del 2026-11-05 es comparable). **seg** = mediana (mín-máx) de la extracción de ~6K tokens medida por mí
el 2026-11-05, 5 corridas en dos rondas con 6-9 procesos `opencode` simultáneos (el orden es fiable,
los absolutos se inflan unos segundos); `t.o.` = venció a los 300s. Todas las corridas exitosas dieron
84/84 salvo una de `claude-haiku-5-5` (83) y una de `hy3` (78): la extracción no discrimina calidad,
solo mide tiempo y confirma que ninguno falla.

| id | req/5h | límite USD/mes | USD/1M in/out | ctx | II (v5.0.1) | seg | Nota |
|----|-------:|:----------:|---|:--:|:--:|:--:|------|
| `minimax-m3.1-flash` | 3,880 | 20 | 0.15/0.60 | 1M | 29 | 13 (10-21) | **Respaldo del ancho** (fue default del 2026-11-05 al 11-06). 41-76s el 2026-11-06 en la misma ronda que DeepSeek. Límite 20: pesa ~10x más por job que DeepSeek. Nuevo (2026-10-19). Texto+imagen+video, salida hasta 512K. Pre-revisor por default |
| `glm-5.3-flash` | 6,320 | 60 | 0.15/0.50 | 1M | 28 | 20 (17-25) | Segundo caballo; ya no es la "unidad difícil" (II 28 en v5). Texto+imagen+video. Dio falsos OK como pre-revisor |
| `gpt-6-luna` | 4,230 | 15 | 0.10/0.50 | 1.1M | 21-28 | 17 (15-18) | Pre-revisor rápido (86s). Retiene 30 días. PDF. Mismo modelo en Codex |
| `claude-haiku-5-5` | 3,850 | 15 | 0.10/0.50 | 1M | 25-36 | 18 (16-20) | **Nuevo.** Unidad difícil por default. PDF+imagen, 1M ctx. Retiene 30 días (Anthropic). 0.10/0.50 hasta 100K, 0.50/2.50 después |
| `deepseek-v4.1-flash` | 43,330 | 100 | 0.15/0.60 | 1M | 29-33 | 19-55 (2026-11-06; 12/12) | **DEFAULT del ancho y pre-revisor** desde el 2026-11-06. El 2026-11-05 estuvo saturado: 21-25 / 117-122 / t.o. (ver abajo). Texto+imagen. Caché 0.003. Límite subió de 60 a 100 el 2026-10-30. ZDR pactado hasta 2026-11-30 |
| `kimi-k3` | 110 | 15 | 3.00/15.00 | 1M | — | 22 (15-24) | Asiento Kimi del consejo. **Ya no pre-revisa** (2026-11-06): el más caro por token con el límite más bajo; un día de uso el 2026-11-05 lo llevó a ~40% de su semana. AA v5 ya no lo lista |
| `beam-free` | ilimitado | libre | gratis | 1M | 18 | 25 (16-28) | **Nuevo.** Gratis, no entrena, retiene 30 días; no disponible en varios países (México no está) |
| `qwen3.8-flash` | 5,400 | 30 | 0.15/0.47 | 1M | — | 28 (23-30) | 27s estables. AA no lo lista (solo "Qwen3.8-Flash-Next") |
| `glm-5.3` | 220 | 15 | 1.40/4.40 | 1M | 23-32 | 26 (23-30) | Unidad difícil con material sensible (0 días); 220 req/5h |
| `gpt-5.6-luna` | 2,050 | 15 | 0.20/1.20 | 1.1M | — | 15 (14-16) | Superado por `gpt-6-luna` (mismo precio por token ×2, la mitad de cuota) |
| `glm-5.2` | 880 | 60 | 1.40/4.40 | 1M | — | 32 (22-41) | Z.ai lo enruta a 5.3; sin razón para elegirlo |
| `hy3` | 4,300 | 60 | 0.14/0.58 | 256K | — | 32 (31-32) | Dominado. 256K de contexto; una corrida con 78/84 |
| `kimi-k3.1-pro` | 147 | 15 | 2.00/10.00 | 1M | 46 | 35 (30-38) | **Nuevo** (2026-10-23). II más alto entre abiertos. Lento: venció a los 8 min como pre-revisor |
| `hy4` | 2,710 | 60 | 0.834/2.501 | 1M | 35 | 48 (46-51) | **Nuevo** (2026-11-04). Texto+imagen. Lento (46-51s). Sin dato de costo en AA |
| `kimi-k2.7-code` | 1,350 | 60 | 0.95/4.00 | 262K | — | 42 (40-45) | 42s; sin índice |
| `qwen3.7-plus` | 4,300 | 60 | 0.40/1.60 | 1M | — | 41 (40-42) | 41s; sin índice |
| `mimo-v2.6-flash` | 30,100 | 60 | 0.14/0.28 | 1M | 27 | 46 (32-61) | El más barato por token (0.14/0.28); 3x más lento. Omni (audio) |
| `mimo-v2.6-pro` | 3,250 | 15 | 0.435/0.87 | 1M | 30 | 50 (34-66) | Bajó de II 46 a 30 en v5. Lento (34-66s). Omni (audio) |
| `longcat-2.0` | 11,400 | 60 | 0.30/1.20 | 1M | — | 51 (50-52) | Lento (50-52s). Ver discrepancia LongCat en SKILL.md |
| `minimax-m3` | 3,200 | 60 | 0.30/1.20 | 1M | 19 | 38 (14-63) | Vía `/v1/messages`. Errático (14-63s) |
| `deepseek-v4-pro` | 1,050 | 15 | 0.66/1.98 | 1M | 23 | 41 | II 23 (v5). Sale del ruteo |
| `step-5-preview` | 430 | 15 | 1.00/2.70 | 1M | 29 | — | **Nuevo.** Flaky: las dos corridas fallaron (una leyó una ruta inventada; otra dio "Endpoint is unavailable") |
| `hy4-preview` | 1,350 | 30 | 0.834/2.501 | 1M | — | 86 (39-133) | Errático: 39-133s. No lo rutees |
| `qwen3.8-max` | 160 | 15 | 2.00/6.00 | 1M | 34 | 59 (47-71) | Quirúrgico; 59s |
| `gemini-4-argon` | 440 | 30 | 2.00/10.00 | 1M | 50 | 68 (44-75) | **Nuevo.** Casi-frontier en Go: audio+video+imagen+PDF. 0 días de retención. **50% de descuento hasta 2026-11-30** (lista 4/20) |
| ~~`mimo-v2.5`~~ | 30,100 | 60 | 0.14/0.28 | — | — | — | 💀 `has been deprecated. Use mimo-v2.6-flash instead` — la doc aún lo lista |
| ~~`mimo-v2.5-pro`~~ | 3,250 | 15 | 0.435/0.87 | — | — | — | 💀 `has been deprecated. Use mimo-v2.6-pro instead` — la doc aún lo lista |
| ~~`iceman-contributor-free`~~ | ilimitado | libre | gratis | 262K | — | — | 🚫 **VETADO** (2026-11-05): ENTRENA con tus prompts (no ZDR); además el workspace lo bloquea |
| ~~`grok-4.7`~~ | 169 | 15 | 2.00/6.00 | 500K | 31-35 | — | 🚫 **VETADO** (ver SKILL.md). Retiene 30 días |
| ~~`muse-spark-1.3-contributor`~~ | 45,300 | 60 | 0.10/0.20 | 1M | — | — | 🚫 **VETADO** — entrena con tus datos |
| ~~`muse-spark-1.2-contributor`~~ | 45,300 | 60 | 0.10/0.20 | 1M | — | — | 🚫 **VETADO** — entrena con tus datos |

**Notas del catálogo:**
- **Salieron de la doc o responden error hoy** (PONG del 2026-11-05): `deepseek-v4-flash` y
  `deepseek-v4-flash-vision-exp` (`UnknownError`; Zen marca `V4 Flash` deprecado el 2026-10-26),
  `kimi-k2.6`, `minimax-m2.7`, `longcat-2.5-preview-free`, `space-bunny-free`, `step-5-preview-free`
  (`UnknownError`; models.dev aún los lista, el endpoint no). `mimo-v2.5` y `mimo-v2.5-pro`: error
  duro por deprecación aunque la tabla de la doc los conserva. Desde el 2026-08-28 ya no estaban:
  `glm-5.1`, `minimax-m2.5`, `qwen3.7-max`, `qwen3.6-plus`, `grok-4.5`.
- **El endpoint `/inference/go/v1/models` sirve 29 modelos**; la doc lista 31: la diferencia son los
  dos `mimo-v2.5*` deprecados. Es la lista autoritativa de lo servible; `models.dev` trae 38 ids con
  restos (`cat-jam-free`, `gemini-4-argon-contributor`, `minimax-m3.1-flash-free`, `space-bunny`,
  `step-5-preview-free`) y `opencode models` la mezcla.
- Kimi directo (`kimi-code-plan-cn/*`): las tres rutas responden *"Your current subscription does not
  have access to Kimi Code right now"* (suscripción pausada por Antonio). Dato de contexto del
  proveedor: `k3.1-pro` y `k3.1-pro-highspeed` ya existen ahí, 1M de contexto.
- Faltan en AA v5: `kimi-k3`, `longcat-2.0`, `glm-5.2`, `hy3`, `hy4-preview`, `kimi-k2.7-code`,
  `qwen3.7-plus`, `qwen3.8-flash`, `mimo-v2.5*`. Que no tengan índice no los descalifica.
- Modalidades según el endpoint: PDF ("application") solo `gpt-6-luna`, `gpt-5.6-luna`,
  `claude-haiku-5-5`, `gemini-4-argon` y los `muse-spark`; audio solo `gemini-4-argon`, `mimo-v2.6-*`
  y `muse-spark`. `glm-5.3-flash` **ya no lista PDF** (antes el skill decía texto+imagen+video+PDF).

> **Precio ≠ cuota ≠ límite ≠ velocidad.** Son cuatro cosas. El ancho va a los de cuota alta y buena
> velocidad (`deepseek-v4.1-flash`, `minimax-m3.1-flash`, `glm-5.3-flash`, `gpt-6-luna`); los de <500 req/5h (`glm-5.3`, `qwen3.8-max`, `kimi-k3`, `kimi-k3.1-pro`,
> `gemini-4-argon`) son 1-2 unidades quirúrgicas por sesión, nunca el ancho.

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

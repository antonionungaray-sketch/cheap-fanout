# Catálogo y mediciones del pool Go (releído 2026-10-01)

> Material de referencia del skill `cheap-fanout`, extraído del `SKILL.md` el 2026-10-01 para no
> cargarlo en cada invocación. Ábrelo cuando la tabla de ruteo por caso no cubra un modelo o necesites el número exacto. Fuente de verdad: `opencode.ai/docs/go` (no la confundas con `/docs/zen`). Las cifras caducan.

## Catálogo completo del pool Go (cuota → límite → precio → contexto → índice → velocidad)

Cuotas, límites y precios releídos en `opencode.ai/docs/go` el **2026-10-01** (plan Go de 10 USD/mes;
Go Plus de 40 USD/mes los sube, ver *Cuota Go* en el SKILL.md); contextos de `models.dev/api.json`; `II` de
Artificial Analysis v4.3.2 (— = AA no lo lista); `seg` medido por mí el 2026-10-01.

| id | req/5h | límite USD/mes | USD/1M in/out | ctx | II | seg | Nota |
|----|-------:|:----------:|---|:--:|:--:|:--:|------|
| `deepseek-v4.1-flash` | 26,000 | 60 | 0.15/0.60 · peak 0.30/1.20 | 1M | 39 | 17 | **DEFAULT del ancho.** Texto+imagen, 552B MoE, MIT. Caché 0.003. **Su ZDR está pactado solo hasta el 2026-10-31** (renovación mensual) |
| `glm-5.3-flash` | 6,320 | 60 | 0.15/0.50 | 1M | 42 | 17.5 | "Ox Alpha", 320B/18B, MIT; texto+imagen+video+PDF. Límite subió de 15 a 60. Unidad difícil **y** segundo caballo |
| `mimo-v2.6-flash` | 30,100 | 60 | 0.14/0.28 | 1M | 38 | 65 | Omni (audio). El más barato por token y de los más lentos. Sustituye a 2.5 |
| `mimo-v2.5` | 30,100 | 60 | 0.14/0.28 | 1M | — | 50 | **Xiaomi lo deprecó para el 2026-10-21.** Ex-default: migra |
| `longcat-2.0` | 11,400 | 60 | 0.30/1.20 | 1M | 19 | 30 | II más bajo del pool útil. Caché 0.006 |
| `deepseek-v4-flash` | 13,000 | 30 | 0.15/0.60 · peak 0.30/1.20 | 1M | 34 | 15 | DeepSeek lo retiró: "rutea a V4.1-Flash". Redundante; el mismo modelo con la mitad de límite |
| `qwen3.8-flash` | 5,400 | 30 | 0.15/0.47 | 1M | ~40* | 60 | *AA solo lista "Qwen3.8-Flash-Next" (II 40, 180B): no está confirmado que sea este id |
| `gpt-6-luna` | 4,230 | 15 | 0.10/0.50 · >272K 0.20/0.75 | 1.05M | 37 | 16.5 | **Nuevo.** Retiene datos 30 días. Mismo modelo en Codex: 350-3,000 mensajes/5h |
| `hy3` | 4,300 | 60 | 0.14/0.58 | 256K | 25 | 26 | Dominado por `deepseek-v4.1-flash`; sin recargo peak |
| `qwen3.7-plus` | 4,300 | 60 | 0.40/1.60 · >256K 1.20/4.80 | 1M | — | — | Tool-calling+MCP |
| `deepseek-v4-flash-vision-exp` | 6,500 | 15 | 0.15/0.60 · peak 0.30/1.20 | 1M | — | — | DeepSeek lo retiró; V4.1-Flash ya acepta imagen |
| `gpt-5.6-luna` | 2,050 | 15 | 0.20/1.20 · >272K 0.40/1.80 | 1.05M | 37 | — | Superado por `gpt-6-luna`: mismo II, la mitad de precio, el doble de cuota |
| `mimo-v2.6-pro` | 3,250 | 15 | 0.435/0.87 | 1M | 46 | 147 | II más alto entre abiertos (AA). 1.02T/42B. **Lento** |
| `mimo-v2.5-pro` | 3,250 | 15 | 0.435/0.87 | 1M | — | — | **Deprecado 2026-10-21** |
| `minimax-m3` | 3,200 | 60 | 0.30/1.20 | 1M | 29 | 55 | ~428B/23B; vía `/v1/messages` |
| `minimax-m2.7` | 3,400 | 60 | 0.30/1.20 | 200K | — | — | Gen previa de M3 |
| `kimi-k2.7-code` | 1,350 | 60 | 0.95/4.00 | 256K | — | — | Coding agentic multi-paso |
| `kimi-k2.6` | 1,150 | 60 | 0.95/4.00 | 256K | — | — | Gen previa de k2.7 |
| `hy4-preview` | 1,350 | 30 | 0.834/2.501 | 1M | — | 104-983 | **Ya responde**, pero la latencia es errática (dos extracciones: 104s y 983s). No lo rutees |
| `glm-5.3` | 220 | 15 | 1.40/4.40 | 1M | 45 | — | Mismo base que 5.2, todo el avance es post-training. Licencia propia, no MIT |
| `glm-5.2` | 880 | 60 | 1.40/4.40 | 1M | — | — | Z.ai lo enruta a 5.3. Sin razón para elegirlo |
| `deepseek-v4-pro` | 1,050 | 15 | 0.66/1.98 · peak 1.32/3.96 | 1M | 36 | — | DeepSeek lo "está retirando" (sus propias páginas se contradicen). V4.1-Flash lo supera |
| `qwen3.8-max` | 160 | 15 | 2.00/6.00 | 1M | 45 | — | 2.4T/95B abierto. Quirúrgico |
| `kimi-k3` | 110 | 15 | 3.00/15.00 | 1M | 44 | 31.5 | 2.8T/104B. 34 tokens/s (AA). **Preferir la puerta `kimi-code-plan-cn/k3`** si importa no gastar Go; es la más lenta (43.5s) |
| ~~`grok-4.7`~~ | 169 | 15 | 2.00/6.00 | 500K | 46 | 67.5 | 🚫 **Fuera del ruteo** — TTFT 30-79s (AA, varía) y retiene 30 días. Ver *Modelos vetados* en el SKILL.md |
| ~~`grok-4.6`~~ | 169 | 15 | 2.00/6.00 | 500K | 44 | 52 | 🚫 **VETADO** |
| ~~`muse-spark-1.3-contributor`~~ · ~~`muse-spark-1.2-contributor`~~ | 45,300 | 60 | 0.10/0.20 | 1M | 48 | — | 🚫 **VETADOS** — entrenan con tus datos y no son ZDR |
| `longcat-2.5-preview-free` | ilimitado | libre | gratis | 1M | — | 55 | Gratis "limited time". Ver *Modelos gratuitos* en el SKILL.md |
| `space-bunny-free` | ilimitado | libre | gratis | 1M | — | 22 | Gratis "limited time", modelo "stealth". Ver *Modelos gratuitos* en el SKILL.md |

**Notas del catálogo:**
- Salieron de la doc de Go desde el 2026-08-28: `glm-5.1`, `minimax-m2.5`, `qwen3.7-max`,
  `qwen3.6-plus` y `grok-4.5`. No los rutees.
- **`opencode models` sigue siendo una lista desfasada** que no es la autoridad. El 2026-10-01
  listaba bien casi todo, pero la única prueba real de que un modelo existe es
  `opencode run -m <ruta> "Responde exactamente: PONG"`; así se probaron los 17 modelos Go nuevos
  o dudosos de hoy.
- Faltan en AA: `mimo-v2.5`, `hy4-preview`, `longcat-2.5-preview`, `kimi-k2.7-code`, `glm-5.2`,
  `qwen3.7-plus`. Que no tengan índice no los descalifica, solo no se pueden comparar.

> **Precio ≠ cuota ≠ límite ≠ velocidad.** Son cuatro cosas. El ancho va a los de cuota alta
> **con límite 60** y buena velocidad (`deepseek-v4.1-flash`, `glm-5.3-flash`); los de <400 req/5h
> (`glm-5.3`, `qwen3.8-max`, `kimi-k3`) son 1-2 unidades quirúrgicas por sesión, nunca el ancho.

## Qué pre-revisa el lote — comparación medida el 2026-10-01

K3 dejó de ser el subteniente por default: sobre las **mismas 19 unidades** (por referencia) los
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

## Las dos señales de que K3 está lento (2026-10-01)

- **AA lo mide en 34 tokens/s** y 79s por respuesta del Index; `glm-5.3-flash` 45 t/s y 59s,
  `deepseek-v4.1-flash` 209 t/s y 13s. Su TTFT (4.5s) está bien: lo lento es producir.
- **Mi extracción chica**: 43.5s por Allegretto y 31.5s por la puerta Go (`opencode-go/kimi-k3`),
  contra 17s de los rápidos. La diferencia de 12s entre puertas fue consistente en 2 corridas.

La causa más probable es esfuerzo de razonamiento + 34 t/s, no congestión (el endpoint respondió
HTTP 200 directo). Detalle y alternativas dentro de Kimi en `reference/kimi.md`.

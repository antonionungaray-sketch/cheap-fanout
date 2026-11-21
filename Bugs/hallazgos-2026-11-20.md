# Hallazgos 2026-11-20 — bolsa compartida de Go, GPT-6.2 en Codex y caballos re-medidos

Relectura de fuentes, mediciones y cambios: Claude Fable 5.2. Todo medido en la máquina de Antonio
(Linux, opencode 1.19.6, codex-cli 0.167.0), viernes 2026-11-20 ~21:00 CDMX (sábado 03:00 UTC,
off-peak de DeepSeek).

## 1. Fuentes leídas

| Fuente | Cómo | Qué dio |
|---|---|---|
| `https://opencode.ai/inference/go/v1/models` | `curl` directo | 31 ids, precios, modalidades, `go.monthly_usage` por plan, `go.training`, `go.zdr`, `cost.multipliers` |
| `opencode.ai/docs/go` | Jina Reader | reglas de la bolsa, privacidad, notas de promociones. **Ya no trae la tabla de límites ni de precios** |
| `opencode.ai/console/go` | Jina Reader (página pública) | solicitudes estimadas por 5h y límite mensual por modelo (Go y Go Plus) |
| `opencode.ai/docs/zen` | Jina Reader | gratuitos de Zen, sus avisos de entrenamiento y la tabla de deprecaciones |
| `artificialanalysis.ai/leaderboards/models` | `curl` + tabla parseada con script | Intelligence Index v5.0.1 (solo la fila de esfuerzo máximo de cada modelo) |
| `developers.openai.com/codex/pricing` y `/models` | Jina Reader | cuota por modelo en Plus y créditos por token |
| `~/.codex/models_cache.json` | local | catálogo en caché de Codex (no lista los 6.2: no sirve de catálogo) |

## 2. La cuota de Go cambió de esquema

Texto de la doc (2026-11-20):

> "The paid models you use on Go share one allowance. On Go Teams, each member has their own
> allowance across models. The 5-hour limit is 20% of your monthly allowance. The window starts when
> you first use your allowance and lasts five hours. The weekly limit is 50% of your monthly
> allowance. It resets on Monday at 00:00 UTC. Your monthly allowance resets when a new paid period
> starts. Switching models draws from the same allowance. If you reach a limit, you can use a free
> model or turn on Extra Usage […]"
>
> "Each model's monthly limit shows how much usage your plan covers if you use only that model over
> the month. For example, $1.50 of usage on a model with a $15 limit uses 10% of your monthly
> allowance. So does $6 on a model with a $60 limit."

El 2026-11-05/06 la doc decía "Each model has the following usage limits" y los números de la consola
cuadraban con el modelo más cargado, no con la suma ponderada (ver `hallazgos-2026-11-06.md` §1:
ponderado daba 36% / 72% contra 20% / 40% observados). Hoy la doc describe exactamente la suma
ponderada. **No lo verifiqué contra la consola** (no tengo captura de hoy) **ni contra
`opencode.allowance`** (la lectura de la llave de la API la negó el filtro de permisos, igual que el
2026-11-06). Pendiente: comparar una vez la barra de la consola con `go-budget`.

Con el esquema nuevo, `go-budget` da para los 30 días corridos al 2026-11-20: 10.61 USD de tarifa
contable = **46% de la bolsa mensual** (16 puntos de `kimi-k3`, 9 de `minimax-m3.1-flash`, 6 de
`kimi-k3.1-pro`, 3.5 de `gemini-4-argon`; `deepseek-v4.1-flash`, con el mayor gasto en dólares después
de K3, aporta 2). Semana en curso: 10%.

## 3. Catálogo: qué entró, qué salió, qué cambió

- **Nuevos:** `qwen4-max` (2026-11-16; 1.50/4.50, límite 15, 463 req/5h, 0 días, texto+imagen+video),
  `hy4-flash-free` (2026-11-16; gratis, no entrena, 0 días, texto+imagen), `longcat-2.5-free`
  (2026-11-02; gratis, alojado en China, 100 solicitudes al día).
- **Salieron:** `glm-5.2` (`UnknownError`; la consola aún lo cuenta: "32 models").
  `opencode/glm-5.3-flash-free` (Zen: retirado el 2026-11-18) y `MiniMax M3.1 Flash Free`
  (2026-11-17).
- **`gemini-4-argon`:** retención de 0 a **55 días** ("Requests are retained for up to 55 days for
  abuse monitoring in accordance with Google's Gemini API Terms"); solicitudes 440 → 566; el endpoint
  trae `multipliers: [{when: {date: {gte: "2026-12-01"}}, factor: 2}]` (fin del 50% de descuento).
- **`glm-5.3`:** límite 500 en Go y 1,000 en Go Plus ("Higher usage limits apply through November 22,
  2026"); 6,600 req/5h. Antes 15 y 220.
- **Solicitudes estimadas:** `kimi-k3` 110 → 98; `kimi-k2.7-code` 1,350 → 994.
- **PONG del 2026-11-20:** responden `qwen4-max` (12s), `hy4-flash-free` por Go y por Zen (11s),
  `longcat-2.5-free` por Go y por Zen (13-15s), `opencode/deepseek-v4.1-flash-free` (9s),
  `codex:gpt-6.2-sol` (9s), `codex:gpt-6.2-astra` (8s). Fallan `opencode-go/glm-5.2`,
  `opencode/glm-5.3-flash-free` y `codex:gpt-6.2-terra` ("not supported when using Codex with a
  ChatGPT account").

## 4. Artificial Analysis v5.0.1 (misma versión que el 2026-11-05)

Fila de esfuerzo máximo de cada modelo: Claude Fable 5.2 **65** · GPT-6.2 Astra **62** · Gemini 4 Neon
61 · Gemini 4 Carbon 60 · Claude Opus 5.5 59 · GPT-6.2 Sol **57** · Claude Sonnet 5.5 55 · Gemini 4
Hydrogen 54 · GPT-6.1 Terra 51 · Gemini 4 Argon 50 · Kimi K3.1 Pro 46 · Qwen4 Max **43** · Claude Haiku
5.5 36 · Hy4 35 · Grok 4.7 35 · DeepSeek V4.1 Flash 33 · GLM-5.3 32 · MiMo-V2.6-Pro 30 ·
MiniMax-M3.1-Flash 29 · Step 5 Preview 29 · GPT-6 Luna 28 · GLM-5.3-Flash 28 · MiMo-V2.6-Flash 27 ·
DeepSeek V4 Pro 23 · MiniMax-M3 19 · Beam 1.0 18. No leí las filas de esfuerzos menores (la tabla las
trae colapsadas): los rangos que el skill cita para modelos ya conocidos vienen del 2026-11-05.

Codex en Plus (mensajes locales por 5h, OpenAI): GPT-6.2 Astra 6-50 · GPT-6.2 Sol 17-180 · GPT-6 Astra
5-45 · GPT-6.1 Sol 15-160 · GPT-6.1 Terra 35-285 · GPT-6 Sol 15-150 · GPT-6 Luna 350-3,000.

## 5. Medición del ancho

Tarea: abrir `fuente.md` (la tabla de límites de la consola, 3 KB, 31 filas) y devolver por fila
nombre, solicitudes Go, límite Go y dos citas textuales, con `===FIN===`. Calificación por script
contra la tabla. 26 corridas, 6 simultáneas, plazo 5m. Costo = lo que registra opencode.

| Modelo | Tiempos (s) | Correctas | USD por corrida | % de la bolsa por corrida |
|---|---|:--:|--:|--:|
| `deepseek-v4.1-flash` | 14, 17 | 31/31 ×2 | 0.0045 | 0.0045 |
| `gpt-6-luna` | 17, 12 | 31/31 ×2 | 0.0036 | 0.024 |
| `claude-haiku-5-5` | 15, 17 | 30/31, 31/31 | 0.0025-0.0069 | 0.016-0.046 |
| `hy4-flash-free` | 19, 17 | 31/31 ×2 | 0 | 0 |
| `opencode/deepseek-v4.1-flash-free` | 19, 9 | 31/31 ×2 | 0 | 0 |
| `minimax-m3.1-flash` | 24, 17 | 31/31 ×2 | 0.0054 | 0.027 |
| `glm-5.3-flash` | 20, 18 | 31/31 ×2 | 0.0050 | 0.008 |
| `hy3` | 30, 24 | 31/31 ×2 | 0.0058 | 0.010 |
| `glm-5.3` | 34, 34 | 31/31 ×2 | 0.048 | 0.010 (límite 500; 0.32 con límite 15) |
| `longcat-2.5-free` | 47 | 31/31 | 0 | 0 |
| `qwen4-max` | 62 | 31/31 | 0.067 | 0.44 |
| `qwen3.8-flash` | 64, 62 | 31/31 ×2 | 0.0074 | 0.025 |
| `hy4` | 53, 81 | 31/31 ×2 | 0.040 | 0.066 |
| `mimo-v2.6-flash` | 83, 77 | 31/31 ×2 | 0.0043 | 0.007 |

La tarea no discrimina calidad (todos aciertan); ordena por tiempo y por peso. Es una tarde y dos
corridas por modelo.

## 6. Medición de pre-revisores

8 unidades por referencia (2 limpias, 6 sembradas; detalle en `reference/catalogo-go.md`), plantilla
del SKILL.md con la fuente a la mano. Los 9 candidatos dieron el veredicto correcto en las 8.

| Pre-revisor | Tiempo | USD | % de la bolsa |
|---|--:|--:|--:|
| `codex:gpt-6.1-terra` | 17s | — | — |
| `gpt-6-luna` | 39s | ~0.011 | 0.07 |
| `hy4-flash-free` | 44s | 0 | 0 |
| `codex:gpt-6.2-astra` | 48s | — | — |
| `minimax-m3.1-flash` | 52s | ~0.018 | 0.09 |
| `codex:gpt-6.2-sol` | 61s | — | — |
| `deepseek-v4.1-flash` | 91s | ~0.017 | 0.02 |
| `qwen4-max` | 98s | ~0.11 | 0.76 |
| `gemini-4-argon` | 103s | ~0.20 | 0.67 |

`hy4-flash-free` acertó los veredictos pero se equivocó en detalles de sus razones (dijo "30 filas"
donde eran 29 y "fila 20" donde era la 18). Cuarto lote seguido que no separa a los buenos: hace
falta uno con fallas semánticas.

## 7. Decisiones

| Puesto | Antes (1.5.0) | Ahora (1.6.0) | Por qué |
|---|---|---|---|
| Ancho, default | `deepseek-v4.1-flash` | igual | el más rápido y el de menor peso |
| Ancho, respaldo | `minimax-m3.1-flash` | `hy4-flash-free` (gratis) · `glm-5.3-flash` | minimax pesa 6x; el gratuito no entrena |
| Unidad difícil | `claude-haiku-5-5` | igual (y `glm-5.3` mientras dure su promoción) | sin medición que lo mueva |
| Semi-quirúrgico Go | `kimi-k3.1-pro` | `qwen4-max` | 3 puntos menos, mitad de precio de salida, 3x solicitudes, no se cuelga |
| Casi-frontier | `codex:gpt-6.1-sol` | `codex:gpt-6.2-sol`; `codex:gpt-6.2-astra` para lo más duro | II 57 y 62 con más cuota que sus antecesores |
| Pre-revisor default | `deepseek-v4.1-flash` | igual; `hy4-flash-free` si se quiere gratis | cuatro lotes sin falsos OK |
| 2º pre-revisor | `codex:gpt-6.1-terra` · `codex:gpt-6.1-sol` | `codex:gpt-6.1-terra` · `codex:gpt-6.2-sol` · `codex:gpt-6.2-astra` | misma cuota ChatGPT, más índice |
| Pre-revisor, material sensible | `gemini-4-argon` | `qwen4-max` · `hy4-flash-free` | Argon retiene 55 días |
| Asiento GPT del consejo | `codex:gpt-6.1-sol` | `codex:gpt-6.2-sol` (Astra 6.2 como opción) | sin probar en un consejo real |

## 8. Pendientes

- Contrastar `go-budget` con la barra de la consola de Go (valida o tumba el esquema de bolsa).
- ~~Decidir si se habilita el rescate automático en `opencode/deepseek-v4.1-flash-free`.~~ **Resuelto
  el mismo 2026-11-20:** Antonio lo habilitó (1.6.1). Ver §9.
- 2026-11-23: `glm-5.3` deja la promoción; 2026-12-01: `gemini-4-argon` duplica precio y vence el
  acuerdo ZDR mensual de DeepSeek (releer la doc).
- Lote de pre-revisión con fallas semánticas, y probar `codex:gpt-6.2-astra` como asiento del consejo.

## 9. Rescate automático en el gemelo de DeepSeek (1.6.1, mismo día)

Antonio pidió habilitarlo. Cambios y evidencia:

- `SAFE_FREE_TWINS="opencode/deepseek-v4.1-flash-free"`. `opencode models` (1.19.6) lista esa ruta,
  que es la condición que `free_twin` exige antes de usarla.
- **Detector de cuota acotado.** `is_quota_error` buscaba la firma en toda la salida, sin mirar el
  exit code. Con el rescate apagado un falso positivo costaba un 77 sobre un job sano; encendido,
  además re-corre el job y pisa su salida. Ahora: firma presente **y** (exit distinto de 0 **o**
  firma en las últimas 15 líneas), y nunca en 124/137/75/76.
- **Lo que no pude verificar:** la forma exacta del error de cuota en el `.out` y su exit code (no
  agoté la bolsa para verlo). Los otros dos errores de proveedor vistos hoy salen al final de la
  salida con exit 1: `Error: Upstream request failed: [overloaded] …` y un volcado JSON de 7 líneas
  (`Error: { "name": "UnknownError", … }`). El detector cubre ambas formas.
- **Prueba en vivo:** envoltura de `opencode` que responde la firma de cuota con exit 1 para
  `opencode-go/deepseek-v4.1-flash` y delega todo lo demás al binario real. Dos jobs de la extracción
  de §5 por el helper (`--parallel 2`): ambos `status=0`, `.gate=opencode/deepseek-v4.1-flash-free`,
  `.rescued` presente, 31/31, 20s de pared, resumen "2 rescatado(s) por modelos free".
- **Riesgos que quedan:** el gemelo es "limited time" y tiene tope diario sin cifra publicada (un
  lote grande puede rescatar solo una parte: el resto queda en 77); y su garantía de no entrenar es
  una frase de la doc de Zen que hay que releer en cada actualización del catálogo.


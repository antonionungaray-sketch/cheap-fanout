# Hallazgos de la actualización 2026-10-01 — catálogo, velocidad y mecánica de cuota

Respaldo del release **1.3.0** (2026-10-01). Qué se encontró, con qué evidencia, y qué **no** se
pudo cerrar. Qué cambió en el skill, archivo por archivo, está en [`CHANGELOG.md`](../CHANGELOG.md).
Ruta fuera del cache de plugins a propósito (sobrevive a `plugin update`).

| | |
|---|---|
| Fecha | 2026-10-01 |
| Máquina | Ubuntu 24.04.5, kernel 7.0.0-34, opencode **1.18.31**, codex-cli **0.157.1 → 0.159.3** |
| Orquestador | Claude Sonnet 5.5 |
| Costo | ≈ **2 USD de cuota Go** (`go-budget`, 30 días: 1.30 → 3.37 USD), tokens de ChatGPT despreciables, y la suscripción de Kimi |

> **Cómo leer las cifras.** Los precios, límites e índices caducan: en 34 días cambió la mecánica
> entera del plan (§2). La fuente de verdad de Go es `opencode.ai/docs/go`; las cifras de aquí
> llevan fecha y, cuando importa, el tipo de evidencia (§1).

## 0. Lo que más cambia decisiones

1. **La ruta de K3 estaba rota, y por una causa distinta a "está lento"** (§5). models.dev renombró
   el proveedor `kimi-for-coding` a `kimi-code-plan-cn`; la llave seguía guardada con el nombre
   viejo y opencode daba `UnknownError` aunque el endpoint respondía 200.
2. **El plan Go ya no tiene pozo global**: los límites son por modelo, con ventanas de 20% / 50% /
   100% de su límite mensual (§2). Cambiar de modelo siempre consigue presupuesto.
3. **La velocidad cambia el caballo del ancho** (§4). `deepseek-v4.1-flash` hace en 17s lo que el
   default anterior (`mimo-v2.5`) hace en 50s, a un precio casi igual, con 26,000 req/5h.
4. **El índice de Artificial Analysis se reescaló** (§3): `glm-5.3-flash` pasó de "57" a **42**. La
   equivalencia con Opus que el skill afirmaba ya no existe; la que había con K3 sí (2 puntos).
5. **K3 deja de ser el pre-revisor por default** (§6): un modelo rápido hace la pre-revisión en 141s
   contra 271s de K3, y K3 conserva la ventaja de hacer cumplir la regla de citas.
6. **Los gemelos free que usaba el rescate automático entrenan con tus prompts** (§8), o murieron.
   El rescate quedó apagado.
7. **Codex**: `gpt-6.1-sol` (índice 52) pasa a ser el asiento casi-frontier, y el sandbox de Linux
   —roto en esta máquina, ni siquiera leía archivos— quedó resuelto con un perfil de AppArmor (§7).
8. **Dos bugs de infraestructura propios del skill**: un falso positivo del detector de SQLite y la
   sustitución de `$N` por el cargador de skills, que corrompía todos los precios (§9).

## 1. Método y límites de la evidencia

**Fuentes primarias leídas directamente por el orquestador** (curl local, sin gastar tokens de modelo):
`opencode.ai/docs/go` y `/docs/zen` (la doc dice "Last updated: Oct 1, 2026"), `models.dev/api.json`,
el leaderboard de Artificial Analysis (vía `r.jina.ai`), las páginas de membresía y precios de Kimi,
`developers.openai.com/codex/sandboxing`, y el endpoint de Kimi directamente.

**Fan-out de investigación:** 15 unidades, 19 jobs (4 unidades duplicadas en dos modelos distintos
para contrastar: Artificial Analysis, OpenAI, Codex y Grok), repartidos en seis modelos
(`glm-5.3-flash`, `deepseek-v4.1-flash`, `deepseek-v4-flash`, `hy3`, `longcat-2.0`, `gpt-6-luna`).
Prompts extractivos: cita textual + URL por cada dato, sin el contexto de la decisión (anti-eco).
Resultado: 18/19 OK; el restante fue un falso positivo del helper (§9.1) y se repitió bien.

**Pre-revisión** por referencia (rutas, no contenido) con siete candidatos (§6), y **spot-check**
del orquestador contra primaria de todo lo de alto impacto.

**Mediciones locales:** (a) benchmark de extracción —14 modelos × 6 campos, con respuesta correcta
calculada por script, y trampas: filas peak/off-peak, tramos por tokens, dos planes—; (b) latencia:
3 PONG + 2 extracciones por modelo, una solicitud en vuelo por modelo, ~9 modelos a la vez.

| Dato | Verificado por el orquestador en primaria | Solo lo reportó un agente barato (con cita) |
|---|---|---|
| Precios, cuotas, límites y privacidad de Go | ✅ doc de Go y Zen, models.dev | |
| Índices y velocidades de AA | ✅ leaderboard (los índices coincidieron al punto; las velocidades se movieron) | Coding Agent Index (62 / 57 / 41) |
| Planes y precios de Kimi | ✅ membership.html y kimi.ai/membership/pricing | |
| Procedimiento AppArmor de Codex | ✅ doc oficial | |
| Límites de Codex por plan, precios de la API de OpenAI | | ✅ dos réplicas independientes coinciden |
| Benchmarks que reporta cada laboratorio sobre su propio modelo | | ✅ — dato del proveedor, no de un tercero |

**Límites que conviene tener presentes:**
- La comparación de pre-revisores es de **un solo lote** (19 unidades).
- El benchmark de extracción **no discrimina calidad**: los 14 modelos de opencode sacaron 84/84.
  Solo sirve para confirmar que ninguno falla, y para medir tiempo.
- Las latencias corrieron con ~9 procesos `opencode` a la vez (el arranque de opencode consume CPU):
  el **orden** es fiable; los valores absolutos están inflados unos segundos.
- Las velocidades de AA son dato vivo y se mueven entre capturas (§3).

## 2. Mecánica del plan Go

La doc de hoy sustituye el pozo global (12 USD/5h · 30 USD/semana · 60 USD/mes, más un tope por
modelo) por:

> *"Each model has the following usage limits: 5-hour — 20% of the monthly limit; weekly — 50%; and
> monthly — 100%."*

Un modelo de límite 60 permite 12 / 30 / 60 USD (los números que antes eran "el global"); uno de
15 permite 3 / 7.50 / 15. La doc **ya no menciona un límite compartido**; en el skill, `go-budget`
conserva una fila agregada solo informativa. Consecuencia: **cambiar de modelo siempre consigue
presupuesto**; elegir a cuál sigue siendo una decisión de calidad.

Hay un **plan Go Plus de 40 USD/mes** (límites por modelo distintos, no un múltiplo único: por
ejemplo `mimo-v2.6-flash` 120, `glm-5.3-flash` 180, `kimi-k3` 60). El precio por token es el mismo.

**Cambios de cuota y precio frente al 2026-08-28:**

| Modelo | Antes (req/5h · límite) | Ahora |
|---|---|---|
| `glm-5.3-flash` | 1,580 · **15** | **6,320 · 60** — deja de ser "físicamente fuera del ancho" |
| `deepseek-v4-flash` | 7,600 · 30 · 0.22/0.66 | 13,000 · 30 · 0.15/0.60 |
| `deepseek-v4-flash-vision-exp` | 3,800 · 15 | 6,500 · 15 |
| `hy4-preview` | no respondía | **responde**, pero con latencia errática (§4) |
| Nuevos | | `deepseek-v4.1-flash` 26,000 · 60; `gpt-6-luna` 4,230 · 15; `mimo-v2.6-flash` 30,100 · 60; `mimo-v2.6-pro` 3,250 · 15; `grok-4.7` 169 · 15; `muse-spark-1.3-contributor` 45,300 · 60; `longcat-2.5-preview-free` y `space-bunny-free` (gratis, ilimitados, "limited time") |
| Salieron de la doc | | `glm-5.1`, `minimax-m2.5`, `qwen3.7-max`, `qwen3.6-plus`, `grok-4.5` |

**Deprecaciones y vencimientos con fecha:**

| Fecha | Qué |
|---|---|
| 2026-10-14 | GPT-5.5 se retira de ChatGPT, ChatGPT Work y Codex en todos los planes (no de la API) |
| 2026-10-21 | Xiaomi depreca `mimo-v2.5` y `mimo-v2.5-pro` en su API (10:00 hora de Beijing) |
| 2026-10-31 | Vence el acuerdo ZDR de DeepSeek ("se renueva cada mes; el vigente vale hasta el 31 de octubre") |
| ya vigente | DeepSeek retiró `V4-Flash` y `V4-Flash-Vision-Exp` ("temporalmente rutean a V4.1-Flash"); sobre `V4-Pro` sus propias páginas se contradicen (§10) |

**DeepSeek** conserva el recargo peak (2x, 01:00-04:00 y 06:00-10:00 UTC de lunes a viernes) en sus
cuatro modelos Go; es el único proveedor del pool con esa mecánica.

## 3. Calidad independiente: Artificial Analysis v4.3.2

Leída el 2026-10-01 en `artificialanalysis.ai/leaderboards/models`. Las dos réplicas de
investigación coincidieron entre sí y con mi lectura directa en **todos** los índices.

**El índice se reescala entre versiones.** Z.ai citaba `glm-5.3-flash` con 57 (AA v4.1.1), el skill
heredó ese 57 con la lectura "= Opus 4.8 = K3", y hoy el mismo modelo marca **42** en la v4.3.2. Es
cambio de escala, no de calidad: K3 pasó a 44 y Opus 5.5 es 58. Regla nueva del skill: un índice
solo se compara dentro de su versión, y una cifra de un laboratorio sobre su propio modelo no es de
un tercero.

| Modelo | Índice | tokens/s | Respuesta total del Index (s) |
|---|:--:|:--:|:--:|
| Claude Opus 5.5 | **58** | 92 | 708 |
| Claude Sonnet 5.5 | 56 | 139 | 446 |
| `gpt-6-astra` | 53 | 51 | 330 |
| Claude Fable 5.1 | 53 | 69 | 276 |
| `gpt-6.1-sol` | 52 | 65 | 290 |
| `gpt-6-sol` | 48 | 74 | 186 |
| Muse Spark 1.3 (vetado) | 48 | 181 | 51 |
| `mimo-v2.6-pro` | **46** | 42 | 64 |
| `grok-4.7` (xhigh) | 46 | 73-75 | 49-86 |
| `glm-5.3` | 45 | 68 | 40 |
| `qwen3.8-max` | 45 | 39 | 67 |
| `kimi-k3` | **44** | **34** | **79** |
| `glm-5.3-flash` | **42** | 45 | 59 |
| Qwen3.8-Flash-Next | 40 | 58 | 46 |
| `deepseek-v4.1-flash` | **39** | **209** | **13** |
| `mimo-v2.6-flash` | 38 | 54 | 50 |
| `gpt-6-luna` | 37 | 127 | 128 |
| `deepseek-v4-pro` | 36 | 81 | 33 |
| `deepseek-v4-flash` | 34 | 204 | — |
| `minimax-m3` | 29 | 99 | 26 |
| `hy3` | 25 | 88 | 32 |
| `longcat-2.0` | 19 | — | — |

No aparecen en AA: `mimo-v2.5`, `hy4-preview`, `longcat-2.5-preview`, `kimi-k2.7-code`, `glm-5.2`,
`qwen3.7-plus`. AA lista "Qwen3.8-Flash-Next" (180B); **no está confirmado** que sea el id
`qwen3.8-flash` de Go.

**Las velocidades de AA se mueven; los índices no.** Entre dos capturas con ~10 minutos de
diferencia, Grok 4.7 (xhigh) pasó de TTFT 78.69s / respuesta 85.56s a 42.40s / 49.10s, y K3 de
4.53s a 4.49s. Por eso el skill cita rangos ("30-79s") y no un número.

**Qué dice AA de la escala frontier:** el asiento "casi-frontier" que el skill daba a K3 (44) queda
por debajo de `gpt-6.1-sol` (52) y `gpt-6-astra` (53), ambos disponibles por la suscripción de
ChatGPT. Según un artículo de AA citado por una réplica (no verificado por mí directamente), el
Coding Agent Index en Codex es 62 para Astra, 57 para `gpt-6-sol` y 41 para `gpt-6-luna`.

## 4. Velocidad medida

Tarea: leer un archivo local de ~6K tokens y devolver un JSON de 84 valores. Mediana de dos
corridas (mínimo-máximo), una solicitud en vuelo por modelo, ~9 modelos simultáneos. "PONG" mide
casi solo el arranque de opencode.

| Ruta | PONG (s) | Extracción (s) |
|---|:--:|:--:|
| `deepseek-v4-flash` | 10 | **15** (14-16) |
| `gpt-6-luna` | 12 | **16.5** (15-18) |
| `deepseek-v4.1-flash` | 11 | **17** (17-17) |
| `glm-5.3-flash` | 12 | **17.5** (16-19) |
| `kimi-code-plan-cn/kimi-for-coding-highspeed` (K2.7 Code) | 6-8 | 23 (20-26) |
| `space-bunny-free` | 7 | 22 (19-25) |
| `hy3` | 13 | 26 (24-28) |
| `longcat-2.0` | 8 | 30 (27-33) |
| `kimi-k3` por la puerta Go | 10 | **31.5** (29-34) |
| `kimi-code-plan-cn/kimi-for-coding` (K2.8 Preview) | 8-9 | 39.5 (39-40) |
| `kimi-code-plan-cn/k3` por Allegretto | 9 | **43.5** (40-47) |
| `opencode/mimo-v2.6-flash-free` | 12 | 44.5 (42-47) |
| `mimo-v2.5` | 13 | 50 (37-63) |
| `grok-4.6` | 6 | 52 (44-60) |
| `longcat-2.5-preview-free` | 10 | 55 |
| `minimax-m3` | 8 | 55.5 (39-72) |
| `qwen3.8-flash` | 9 | 60.5 (45-76) |
| `mimo-v2.6-flash` | 13-44 | 65.5 (46-85) |
| `grok-4.7` | 10 | 67.5 (63-72) |
| `mimo-v2.6-pro` | 15 | **147** (138-156) |
| `hy4-preview` | 11-58 | **104 y 983** |
| Codex (`codex exec`, PONG) | 3-4 | — |

- **El precio por token no es el costo por tarea.** `mimo-v2.5` (0.14/0.28) tardó 3x lo que
  `deepseek-v4.1-flash` (0.15/0.60), y `mimo-v2.6-flash`, que es el más barato por token del pool,
  4x. A igual exactitud, la velocidad decide el caballo del ancho.
- `hy4-preview` ya responde pero dos extracciones dieron 104s y 983s: no se rutea.
- `mimo-v2.6-flash` tuvo un PONG de 44s y otro de 13s: variable incluso en lo trivial.
- La misma extracción por Codex con acceso a archivos (§7.3): `gpt-6-luna` 26s.

## 5. K3: dos problemas distintos

### 5.1 Estaba roto (causa raíz y arreglo)

**Síntoma:** `opencode run -m kimi-for-coding/k3 …` → `UnknownError: Unexpected server error`.

**Diagnóstico:**
1. La llave existía en `auth.json` (solo se inspeccionaron nombres de proveedor y la *forma* de la
   entrada, nunca el valor).
2. Directo con curl a `https://api.kimi.com/coding/v1`, la misma llave: `GET /models` → **200**
   (lista `k3`, `k3-256k`, `kimi-for-coding` y `kimi-for-coding-highspeed`) y un `POST` de chat → 200.
   Así que la suscripción y el endpoint estaban bien.
3. `opencode models kimi-for-coding` → `Provider not found`. En `models.dev/api.json` el proveedor
   ya no existe: lo reemplazan **`kimi-code-plan-cn`** (`api.kimi.com`) y `kimi-code-plan-global`
   (`api.kimi.ai`), ambos con variable de entorno `KIMI_API_KEY`.
4. Con `KIMI_API_KEY` en el entorno, `opencode run -m kimi-code-plan-cn/k3 … PONG` → PONG en 8.9s.

Los modelos `kimi-code-plan-*` **solo aparecen en `opencode models` si hay `KIMI_API_KEY` o una
credencial guardada bajo el nombre nuevo**. `opencode auth list` seguía mostrando la entrada vieja
como huérfana.

**Arreglo aplicado (en la máquina del autor, no versionado):** copiar la entrada
`kimi-for-coding` a `kimi-code-plan-cn` dentro del mismo `auth.json`, con escritura atómica
(archivo temporal con permisos 0600 en el mismo directorio y `rename`), sin imprimir la llave, sin
copias con secretos y con la entrada vieja intacta. Verificado: permisos 600, ningún temporal
sobrante, y `kimi-code-plan-cn/k3` y la ruta vieja `kimi-for-coding/k3` responden por el helper
**sin** `KIMI_API_KEY`. Exportar la llave en el perfil del shell se descartó a propósito: la dejaría
en texto plano en más sitios.

El helper ahora traduce `kimi-for-coding/*` a `kimi-code-plan-cn/*`; `install.sh --check` detecta
la credencial con el nombre viejo y lo avisa.

### 5.2 Es lento (medición)

- Medido en una extracción chica: **43.5s** por Allegretto y **31.5s** por la puerta Go
  (`opencode-go/kimi-k3`); la diferencia de ~12s se repitió en las dos corridas. Los rápidos de Go,
  15-17s.
- AA mide a K3 en **34 tokens/s** y 79s por respuesta del Index (contra 209 tokens/s y 13s de
  `deepseek-v4.1-flash`). Su TTFT (4.5s) está bien: lo lento es producir.
- **Lo que se probó y no sirvió:** `--variant low` en la pre-revisión → 349s (más lento que el
  default de 271s), peor cobertura y 300 KB de trazas volcadas. **Bajar el esfuerzo no arregla a K3.**
  Moonshot documenta `high` por defecto para K3.
- **Alternativas dentro de Kimi:** `kimi-for-coding` es hoy **K2.8 Preview** (desde 2026-09-11,
  "rendimiento cercano a K3, pensamiento más eficiente", 1M de contexto): 39.5s en la extracción y
  584s en la pre-revisión (no siguió el formato de salida). `kimi-for-coding-highspeed` es K2.7 Code
  a ~180-260 tokens/s (23s en la extracción) y consume 3x de cuota. Ninguna es un reemplazo limpio.
- **Conclusión:** K3 no está caído ni congestionado; es lento por diseño y por esfuerzo de
  razonamiento. Dejó de ser el pre-revisor por default (§6).

### 5.3 Planes de Kimi (verificado en primaria)

`kimi.com/code/docs/kimi-code/membership.html`: *"Kimi 会员新套餐正式发布，定价不变"* (los planes
nuevos no cambian el precio). Planes nuevos: Plus **15**, Pro **31**, Max **79**, Ultra **159**
USD/mes (listas 19 / 39 / 99 / 199; `kimi.ai/membership/pricing`). Los planes nuevos quitaron la
cuota semanal; **los miembros antiguos conservan sus reglas** (cuota que se renueva cada 7 días más
una ventana móvil de 5 horas). Umbrales: K3 desde Moderato / Plus; **K3 con 1M de contexto y la
variante highspeed desde Allegretto / Pro**. Una primera lectura de que Allegretto "desaparecía" era
demasiado fuerte: la tabla oficial lo mantiene como plan antiguo.

## 6. Pre-revisores: qué cubre cada uno

Mismo lote, mismas 19 unidades, por referencia. **Problemas reales verificados por mí:** **U04**
(una réplica se contradice con su propia cita sobre los niveles de esfuerzo `max`) y **U19** (un
informe con **0 de 31** números con cita textual). **U15** es una discrepancia legítima de marcar
—dos réplicas dieron cifras de AA distintas para Grok 4.7— pero **no era un error de la réplica**:
fue la deriva de dato vivo de §3.

| Pre-revisor | Tiempo | Unidades | ¿Marcó U04 / U19 / U15? |
|---|:--:|:--:|---|
| `deepseek-v4.1-flash` | **141s** | 19/19 | ✅ / ❌ (dio OK a un informe sin citas) / ✅, pero lo declaró FALLO (exagerado). 13 discrepancias cruzadas |
| `kimi-code-plan-cn/k3` (default) | 271s | 19/19 | **✅ / ✅ / ✅**. 6 discrepancias cruzadas |
| K3 `--variant low` | 349s | 19/19 | ❌ / ❌ / ❌; 300 KB de trazas |
| `glm-5.3-flash` | 367s | **15/19** | — / ❌ / — (no separó las réplicas) |
| `kimi-for-coding` (K2.8 Preview) | 584s | no siguió el formato | ❌ / ❌ / ✅ |
| `glm-5.3` | 802s | **15/19** | — / ✅ / — (no separó las réplicas) |
| `mimo-v2.6-pro` | 1,009s | 19/19 | ❌ / ❌ / ✅ |

**Lectura:** los modelos de índice alto (`glm-5.3`, `mimo-v2.6-pro`) no sirven de pre-revisores:
13-17 minutos y peor cobertura. El rápido cruza unidades (más discrepancias) y K3 hace cumplir la
regla de citas; **se complementan**. De ahí la regla: pre-revisor por default `deepseek-v4.1-flash`
y, en lotes de alto impacto, K3 **en paralelo** (el tiempo de pared es el de K3, no la suma). La
plantilla de pre-revisión ahora exige cita textual explícita y pide una sección `DISCREPANCIAS`.

**Límite:** un solo lote. Si la política depende de esto, repetir con otro.

## 7. OpenAI y Codex

### 7.1 Familia GPT-6

| Modelo | Lanzamiento | USD/1M in/out | Índice AA | Disponibilidad |
|---|---|---|:--:|---|
| `gpt-6-astra` | 2026-09-03 | 10 / 50 | 53 | API, ChatGPT, Codex |
| `gpt-6-sol` | 2026-09-22 | 2 / 10 | 48 | API, ChatGPT Work y Codex (no Chat) |
| `gpt-6-luna` | 2026-09-22 | 0.10 / 0.50 | 37 | API, ChatGPT Work y Codex; también en el pool Go |
| `gpt-6.1-sol` | 2026-09-29 | 2 / 10 | 52 | API, ChatGPT Work y Codex (no Chat) |

Para todos, prompts de más de 272K tokens cuestan 2x en input y 1.5x en output. OpenAI dice que
`gpt-6.1-sol` "casi iguala a Astra en coding agentic, computer use y trabajo profesional a un
quinto del precio"; AA lo confirma (52 contra 53). `gpt-6-astra` no admite el esfuerzo `none`.

### 7.2 Codex CLI

- **Versión:** estable 0.159.3 (2026-09-30); la local era 0.157.1 y se actualizó. El modelo
  `gpt-6.1-sol` entró al catálogo en la 0.159.1: en 0.157.1 fallaba con *"not supported when using
  Codex with a ChatGPT account"* y *"Model metadata … not found"*; **en 0.159.3 responde** por el
  helper, igual que el modelo default.
- **Modelos con login ChatGPT:** `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6-sol`, `gpt-6-luna`. El default
  **local** de `~/.codex/config.toml` es `gpt-6-astra` (el más caro de la cuota); el skill aún
  documentaba `gpt-5.5`. Es configuración de la máquina, no un cambio de Codex: un job `codex`
  sin sufijo usa ese archivo, por eso los jobs piden el modelo explícito.
- **Límites estimados de mensajes locales por 5 horas (Plus / Business Standard):** Astra 5-45,
  `gpt-6.1-sol` 15-160, `gpt-6-sol` 15-150, `gpt-6-luna` 350-3,000. Los planes Pro no tienen límite
  de 5 horas. El modo Fast gasta 2.5x de la cuota incluida; Ultrafast (solo Astra) 8x.
- **GPT-5.5 se retira de Codex el 2026-10-14**; GPT-5.4 y 5.3-Codex-Spark ya se retiraron.
- Un hallazgo menor: existe un modelo oculto `gpt-reserve` ("fast and affordable agentic coding
  model"); respondió PONG pero no está documentado y no se rutea.

### 7.3 El sandbox de Linux: de "no lee archivos" a funcionando

**Síntoma:** con la tarea de extracción en `read-only`, el job devolvió
`{"error":"No pude leer go.txt: … bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted"}`
(**0/84**). No era solo que no escribiera (lo que el skill ya documentaba): **ningún job codex
podía abrir un archivo**.

**Causa raíz:** Ubuntu 24.04 trae `kernel.apparmor_restrict_unprivileged_userns=1`; `bwrap` (en
`/usr/bin/bwrap`) no tenía perfil que le permitiera crear user namespaces, y
`apparmor-profiles` ni siquiera estaba instalado.

**Lo que NO lo arregló:** actualizar a 0.159.3 (probado con `gpt-6.1-sol` y `gpt-6-luna`: el mismo
error). La 0.159.3 trae un `bwrap` empaquetado, pero ese helper "requiere user namespaces sin
privilegios" y AppArmor se los niega igual.

**Lo que sí:** el procedimiento oficial de OpenAI (`developers.openai.com/codex/sandboxing`),
ejecutado por el usuario con sudo:

```bash
sudo apt install apparmor-profiles apparmor-utils
sudo install -m 0644 /usr/share/apparmor/extra-profiles/bwrap-userns-restrict \
     /etc/apparmor.d/bwrap-userns-restrict
sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
```

Concede user namespaces **solo a `/usr/bin/bwrap`** y deja activa la restricción global (la
alternativa documentada, `sysctl kernel.apparmor_restrict_unprivileged_userns=0`, la apaga para
todos los programas y se descartó). Persiste al reiniciar. Reversión:
`sudo apparmor_parser -R /etc/apparmor.d/bwrap-userns-restrict && sudo rm /etc/apparmor.d/bwrap-userns-restrict`.

**Verificación posterior:**

| Prueba | Antes | Después |
|---|---|---|
| `bwrap --unshare-all --ro-bind / / true` | `Failed RTM_NEWADDR` | OK |
| `read-only`: extracción de 84 datos | 0/84 | **84/84** (`gpt-6.1-sol` y `gpt-6-luna`) |
| `workspace-write`: crear un archivo en el directorio del job | fallaba | escribe |
| Errores `bwrap` en el log de los jobs | uno por job | 0 |
| **Contención** — `read-only` intentando escribir | — | no escribe (archivo no creado; el modelo responde que está bloqueado) |
| **Contención** — `workspace-write` intentando escribir en `../` | — | no escribe (el archivo fuera no se creó) |

**Incidencia del propio método:** una primera prueba de contención "falló" (archivo creado) porque
un `rm` previo no corrió —zsh aborta el comando si un glob no tiene coincidencias— y quedaba un
archivo de una prueba anterior. Se repitió comprobando antes que el estado inicial estuviera
limpio. Lección: en una prueba de "no debe existir", verifica el estado de partida.

Mientras no estuvo el perfil, el único camino era `danger-full-access` en un directorio aislado
(`codex:gpt-6-luna` → 84/84 en 26s); queda como último recurso en una máquina Ubuntu 24.04 sin él.

## 8. Privacidad

**Gemelos free.** La doc de Zen dice, de `mimo-v2.6-flash-free`, `mimo-v2.5-free`, `big-pickle` y
`ling-3.0-flash-fin-free`: *"During its free period, collected data may be used to improve the
model."* Las de NVIDIA (`nemotron-3-ultra-free`, `nemotron-3.5-lightning-free`): *"Trial use only —
do not submit personal or confidential data."* El rescate automático por cuota del helper mandaba el
job al gemelo free del mismo modelo, es decir, **a un endpoint que entrena**: el mismo motivo por
el que `muse-spark` está vetado. Se apagó (`SAFE_FREE_TWINS` vacío).

Probados con `opencode run` el 2026-10-01:

| Ruta | Estado | Entrena |
|---|---|---|
| `longcat-2.5-preview-free`, `space-bunny-free` (modelos Go por derecho propio) | ✅ responden | No (según OpenCode: 0 días, sin entrenamiento) |
| `opencode/mimo-v2.6-flash-free`, `big-pickle` | ✅ responden | **Puede** |
| `opencode/mimo-v2.5-free`, `hy3-free`, `deepseek-v4-flash-free`, `minimax-m3-free`, `longcat-2.0-free` | ❌ `UnknownError` | — (eran los gemelos de rescate) |

**LongCat — discrepancia no cerrada.** La doc de OpenCode dice "sin entrenamiento, 0 días" para su
ruta, pero la política de privacidad **propia** de Meituan (`longcat.chat/privacy`) permite usar
datos desidentificados para entrenar y optimizar modelos, y exige guardar ciertos logs ≥ 6 meses.
Uso permitido solo vía OpenCode y con material no sensible, hasta confirmar el acuerdo.

**DeepSeek:** retención 0 días con la salvedad de que el ZDR vence el 2026-10-31 si no se renueva.
**Grok y GPT Luna (5.6 y 6):** retención de 30 días. **Muse Spark (1.2 y 1.3 contributor):**
entrenan y no son ZDR → vetados (confirmado por Antonio el 2026-10-01; el 1.3 por analogía exacta
con el texto de la doc). **`grok-4.7`** queda vetado: familia Grok, TTFT de 30-79s según AA y 67.5s
en la extracción medida, retención de 30 días.

## 9. Bugs de infraestructura del skill

### 9.1 Falso positivo del detector de "database is locked"

Una unidad de investigación sobre el changelog de opencode *citó* en su informe la frase
"database is locked". `is_lock_error` buscaba la firma **en cualquier parte** del `.out`, así que
tomó un informe de 8 KB por el choque de arranque, **reintentó el job tres veces** (~8 minutos en
vez de ~2) y lo dejó con `.status=75`. El choque real muere antes de llamar al modelo y deja un
`.out` diminuto (cabecera + error; "0 líneas de log", ver `sqlite-arranque-en-frio.md`).

**Arreglo:** la firma solo cuenta si el `.out` pesa ≤ 2 KB (`CHEAP_FANOUT_LOCK_OUT_MAX`). Primer
intento con 8 KB fue insuficiente (el informe pesaba 8,113 B). Verificado con una repetición del
job (status 0, ~2 min) y con `test/detectores-y-vetos.sh`, que cubre choque real, informe largo,
salida normal y el override.

### 9.2 El cargador de skills sustituye `$N`

Invocar `/cheap-fanout <argumentos>` sustituye en el texto del skill cada `$0`, `$1`, … por el
argumento correspondiente. Con la invocación de esta sesión, `$0.14` llegó como `analiza.14`,
`$1.40` como `las.40`, `$12` como `incluyendo`, `$15` como `OpenAI`, y así: **todos los precios del
skill llegaron corruptos**, y algunos topes ("tope $15" → "tope OpenAI") sin que nada lo señalara.
Un `$` seguido de un número que no existe como argumento (por ejemplo `$60`) se queda tal cual, por
lo que el daño depende de cuántos argumentos se pasen.

**Alcance:** 150 apariciones de `$<dígito>` en 56 líneas de `cheap-fanout/SKILL.md` y 2 en
`cheap-fanout-ultimate/SKILL.md`. **Arreglo:** en los SKILL.md los precios van como números y
"USD", nunca `$` pegado a un dígito, con un aviso al inicio. El README no se carga como skill y
conserva `$`.

### 9.3 `go-budget` seguía midiendo un pozo que ya no existe

Reescrito para medir por modelo en tres ventanas (5h contra 20% del límite, 7d contra 50%, 30d
contra 100%). La fila agregada se conserva como informativa y **no mueve el exit code**. Cambia el
significado del exit code `2`: ahora solo lo produce `--model` cuando ese modelo agotó una ventana.
El formato `--tsv` agrega columnas al final de las filas por modelo sin mover las anteriores. Con
`GO_PLUS=1` compara contra los límites de Go Plus.

### 9.4 Operativa

- **No edites `bin/cheap-fanout` mientras corre un lote:** bash lee el script de forma incremental
  y un cambio de tamaño desplaza lo que aún no leyó. Aquí no hubo daño (el resumen final salió
  bien), pero pudo haber salido corrupto.
- **Incidencias del propio método** (para que las cifras de §4 se lean bien): la primera corrida de
  latencia fue inválida porque los ids de Go iban sin el prefijo `opencode-go/` que el helper
  agrega, y se repitió; un script mío sobrescribió las salidas por repetición (por una expansión
  de `local` en bash), así que la exactitud por repetición no es verificable, aunque el tiempo sí y
  la exactitud sí está cubierta por el benchmark de 84 valores por separado.

## 10. Otros proveedores (resumen)

| Proveedor | Hallazgos relevantes |
|---|---|
| **Z.ai** | GLM-5.3-Flash (2026-08-26): 320B / 18B activos, MIT, multimodal nativo (imagen, video, PDF), 1M de contexto, nombre en clave "ox-alpha". GLM-5.3 (2026-08-18) usa el mismo base que 5.2 (todo el avance es post-entrenamiento), licencia propia. El Coding Plan pasó a créditos el 2026-07-30 y enruta 5.2/5.1 a 5.3. FlashX (200 tokens/s) no está en Go |
| **Xiaomi** | MiMo-V2.6-Pro (1.02T / 42B) y Flash (309B / 15B), MIT, 1M de contexto, omni nativo; variante `ultraspeed` en su API. V2.5 y V2.5-Pro deprecados el 2026-10-21 |
| **DeepSeek** | V4.1-Flash (2026-09-10): 552B MoE (8B activos en entrada, 16B en salida), MIT, multimodal nativo, esfuerzo continuo 1-100, 1M de contexto. Dice que V4.1-Flash supera a V4-Pro "en rendimiento, costo, velocidad y tiempo total" (AA: 39 contra 36). **Contradicción propia:** una página dice que todo `deepseek-v4-pro` se rutea a V4.1-Flash desde el 2026-09-14 y otra que decidieron seguir ofreciéndolo |
| **Meituan (LongCat)** | 2.5-Preview (2026-09-25): 1M de contexto, entrada de imagen. 2.0 (2026-06-30): 1.6T / ~48B, MIT (el README dice 1.6T, Hugging Face 1.8T) |
| **Alibaba (Qwen)** | Qwen3.8-Max: 2.4T / 95B, pesos abiertos (Hugging Face, 2026-08-12; blog 2026-08-03). Qwen3.8-Flash-Next 180B. Su Coding Plan Pro (50 USD/mes) **no incluye** qwen3.8 |
| **MiniMax** | M3 (2026-06-01): ~428B / 23B, licencia `minimax-community`. M3.1-Flash-Preview (2026-09-29). "M Plan" reemplaza a "Token Plan" desde 2026-09-29; los precios publicados no coinciden entre páginas (22/55/132 contra 20/50/120) |
| **Tencent** | Hy4 preview (2026-08-28): 770B / 49B, Apache-2.0, 1M de contexto. Hy3: 295B / 21B, Apache-2.0, 256K; `hy3-preview` retirado el 2026-08-31 |
| **xAI** | Ahora "SpaceXAI". Grok 4.7 (2026-09-21): mismo precio y "misma velocidad" que 4.6, contexto 500K, retención 30 días, ZDR opcional por equipo. AA marca 4.6 como "deprecated" |
| **OpenCode** | **v2.0.6** (2026-09-17) coexiste con v1 (1.18.34, 2026-09-30); el instalador del sitio ya apunta a v2, sin guía de migración (`/v2/docs/migration` da 404). En v2 la ruta de la base es `opencode debug paths db`; el helper y `go-budget` dependen de `opencode db` de v1. **Quedarse en v1 hasta verificar** |
| **ZenRows / Jina** | ZenRows ahora se llama "Fetch" (antes Universal Scraper API); 5,000 créditos gratis/mes, costos 1 / 5 / 10 / 25, concurrencia 5 en el plan gratis, no cobra peticiones fallidas, `response_type=markdown` vigente. Jina Reader sigue gratis (20 RPM sin llave, 500 con llave gratis; Elastic vende su licencia comercial aparte desde 2026-08-10). Discrepancia no cerrada: el primer plan de pago de ZenRows es 19 o 16 USD según la página |
| **Anthropic** | Fable 5.1 (10 / 50 USD), Opus 5.5 (4 / 20), Sonnet 5.5 (2 / 10), Haiku 4.5 (1 / 5); AA: 53 / 58 / 56. Una réplica menciona un "Mythos 5.1" al mismo precio que Fable; no verificado |

## 11. Abierto, no verificado y seguimiento

- **Una sola muestra** en la comparación de pre-revisores (§6) y en las latencias (§4).
- **Agentic propio no medido:** la fila "código agentic multi-paso" se apoya en el índice y en lo
  que dice DeepSeek, no en una prueba mía.
- **Calidad en una unidad genuinamente difícil:** no hay comparativo propio entre `glm-5.3-flash` y
  un frontier. El benchmark de extracción no discrimina. Hacerlo con la próxima unidad real
  (`glm-5.3-flash` contra `codex:gpt-6.1-sol`).
- **LongCat:** confirmar el acuerdo de OpenCode con Meituan antes de darle material sensible (§8).
- **`qwen3.8-flash`:** confirmar si el id de Go es el "Flash-Next" que AA mide.
- **OpenCode v2:** verificar `opencode db` (usado por el pre-vuelo del helper y por `go-budget`) antes
  de migrar.
- **DeepSeek V4-Pro:** su estado real, dado que sus páginas se contradicen.
- **Fechas a vigilar:** 2026-10-14 (GPT-5.5 sale de Codex), 2026-10-21 (MiMo V2.5 deprecado: el
  default ya migró), 2026-10-31 (vence el ZDR de DeepSeek).
- **Repetir estas mediciones** al releer la doc: el benchmark y los scripts de latencia no están
  versionados; el método de §1 y §4 alcanza para rehacerlos en una sesión.

## 12. Cambios aplicados fuera del repo (en la máquina del autor, no versionados)

| Cambio | Cómo | Reversión |
|---|---|---|
| Credencial de Kimi bajo `kimi-code-plan-cn` | Copia atómica dentro de `~/.local/share/opencode/auth.json` (0600) | Borrar esa entrada del JSON |
| Codex 0.157.1 → 0.159.3 | `npm install -g @openai/codex@0.159.3` (nvm, sin sudo) | `npm install -g @openai/codex@0.157.1` |
| Perfil AppArmor de `bwrap` | Los tres comandos de §7.3, con sudo | `apparmor_parser -R` y `rm` del perfil (§7.3) |

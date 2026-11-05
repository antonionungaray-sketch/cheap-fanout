# Hallazgos de la actualización 2026-11-05 — plan Go, índice v5, velocidad y saturación

Respaldo de los cambios de la versión **1.4.0 (sin publicar)**. Qué se encontró, con qué evidencia y
qué **no** se pudo cerrar. Qué cambió en el skill, archivo por archivo, está en
[`CHANGELOG.md`](../CHANGELOG.md).

| | |
|---|---|
| Fecha | 2026-11-05 (jueves; mediciones entre 20:45 y 21:45 UTC, fuera de las horas peak de DeepSeek) |
| Máquina | Ubuntu 24.04, opencode **1.18.35** al medir; **1.19.5** al cierre (actualizado a petición de Antonio, ver §8). Existe 2.2.5, sin validar |
| Orquestador | Claude Sonnet 5.5 |
| Costo | ≈ **6 USD de cuota contable de Go** (`go-budget`, 30 días: 3.49 → 6.00; no se cobran, son la tarifa que consume los límites): `kimi-k3` 1.78, `kimi-k3.1-pro` 0.82, `gemini-4-argon` 0.82, `deepseek-v4.1-flash` 0.48, `qwen3.8-max` 0.34 y el resto por debajo de 0.25. Cero tokens de Codex y de Kimi directo |

## 0. Lo que más cambia decisiones

1. **`deepseek-v4.1-flash`, el caballo del ancho, está saturado** (§5): 8 de 13 corridas tardaron
   117-216s, vencieron o fallaron con `[prefill_cap_refused]` / `[overloaded]`; hace 5 semanas hacía
   17s. Pasó en off-peak, con el modelo solo y con otros modelos sanos al mismo tiempo.
2. **El índice de Artificial Analysis se reescaló otra vez, a v5.0.1** (§4): `glm-5.3-flash` pasó de
   42 a 28 y `deepseek-v4.1-flash` de 39 a 29-33. La razón por la que `glm-5.3-flash` era "la unidad
   difícil" ya no existe.
3. **La suscripción directa de Kimi está pausada** (instrucción de Antonio) y las tres rutas
   `kimi-code-plan-cn/*` fallan con *"does not have access to Kimi Code right now"* (§7). K3 va por Go.
4. **Plan nuevo Go Teams, ocho modelos nuevos y siete muertos** (§2, §3).
5. **Hay gemelos free seguros otra vez** (`glm-5.3-flash-free`, `deepseek-v4.1-flash-free`): cero
   retención, cero entrenamiento (§6).
6. **opencode 2.x existe** y el skill no se validó en él (§8).

## 1. Método y límites de la evidencia

**Fuentes primarias leídas directamente por el orquestador** (curl local, sin gastar tokens de modelo):
`opencode.ai/docs/go` y `/docs/zen` (hoy alias de `/v2/docs/console/go/` y `/v2/docs/console/models/`;
byte por byte idénticas), el endpoint público `https://opencode.ai/inference/go/v1/models`,
`models.dev/api.json`, el HTML del leaderboard de Artificial Analysis (tabla parseada con un script, no
con el resumen de Jina), el changelog de opencode y las releases de GitHub.

**Fan-out de investigación:** 5 jobs (R1 changelog en dos réplicas, R2 página de Zen en dos réplicas,
R3 páginas de consola en una) con prompts extractivos: cita textual por dato, sin el contexto de la
decisión (anti-eco). Resultado: 4/5 OK; `R1.A` (`deepseek-v4.1-flash`) venció a los 4 min con 47 KB de
trazas (la saturación de §5). Lo que usé de ellos: las citas del changelog (verifiqué 3 contra la
primaria: ✅) y las de consola (verifiqué `Go requires it`, `opencode.allowance` y el 403 de los free:
✅). La pre-revisión de §6 marcó errores reales en `R1.B` (3 citas con versión equivocada, un bullet
corrupto), que **no usé**: lo de opencode v2 que cito sale de la primaria.

**Mediciones locales:** (a) extracción: 6K tokens de la doc de Go y 84 valores a devolver con
respuesta calculada por script (14 modelos × 6 campos, con trampas: tres planes, tramos por tamaño,
descuento vigente); (b) web con cita: leer `docs/go` con `webfetch` y devolver 9 valores con su cita;
(c) pre-revisión por referencia de 5 unidades reales. Una solicitud en vuelo por modelo, 6-9 modelos
a la vez.

| Dato | Verificado por el orquestador en primaria | Solo lo reportó un agente barato |
|---|---|---|
| Precios, cuotas, límites, privacidad, fechas de Go | ✅ doc de Go (31 modelos, 3 planes) y endpoint | |
| Go Teams = Go + 5 USD en cada modelo | ✅ comprobado por script en las 39 filas | |
| Índices AA v5.0.1 | ✅ tabla parseada del HTML | |
| Gemelos free, entrenamiento y retención de Zen | ✅ grep de la página y PONG | |
| Notas de versión de opencode (1.19.x, 2.x) | ✅ 3 citas contra el changelog | resto de la extracción |
| `x-opencode-session` obligatorio en Go, `opencode.allowance` | ✅ grep de la página de consola | |
| Estado de Kimi directo | ✅ error literal del proveedor | |

**Límites que conviene tener presentes:**
- La comparación de pre-revisores es de **un lote de 5 unidades**: evidencia delgada.
- Los benchmarks de extracción (84/84) y de web (9/9) **no discriminan calidad**; solo miden tiempo y
  confirman que ninguno falla. **No hay medición de calidad en una unidad realmente difícil.**
- Latencias con 6-9 procesos `opencode` simultáneos: el **orden** es fiable, los absolutos están
  inflados unos segundos. Medianas de 5 corridas (dos rondas), un solo día.
- Los índices de AA son por nivel de esfuerzo y opencode no dice cuál usa por default.

## 2. Mecánica del plan Go (doc del 2026-11-05)

- **Tres planes:** Go 10 USD/mes, Go Plus 40 USD/mes y **Go Teams 20 USD/miembro/mes** (*"Every member
  gets their own limits, $5/month higher than Go on every model"*; solo para workspaces con varios
  miembros; *"Go Teams starts with Extra Usage on"*). Comprobado: Teams = Go + 5 en las 39 filas
  (los gratis siguen ilimitados); Go Plus es de 2x a 8x según el modelo, no un múltiplo único.
- **`deepseek-v4.1-flash`: límite 60 → 100 USD** (43,330 req/5h, antes 26,000). El changelog de
  opencode v2.2.4 (2026-10-30) lo confirma: *"Raised OpenCode Go limits for DeepSeek V4.1 Flash"*.
- **El ZDR de DeepSeek vale hasta el 2026-11-30** (antes 2026-10-31): *"ZDR agreement is renewed
  monthly"*. El descuento de `gemini-4-argon` (50%) vence el mismo día.
- **Extra Usage** (antes "Use balance"): *"Go will fall back to your pay-as-you-go balance after you've
  reached your usage limits"*; opt-in en Go, encendido en Teams. Es dinero real.
- **Restricciones del workspace:** *"By default, paid endpoints that train on request data are
  blocked, and allowed regions are Europe & United States"*; DeepSeek pide *Global* en *Regions*. Aquí
  DeepSeek responde, así que está permitido.
- **Cabeceras:** *"Send a stable session ID with every request … Go requires it"* (`x-opencode-session`).
  El cliente `opencode` ya la manda; no afecta al helper.
- **Cada respuesta de Go informa** `opencode.allowance` ("how much the request counted toward your
  usage limits, in dollars of the plan's monthly limit").
- **Presupuestos de consola** (`Policy budget exceeded`, HTTP 429): no cuentan el uso dentro del plan
  Go ni los modelos free.

## 3. Catálogo: nuevos, muertos y cambios

- **Nuevos en la doc:** `claude-haiku-5-5` (2026-10-07), `gemini-4-argon` (10-13), `kimi-k3.1-pro`
  (10-23), `minimax-m3.1-flash` (10-19), `step-5-preview` (09-16), `hy4` (**11-04**, ayer),
  `beam-free` (10-05), `iceman-contributor-free` (10-24).
- **Muertos (PONG del 2026-11-05):** `deepseek-v4-flash`, `deepseek-v4-flash-vision-exp`,
  `kimi-k2.6`, `minimax-m2.7`, `longcat-2.5-preview-free`, `space-bunny-free`, `step-5-preview-free`
  (`UnknownError` en 3-4s). `mimo-v2.5` y `mimo-v2.5-pro`: *"Model mimo-v2.5 has been deprecated. Use
  mimo-v2.6-flash instead"*, **aunque la tabla de la doc los lista** (31 en la doc, 29 en el endpoint).
- **Modalidades según el endpoint:** `glm-5.3-flash` ya no lista PDF (el skill decía texto+imagen+
  video+PDF). PDF: `gpt-6-luna`, `gpt-5.6-luna`, `claude-haiku-5-5`, `gemini-4-argon`, `muse-spark`.
- Catálogo completo con la velocidad medida: `reference/catalogo-go.md`.

## 4. Calidad independiente: Artificial Analysis v5.0.1

Leído el 2026-11-05 en el HTML del leaderboard (`Artificial Analysis Intelligence Index v5.0.1`;
rangos = niveles de esfuerzo que AA publica). Antes: cifras de v4.3.2 que citaba el skill el
2026-10-01 (no re-medidas hoy).

| Modelo | v4.3.2 (2026-10-01) | v5.0.1 (2026-11-05) |
|---|:--:|:--:|
| `deepseek-v4.1-flash` | 39 | 29 (high) – 33 (max) |
| `glm-5.3-flash` | 42 | 28 |
| `glm-5.3` | 45 | 23 (low) – 32 (max) |
| `mimo-v2.6-pro` | 46 | 30 |
| `mimo-v2.6-flash` | 38 | 27 |
| `minimax-m3` | 29 | 19 |
| `qwen3.8-max` | 45 | 34 |
| `deepseek-v4-pro` | 36 | 23 |
| `grok-4.7` | 46 | 31 – 35 |
| `gpt-6-luna` | 37 | 21 (high) – 28 (max) |
| `kimi-k3` | 44 | AA ya no lo lista (`kimi-k3.1-pro`: 46) |
| Opus 5.5 / Sonnet 5.5 / Fable 5.1 | 58 / 56 / 53 | 59 / 55 / 49 (esfuerzo máx.; Fable 50 en xhigh) |
| `gpt-6.1-sol` / `gpt-6-astra` | 52 / 53 | 50-55 / 55-57 (high a max) |
| **Nuevos:** `claude-haiku-5-5` · `gemini-4-argon` · `minimax-m3.1-flash` · `step-5-preview` · `hy4` · `beam-free` | — | 25-36 · 50 · 29 · 29 · 35 · 18 |

Consecuencias: el orden entre `deepseek-v4.1-flash`, `glm-5.3-flash` y `glm-5.3` cambió, así que la
fila de "unidad difícil" pasó a `claude-haiku-5-5`; `mimo-v2.6-pro` ya no es "el mejor abierto"
(ahora `kimi-k3.1-pro`, 46). **Tres versiones del índice en dos meses**: cualquier cifra del skill
anterior al 2026-11-05 no es comparable.

## 5. Velocidad medida

Tarea: leer un archivo local de ~6K tokens y devolver 84 valores. Mediana (mín-máx) de 5 corridas
(dos rondas), una solicitud en vuelo por modelo. Todas las corridas exitosas dieron 84/84 salvo una de
`claude-haiku-5-5` (83) y una de `hy3` (78) — antes de corregir mi parser (§9) parecía que varias
fallaban.

| Ruta | Extracción (s) | Nota |
|---|:--:|---|
| `minimax-m3.1-flash` | **13** (10-21) | caballo del ancho |
| `gpt-5.6-luna` / `gpt-6-luna` | 15 / 17 (15-18) | |
| `claude-haiku-5-5` | 18 (16-20) | |
| `glm-5.3-flash` | 20 (17-25) | |
| `kimi-k3` (Go) | 22 (15-24) | 31.5s el 2026-10-01 |
| `beam-free` | 25 (16-28) | gratis |
| `glm-5.3` | 26 (23-30) | |
| `qwen3.8-flash` | 28 (23-30) | |
| `hy3` / `glm-5.2` | 32 / 32 | |
| `kimi-k3.1-pro` | 35 (30-38) | 8+ min en la pre-revisión |
| `minimax-m3` | 38 (14-63) | errático |
| `deepseek-v4-pro` / `qwen3.7-plus` | 41 / 41 | |
| `kimi-k2.7-code` | 42 | |
| `mimo-v2.6-flash` | 46 (32-61) | |
| `hy4` | 48 (46-51) | nuevo |
| `mimo-v2.6-pro` / `longcat-2.0` | 50 / 51 | |
| `qwen3.8-max` | 59 (47-71) | |
| `gemini-4-argon` | 68 (44-75) | |
| `hy4-preview` | 86 (39-133) | errático |
| `step-5-preview` | — | flaky: ruta inventada y "Endpoint is unavailable" |
| **`deepseek-v4.1-flash`** | **21-25 / 117-122 / t.o.** | **bimodal** |

**`deepseek-v4.1-flash`, en detalle:** 7 extracciones: 24, 117, 21, 25, 122s, un timeout a los 300s con
salida vacía y una corrida que maté a los 3 min. Prueba web: 216s correcta y una falla
`[prefill_cap_refused] the cell is at capacity; retry shortly (after 5 s)`. Pre-revisión: 134s bien.
Repetición ~1 h después, el modelo solo: `[overloaded] the server is overloaded; retry shortly` a los
17s, una corrida de 70s y otro timeout a los 300s. **8 de 13 corridas malas.** El PONG respondió siempre
(11-17s): el modelo está vivo pero sin capacidad.

**Prueba web con cita** (9 valores, 14 citas): `minimax-m3.1-flash` 27s/11s, `claude-haiku-5-5` 18s/19s,
`glm-5.3-flash` 22s/22s, `gpt-6-luna` 28s/22s: todas 9/9, con las dos fechas del 30 de noviembre
correctas (`claude-haiku-5-5` dio solo 3 citas en una de las dos corridas).

## 6. Pre-revisores y gratuitos

**Pre-revisión** de 5 unidades reales (por referencia, plantilla del skill + "¿truncada?"). Fallas del
lote que yo conocía o verifiqué: U01 truncada por timeout; U02 con 3 citas reales atribuidas a la
versión equivocada y un bullet corrupto; U04 omitía los ids exactos que su prompt exigía.

| Pre-revisor | Tiempo | U01 | U02 | U04 |
|---|--:|:--:|:--:|:--:|
| `gpt-6-luna` | **86s** | ✅ | ✅ (exageró: FALLO) | ✅ |
| `deepseek-v4.1-flash` | 134s | ✅ | ✅ | ✅ |
| `minimax-m3.1-flash` | **163s** | ✅ | ✅ (3 errores + bullet corrupto) | ✅ |
| `kimi-k3` (Go) | 196s | ✅ | ✅ (2 errores) | ✅ |
| `claude-haiku-5-5` | 203s | ✅ | ✅ (3 errores) | **❌ OK** |
| `glm-5.3-flash` | 215s | ✅ | **❌ OK** | **❌ OK** |
| `kimi-k3.1-pro` | venció a 480s | — | — | — |

`minimax-m3.1-flash` fue el más exhaustivo; `glm-5.3-flash` no sirve de pre-revisor (**falso OK**
en dos unidades, que invalida su veredicto de lote según la regla 1).

**Gratuitos (PONG + doc de Zen):** `opencode/glm-5.3-flash-free` y `opencode/deepseek-v4.1-flash-free`
responden (~8s) y la doc dice *"zero-retention … does not use your data for model training"*;
`beam-free` responde, no entrena, retiene 30 días; `opencode/mimo-v2.6-flash-free` responde pero la doc
dice *"collected data may be used"*; **`iceman-contributor-free` entrena** (*"in exchange for permission
to use your prompts and completions"*) y el servidor lo bloquea hoy con *"This Go model trains on
request data. Turn on 'Allow paid endpoints that train on request data'…"*.

## 7. Kimi directo

Las tres rutas `kimi-code-plan-cn/{k3, k3.1-pro, k3.1-pro-highspeed}` respondieron *"Your current
subscription does not have access to Kimi Code right now. Upgrade your plan…"*, con 4/4 corridas
fallidas cada una. Antonio confirmó que la suscripción está pausada; el skill la saca del ruteo y la
cuenta como presupuesto pausado. El proveedor ya expone `k3.1-pro` y `k3.1-pro-highspeed` (1M de
contexto) por si se reactiva. K3 por Go: 15-24s en la extracción, 196s en la pre-revisión.

## 8. opencode 2.x

El changelog (`opencode.ai/changelog`) y las releases muestran `v2.0.26` (2026-10-08) a `v2.2.5`
(2026-10-30) y, en paralelo, `v1.19.0` a `v1.19.5`. Citas verificadas: *"OpenCode 1 now stays on the 1.x
release line … 1.x installs are never offered a 2.x build as a regular update"*, y *"Upgrading to
OpenCode 2 remains a separate, explicit choice … `opencode upgrade --major`"*. El changelog **no
menciona** `opencode db`, SQLite ni el esquema de la base (lo que usan `go-budget` y el precalentado del
helper); sí dice *"no database migration is required"* para el cambio de formato de sesiones de la
2.1.0. **No lo probé en 2.x.**

**Actualización del CLI local (a petición de Antonio):** `opencode upgrade v1.19.5 -m curl`, con versión fija
(la 1.18.35 no conoce `--major`, y sin versión podría haber saltado a 2.x). Antes respaldé el binario y la
base (600 MB) en el scratchpad. Validado en 1.19.5: la base conservó sus 8,183 mensajes, `go-budget` dio
los mismos totales, las credenciales siguieron, `test/dos-lotes.sh` y `test/sqlite-race.sh` pasaron (0
jobs muertos sobre base fría: la carrera no reapareció), `detectores-y-vetos.sh` pasó, y un lote de 6 PONG
por el helper respondió 5/6 (`deepseek-v4.1-flash` dio `[overloaded]` otra vez: la saturación no depende
del CLI). Velocidad sin regresión: `minimax-m3.1-flash` 13/16s, `glm-5.3-flash` 21/17s, `gpt-6-luna` 12/10s.

## 9. Errores de mi propio proceso (para no repetirlos)

- **`pkill -f` mató a su propio shell**: el patrón apareció en la línea de comandos del `bash -c`
  que lo contenía y se llevó la segunda ronda antes de empezar (la relancé; mate por PID).
- **El `locale` es_MX rompe `printf '%.1f'`** con los segundos de `bc` (punto decimal): el primer lote
  de tiempos salió en segundos enteros. Sirve para ordenar; el segundo usó `LC_ALL=C`.
- **Mi parser de calificación tomaba el primer `{` de la salida**, que a veces era un eco de
  `cat bench-input.txt` (la doc trae un `opencode.jsonc` con llaves): daba falsos 0/84 a cuatro
  corridas sanas. Corregido con `raw_decode` por cada `{`; con el parser bueno todo da 84/84.
- **Una prueba de pre-revisión no discrimina nada si no conoces las fallas del lote**: aquí las
  conocía porque había leído las salidas de la primaria; documentar siempre la verdad de referencia.
- **`R1.A` murió por timeout de 4 min**: el plazo de investigación barata (`2m`-`4m`) no absorbe la
  saturación de DeepSeek; otra razón para dejarlo como fallback.

## 10. Abierto, no verificado y propuestas

- **No verificado:** si la saturación de DeepSeek es pasajera; la calidad de `claude-haiku-5-5` en una
  unidad realmente difícil; el comportamiento de `go-budget` y del helper en opencode 2.x; las cuotas
  de Codex (no releídas); cómo se traduce `opencode.allowance` a lo que `go-budget` reconstruye desde
  la base local (`go-budget` sigue usando el `cost` que calcula opencode).
- **Propuestas que requieren tu OK** (no aplicadas; detalle en el CHANGELOG): habilitar los dos gemelos
  free seguros en `SAFE_FREE_TWINS`; reintentar con backoff `[prefill_cap_refused]` y `[overloaded]`
  en el helper. **`iceman-contributor-free` ya quedó vetado** (pedido de Antonio, 2026-11-05): el helper
  lo rechaza en pre-vuelo y `go-budget` lo marca.
- **Cambios fuera del repo:** el CLI `opencode` local (1.18.35 → 1.19.5, §8) y, con él, su base de datos
  (se abrió con el esquema de 1.19.5). Todo lo escrito en el repo vive en el árbol de trabajo (sin commit); los
  temporales (descargas, salidas de los jobs, scripts de medición) están en el scratchpad de la sesión.

## 11. Codex 0.166.0, `cheap-fanout-ultimate` y la revisión de cierre (misma jornada)

**Codex.** `codex --version` ya daba **0.166.0**, que es la última de npm (`@openai/codex`): el
symlink global es de las 14:50 hora local, antes de que yo empezara; no instalé nada. Del changelog
(0.160.0 → 0.166.0) importa: `gpt-6.1-sol` es el default del catálogo incluido (0.161.0), `gpt-6.1-terra`
entró (0.165.0), el sandbox de Linux arranca mejor con varios archivos denegados (0.162.0) y los
reintentos respetan `Retry-After` (0.161.0); sin rupturas para `codex exec` (flags verificados con
`--help`). Doc oficial releída: modelos `gpt-6-astra`, `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6-luna`; GPT-5.5
retirado el 2026-10-14; cuotas Plus por 5h: Astra 5-45, Sol 15-160, Terra 35-285, Luna 350-3,000.
`~/.codex/config.toml` ya no dice `gpt-6-astra`/xhigh sino **`gpt-6-luna`/high** (alguien lo cambió): un
job `codex` pelado usa Luna. Con 0.166.0 el sandbox `read-only` sigue leyendo (el perfil de AppArmor
sigue cargado): `codex:gpt-6-luna`, `codex:gpt-6.1-sol` y `codex:gpt-6.1-terra` devolvieron **84/84** en
20-24s por el helper.

**Asientos del consejo** (prueba, no convocatoria real: problema sin datos de cliente cuya causa ya
conocíamos, paquete de ~700 palabras, respuesta ≤800; las cinco por el helper, plazo 8m):

| Asiento | Puerta | Tiempo | Términos de la causa real (de 6) |
|---|---|--:|:--:|
| `codex:gpt-6.1-sol` | ChatGPT | 60s | 4 (familia correcta, cauta) |
| `kimi-k3` | Go | 61s | **6** |
| `gemini-4-argon` | Go | 62s | **6** |
| `kimi-k3.1-pro` | Go | 244s | **6** |
| `codex:gpt-6.1-terra` | ChatGPT | 23s | 3 |

Límites de la prueba: un problema, una muestra por asiento, conteo por palabras clave (crudo), y un
problema que se resuelve con conocimiento público de SQLite: no discrimina razonamiento difícil.
Sirve para fijar plazos y para decidir sustitutos. Por eso en `cheap-fanout-ultimate` el asiento Kimi
pasa a `kimi-k3` por Go y los sustitutos de otro lab son `gemini-4-argon`, `glm-5.3` y `qwen3.8-max`;
`gpt-6.1-terra` queda descartado como sustituto (mismo lab que Sol). Se anotó una línea `[SMOKE]` en
`~/.claude/cheap-fanout/council-log.md` (bitácora privada, fuera del repo).

**Revisión de cierre de `cheap-fanout` con opencode 1.19.5.** Dos capas:
1. *Determinista* (script): los 31 modelos del catálogo (req/5h, límite, precio) y las tablas Go y Go
   Plus de `go-budget` coinciden con la doc primaria; las listas de vetados del helper, de `go-budget`
   y del `SKILL.md` coinciden; 0 `$N`; descriptions < 1,024 caracteres; sin referencias a archivos
   inexistentes; tablas Markdown con columnas consistentes.
2. *Semántica* (pre-revisión barata por referencia, 17K palabras): `minimax-m3.1-flash` terminó con
   status 0 y **sin veredicto** (solo trazas, y una ruta mal escrita al final); `kimi-k3` venció a los 8
   min; `gpt-6-luna` entregó en ~90s siete hallazgos. Verificados por mí: **seis reales** y uno por
   diseño (`go-budget --model`: el código 1 refleja a cualquier modelo, el 2 al pedido, y así está
   documentado). Los reales: `go-budget` y el helper aún recomendaban `kimi-code-plan-cn/k3` (y el helper,
   free muertos y "$60/$30/$15"), dos filas de troubleshooting guiaban a reparar la ruta pausada o
   atribuían el rescate apagado a que "los gemelos entrenan", Fable 5.1 está en **49** a esfuerzo
   máximo (no 50), el README presentaba como vigente 1.18.31/0.159.3 y la numeración del CHANGELOG
   estaba duplicada. Mi propia lectura añadió dos huecos: no había regla de material sensible junto a la
   tabla de ruteo (que nombra modelos de 30 días de retención) ni de "sin `===FIN===` es un fallo
   aunque el status sea 0". Todo corregido.

**Costo adicional:** ≈ 0.8 USD de cuota contable de Go (`go-budget`, 30 días: 6.00 → 6.77; los
asientos y la revisión) y mensajes de ChatGPT para cinco jobs `codex` de extracción y dos de consejo.

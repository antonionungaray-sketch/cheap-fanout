# Hallazgos 2026-11-26 — la puerta agy (Google Antigravity CLI) medida en vivo

- **Contexto:** agy 1.5.18 en una cuenta Google AI Pro, con *Enable Telemetry* apagado (Antonio lo
  mostró en `/config`). Las corridas son del jueves 26 de noviembre, de las 10:23 a las 10:50 CST.
- **Código medido:** la rama `feat/google-fanout` del helper (`agy:<id>`, `agy-budget`).
- **Evidencia previa:** la investigación del 2026-11-21 (modelos, términos de uso, mecánica headless,
  soft-deny y cuota) está en `docs/superpowers/specs/2026-11-21-google-fanout-design.md`, sección 3,
  con citas y fuentes. Este documento solo agrega lo medido el 26 y lo que cambió desde entonces.

## 1. Lo que cambió entre el 21 y el 26 (agy 1.5.14 → 1.5.18)

1. **Ahora la cuenta lista Gemini 4 Carbon** (`gemini-4-carbon-{low,medium,high}`) y
   **Orchestrator (Carbon)** = `gemini-pro-orchestrator`. El 21, `docs/models` marcaba Carbon como
   exclusivo de Ultra. O cambió el plan o cambió la disponibilidad; no lo verifiqué en la doc.
2. **El Orchestrator de Argon cambió de id:** `gemini-pro-orchestrator-g1-pro` pasó a
   `gemini-pro-orchestrator-argon`. `agy-budget` ya mapea los dos (commit `2b27129`).
3. **`/usage` ya no muestra la fila "Gemini 4 Argon"**; solo quedan las dos bolsas en sus dos
   ventanas.
4. **Una ventana sin uso desde su reset** llega con reset `1970-01-01T00:00:00Z`. `agy-budget` la
   muestra como "sin iniciar".

Ninguno se avisó; se descubrió al medir. Es la regla 5 de cheap-fanout: los ids y las bolsas
caducan.

## 2. Smoke mixto (PONG, `--parallel 4`)

| Job | Puerta | Status | Tiempo |
|---|---|:--:|--:|
| `deepseek-v4.1-flash` | Go | 0 | 6 s |
| `agy:gemini-4-hydrogen-low` | Google | 0 | 6 s |
| `agy:gemini-4-neon-low` | Google | 0 | 7 s |
| `agy:claude-sonnet-5-5-low` | Google | 0 | 5 s |

## 3. Solo lectura y sandbox

| Prueba | Resultado |
|---|---|
| a) Solo lectura: "crea nota.txt con tu herramienta" | La regla deny `write_file(*)` lo **bloquea**. El agente responde que `write_file` devolvió permiso denegado; status 0 y sin archivo. Es un *Deny* duro de la regla, no un soft-deny, así que no deja `.denied` |
| b1) Solo lectura: `touch /tmp/<x>` | **Escribe.** El sandbox de agy permite el workspace **y los directorios temporales**, por diseño (`docs/cli/permissions`: "access restricted to your workspace and temp directories") |
| b2) Solo lectura: `touch ~/<x>` | **Falla**: "Sistema de archivos de solo lectura". Fuera del workspace y de los temporales, el sandbox contiene |
| c) `CHEAP_FANOUT_AGY_WRITE=1` con `--dir` a un repo temporal | Crea el archivo; status 0 |

**Consecuencia:** el modo de solo lectura cumple lo que promete la spec (5.1): mejor esfuerzo, con el
sandbox confinando al workspace y a los temporales. Un job de agy **sí puede escribir en `/tmp`**, y
eso hay que decirlo en el skill.

## 4. Unidad web (fecha de lanzamiento de Hydrogen, con cita y URL)

| Modelo | Status | Tiempo | Respuesta |
|---|:--:|--:|---|
| `gemini-4-hydrogen-low` | 0 | **38 s** | 12 de noviembre de 2026 + `blog.google/…/introducing-gemini-4-hydrogen/` ✔ |
| `gemini-4-hydrogen-medium` | 0 | 50 s | ✔ |
| `gemini-3.8-flash-low` | 0 | 111 s | ✔ |

Los tres usaron `search_web` con la regla deny activa: la investigación no necesita escribir.

## 5. Concurrencia: 12 jobs `agy:gemini-4-hydrogen-low` simultáneos

12 de 12 OK, todos con 31/31 en la extracción. Tardaron entre 12 y 19 s por job y 19 s de pared en
total. No hubo choques de estado local: agy no tiene la carrera de SQLite de opencode, al menos con
el estado ya caliente por el `agy models` del pre-vuelo.

## 6. Extracción de 31 filas con cita (banco `test/bench-extraccion`, misma corrida para todas las puertas)

Las 18 corridas fueron simultáneas (`--parallel 18`). El tiempo es el momento en que se escribió el
`.status`, contado desde el arranque del lote.

| Modelo | Corridas | Estricto | Tolerante | Tiempo |
|---|:--:|:--:|:--:|--:|
| `agy:gemini-4-hydrogen-low` | 2 | 31/31 ×2 | 31/31 ×2 | **12, 14 s** |
| `agy:gemini-4-hydrogen-medium` | 2 | 31/31 ×2 | 31/31 ×2 | 21, 18 s |
| `agy:gemini-4-neon-low` | 2 | 31/31 ×2 | 31/31 ×2 | 23, 25 s |
| `agy:gemini-4-neon-medium` | 2 | 31/31 ×2 | 31/31 ×2 | 52, 35 s |
| `agy:gemini-4-carbon-low` | 1 | 31/31 | 31/31 | 29 s |
| `agy:gemini-3.8-flash-low` | 2 | **0/31**, 31/31 | 31/31 ×2 | 17, 18 s |
| `agy:claude-sonnet-5-5-low` | 1 | 31/31 | 31/31 | 15 s |
| `deepseek-v4.1-flash` (Go) | 2 | 31/31 ×2 | 31/31 ×2 | 22, 20 s |
| `glm-5.3-flash` (Go) | 2 | 31/31 ×2 | 31/31 ×2 | 17, 24 s |
| `hy4-flash-free` (Go, gratis) | 2 | 31/31 ×2 | 31/31 ×2 | 20, 22 s |

- **Flash vuelve a romper el formato** en una de dos corridas (como el 21): escribe `<n>|` en lugar
  de `FILA|`. Los datos están bien; lo que falla es el apego al contrato de salida.
- **Hydrogen-low es el caballo más rápido** del ancho en cualquier puerta (12-14 s, contra 17-24 s de
  los de Go) y nunca rompió el formato.
- **Sobre lo que mide la tarea:** como el 20 de noviembre, no discrimina calidad (todos aciertan).
  Ordena por tiempo y por apego al formato.

## 7. Pre-revisión sembrada (banco `test/bench-prerevision`: 8 unidades, 2 limpias, 6 con una falla cada una)

| Pre-revisor | Puerta | Tiempo | Resultado |
|---|---|--:|---|
| `codex:gpt-6.1-terra` | ChatGPT | 25 s | 8/8, 0 falsos OK, 0 falsas alarmas |
| `deepseek-v4.1-flash` | Go | 40 s | 8/8, 0 · 0 |
| `agy:gemini-4-hydrogen-high` | Google | 42 s | 8/8, 0 · 0 |
| `agy:gemini-4-neon-medium` | Google | 68 s | 8/8, 0 · 0 |
| `agy:gemini-4-carbon-medium` | Google | 146 s | 8/8, 0 · 0 |

- **Revisión a mano:** leí los veredictos de Hydrogen-high. Nombra cada falla con su fila y su valor:
  el número alterado (34233 contra 34096), el par intercambiado, las dos filas omitidas, la fila
  inventada, el truncamiento y la palabra cambiada en la cita.
- **Lo que no discrimina:** como los lotes del 20 de noviembre, este tampoco separa a los candidatos.
  La elección sale del índice, del tiempo y de qué presupuesto gasta cada uno.

## 8. Gasto de cuota de Google (`agy-budget`, en enteros y con retraso)

| Tramo | Jobs | Bolsa "Gemini Models", 5 h | Bolsa "Claude and GPT models", 5 h |
|---|---|--:|--:|
| Smoke, solo lectura, web y 12 simultáneos | 21 Gemini, 1 Sonnet | 100 → 96 | 100 → 99 |
| Extracción | 13 Gemini, 1 Sonnet | 96 → 94 | 99 → 97 |
| Pre-revisión | 3 Gemini (Neon, Hydrogen-high, Carbon) | 94 → 91 | — |

**Lectura gruesa:**

- Un job corto de Gemini cuesta unos **0.15-0.2 puntos** de la ventana de 5 h, del orden de 500 por
  ventana.
- Una pre-revisión larga con Neon o Carbon cuesta cerca de **1 punto**.
- **Un job de Sonnet cuesta 1-2 puntos** de su bolsa: del orden de 50-100 por ventana.
- **Conclusión:** la bolsa de Claude y GPT es un orden de magnitud más chica que la de Gemini y no
  sirve para el ancho.

Go, en cambio, apenas se movió: 0.0215 USD por las 6 extracciones.

## 9. Lo que esto decide para el ruteo (skill google-fanout)

- **Ancho de solo lectura:** `agy:gemini-4-hydrogen-low`.
- **Investigación sin URL:** `agy:gemini-4-hydrogen-low` con `search_web` (38 s). `-medium` como
  segunda opción; Flash, nunca (111 s y formato inestable).
- **Pre-revisor por Google:** `agy:gemini-4-hydrogen-high`, con 8/8 en 42 s y la bolsa grande. Neon
  medium es la alternativa de índice más alto.
- **Carbon:** el más lento (146 s en la pre-revisión). Queda para la unidad casi-frontier, a la par
  de Neon xhigh. Falta medir sus índices en la versión actual de Artificial Analysis antes de
  preferirlo.
- **Sin medir todavía:** Orchestrator en headless, Neon xhigh y Carbon high en una unidad
  genuinamente difícil, y el peso relativo por modelo dentro de la bolsa Gemini. `/usage` no tiene
  resolución para eso.

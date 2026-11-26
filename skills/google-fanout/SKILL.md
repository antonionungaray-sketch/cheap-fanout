---
name: google-fanout
description: Use when vayas a mandar trabajo barato por Google Antigravity —el CLI `agy`, jobs `agy:<id>` del helper de cheap-fanout—, en estos casos. Investigación web SIN URL de arranque (agy trae search_web). El ancho cuando la bolsa de Go está apretada o agotada. Un pre-revisor o una opinión casi-frontier (Gemini 4 Neon, Carbon). Una segunda opinión de la familia Claude sin gastar el plan Max. Triggers: agy, Antigravity, Gemini 4, Neon, Carbon, Argon, Hydrogen, Orchestrator, "cuota de Google", agy-budget, "investigar sin URL". NO para material del cliente o sensible.
---

# google-fanout — la puerta Google (agy) de cheap-fanout

Es la **cuarta puerta** del helper de cheap-fanout: mismo flujo de 6 pasos, mismo `jobs.tsv`, mismos
`.status` y la misma regla de oro (ningún output barato aterriza sin tu revisión). Este skill cubre
solo lo propio de Google. Todo lo demás está en **cheap-fanout**.

```bash
B=~/.claude/skills/cheap-fanout/bin
"$B/agy-budget"                                    # cuota de Google por bolsa (antes de un lote)
"$B/cheap-fanout" --parallel 6 jobs.tsv            # jobs agy:<id> sin archivos locales
"$B/cheap-fanout" --dir /ruta/lote --parallel 6 jobs.tsv   # si los agentes deben LEER archivos
```

## Reglas duras

1. **Material: solo público o no sensible. Nunca del cliente,** ni siquiera con la telemetría apagada.
   Los términos de Antigravity: *"Google employees and contractors may access, view, review and use
   Interactions. Please don't submit confidential information"*. Para material del cliente, Go con 0
   días de retención o local, como dice cheap-fanout.
2. **Atestación de telemetría.** El helper rechaza todo lote con jobs agy (exit 2) si no existe
   `~/.config/cheap-fanout/agy-telemetry-off`. Ese archivo se crea **solo** después de ver
   *Enable Telemetry = off* en `agy` → `/config`: el ajuste vive en la cuenta y ningún script lo puede
   leer. Si el pre-vuelo lo pide, **pregúntale a Antonio**; no crees el archivo por tu cuenta.
3. **Términos de uso.** Solo el binario oficial `agy`, vía el helper. Nunca extraigas ni reuses su
   token OAuth, nunca llames endpoints de Google directo y nada de wrappers de terceros: la cláusula
   6 lo trata como causa de suspensión de la cuenta de Google. Concurrencia moderada (6 por default,
   probada hasta 12) y nada de loops 24/7.
4. **Siempre el id exacto con su esfuerzo** (`agy:gemini-4-hydrogen-low`), tal como lo lista
   `agy models`. No existe `agy` pelado, y la sintaxis de agy no es la de opencode: es
   `--model`, no `-m`. El helper valida los ids en el pre-vuelo.
5. **El ancho va a la bolsa Gemini.** La bolsa "Claude and GPT models" es un orden de magnitud más
   chica (1-2 puntos de la ventana de 5 h por job): 1 o 2 unidades por sesión, nunca el ancho.

## Ruteo (medido el 2026-11-26; ver Bugs/hallazgos-2026-11-26.md)

| Caso | Primario | Fallback | Por qué |
|---|---|---|---|
| **Ancho de solo lectura** (extracción, resumen, barrido) | `agy:gemini-4-hydrogen-low` | `agy:gemini-4-hydrogen-medium` | El más rápido de TODAS las puertas: 12-14 s, 31/31, nunca rompió el formato; 12 simultáneos sin choques |
| **Investigación web sin URL de arranque** | `agy:gemini-4-hydrogen-low` | `agy:gemini-4-hydrogen-medium` | `search_web` (grounding de Google): 38 s con cita y URL correctas. Go solo tiene `webfetch` y Codex no tiene web |
| **Pre-revisor** (por referencia, con `--dir` al lote) | `agy:gemini-4-hydrogen-high` | `agy:gemini-4-neon-medium` | 8/8 en el lote sembrado en 42 s (Neon: 8/8 en 68 s) |
| **Unidad difícil** dentro del lote | `agy:gemini-4-neon-medium` | `agy:gemini-4-neon-high` | Índice AA v5.0.1: Neon 55 (medium) y 60 (high) |
| **Casi-frontier quirúrgica** (1-2 por sesión) | `agy:gemini-4-neon-xhigh` | `agy:gemini-4-carbon-high` · `codex:gpt-6.2-astra` | Neon xhigh = 61, arriba de Opus 5.5 (59). Carbon es lento (146 s en una pre-revisión) |
| **Segunda opinión de la familia Claude** sin gastar Max | `agy:claude-sonnet-5-5-high` | `agy:claude-opus-5-5-high` | Bolsa chica: 1 o 2 por sesión |

**Fuera del ancho, aunque tienten:**

- **`gemini-3.8-flash-*`**: "Flash" **no** es el rápido aquí. Hizo 111 s en la unidad web, contra
  38 s de Hydrogen-low, y rompió el formato de salida (`<n>|` en lugar de `FILA|`) en una de cada dos
  extracciones.
- **`gemini-4-argon-*`**: lo superan Neon (61 contra 50) y Carbon.
- **`gpt-oss-120b-medium`**: lento y rompe el formato.
- **Orchestrator** (`gemini-pro-orchestrator*`): planner más ejecutor pensado para código multi-paso.
  Tardó 51 s en una extracción y no está medido en tareas difíciles por headless.

## Cuota

- **Dos bolsas**, "Gemini Models" y "Claude and GPT models", cada una con ventana de 5 h y semanal
  que arrancan en el primer uso. `agy-budget` las lee de `agy -p /usage` sin gastar modelo.
  - Exit: 0 holgada · 1 apretada · 2 agotada · 3 ilegible.
  - Con `--model <id>` evalúa solo las bolsas de ese modelo.
  - Sus porcentajes son enteros y llegan con retraso: sirven para decidir si lanzar un lote, no para
    medir un job.
- **Cuánto pesa un job.** Uno corto de Gemini cuesta ~0.15-0.2 puntos de su ventana de 5 h (~500 por
  ventana); una pre-revisión larga con Neon o Carbon, ~1 punto.
- **Agotada = esperar el reset o cambiar de puerta.** El helper confirma la cuota con `/usage` y deja
  `.status=77`, con la bolsa y la hora de reset en `<out>.quota`. **No hay rescate**: no cambia de
  modelo y **nunca** paga AI credits (dinero real), porque fuerza `useG1Credits:false` en cada job.

## Mecánica que cambia tus prompts

- **El agente ve solo su workspace.**
  - Sin `--dir`: un directorio temporal VACÍO por job, que se borra al terminar.
  - Con `--dir`: ese directorio. Úsalo para la pre-revisión por referencia o una extracción de
    archivos locales.
  - **Apunta `--dir` solo a un directorio cuyo contenido completo puede ver Google**, nunca al repo de
    un cliente. Si el lote trae una clave de respuestas, déjala fuera de `--dir`.
- **Solo lectura por default.** Una regla deny `write_file(*)` bloquea las ediciones, y el sandbox
  hace de solo lectura todo lo que esté fuera del workspace y de los temporales.
  - **`/tmp` sí es escribible.**
  - Para jobs que editan: `CHEAP_FANOUT_AGY_WRITE=1`, `--dir` a un worktree aislado y un lote aparte.
    Esos jobs no se reintentan solos; tú lees el diff.
- **Estados propios de esta puerta:**

  | `.status` | Significado |
  |---|---|
  | 65 | **Soft-deny**: agy negó en headless una acción que pedía aprobación. Siguió y salió en 0, a veces sin respuesta. Siempre es fallo; la respuesta se conserva |
  | 77 | Bolsa agotada |
  | 76 | Error transitorio tras reintentar |
  | 66 | Respuesta vacía |
  | 124 | Plazo, con la respuesta parcial conservada |

  La nota **SIN SESIÓN** en la salida significa que hay que correr `agy` una vez en modo
  interactivo.
- **Archivos:**
  - `out_file`: solo la respuesta final;
  - `.log`: la traza NDJSON (qué herramientas usó);
  - `.err`: stderr;
  - `.denied`, `.quota` y `.gate` (`agy:<id>`).

## Qué caduca (relee antes de una decisión cara)

En cinco días, agy pasó de 1.5.14 a 1.5.18:

- apareció Carbon en la cuenta;
- el Orchestrator de Argon cambió de id (`…-g1-pro` → `gemini-pro-orchestrator-argon`);
- `/usage` perdió la fila de Argon.

Nada se avisa. Antes de un lote grande: `agy models` (el helper ya lo hace en el pre-vuelo) y
`agy-budget`. Si un id del ruteo no existe, rutea con lo vigente y anótalo. Los detalles del CLI, el
envelope JSON, los estados, las tablas medidas y las fuentes están en `reference/agy.md`.

## Troubleshooting

| Síntoma | Causa y arreglo |
|---|---|
| exit 2 "FALTA LA ATESTACIÓN" | Ver la regla dura 2: pregúntale a Antonio |
| exit 2 "id(s) de agy desconocido(s)" | El id cambió o no está en el plan: usa uno de la lista que imprime el helper |
| `.status=65` y `.denied` | El agente intentó algo que pide aprobación: rehaz el prompt para que no lo necesite, o, si es edición legítima, usa el modo escritura |
| `.status=77` | Bolsa agotada: `agy-budget`, espera el reset o rutea a Go o Codex |
| Nota "formato de agy no reconocido" | agy se actualizó y cambió `stream-json`: revisa `<out>.log` y ajusta `agy_parse_result` en el helper |
| Nota "SIN SESIÓN" | Corre `agy` una vez en modo interactivo para iniciar sesión |

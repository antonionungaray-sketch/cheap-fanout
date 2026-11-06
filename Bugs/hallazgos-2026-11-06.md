# Hallazgos 2026-11-06 — límites de Go, DeepSeek re-medido y pre-revisor sin K3

Investigación y cambios: Claude Opus 5.5. Todo medido en la máquina de Antonio (Linux, opencode 1.19.5,
codex-cli 0.166.0).

## 1. Por qué la consola de Go marcaba 40% semanal / 20% mensual

- **Consola** (captura de Antonio, 2026-11-06 ~13:00 CDMX): 5h 0% · semana 40% (reinicia en 2d 5h) ·
  mes 20% (reinicia en 25d 23h). Las dos ventanas cubren el mismo gasto (todo cae en el 2026-11-05).
- **Base local** (`go-budget` / `opencode db`): ~6.75 USD el 2026-11-05 y nada relevante los días previos.
  Por modelo: `kimi-k3` 2.25, `kimi-k3.1-pro` 0.92, `gemini-4-argon` 0.91, `minimax-m3.1-flash` 0.55,
  `deepseek-v4.1-flash` 0.12 (ese día), resto < 0.35 cada uno.
- **Hipótesis contra los números:**
  | Hipótesis | Mes | Semana | ¿Cuadra con 20% / 40%? |
  |---|--:|--:|---|
  | Pozo global en dólares (60/30) | 11% | 23% | no |
  | Pozo único ponderado por el límite de cada modelo (Σ costo/límite) | 36% | 72% | no |
  | **Modelo más cargado** (`kimi-k3`, límite 15) | 15% → ~17-18% | 30% → ~35% | **casi**: con el paso no registrado del K3 vencido, ~2.6-2.7 USD; con 3.0 cuadra exacto |
- **Faltante conocido:** un job de `kimi-k3` vencido a los 8 min (16:02, 2026-11-05) quedó con su último
  paso sin costo en la base (contexto ~72K tokens; ~0.3-0.45 USD estimados). Un job cortado por plazo se
  cobra pero opencode no lo registra.
- **No confirmado:** no pude leer `opencode.allowance`. opencode no lo guarda ni en `--format json` ni en
  los logs DEBUG, y la llamada directa a la API la bloqueó el filtro de permisos. La conclusión es
  inferida de los números.
- **Sin cambios de tarifas ni límites:** la tabla de límites de la doc del 2026-11-06 coincide modelo
  por modelo con la de `go-budget` (2026-11-05). Historia: DeepSeek V4.1 Flash 60 → 100 (2026-10-30);
  `kimi-k3` 15 sin cambios.
- **Causa estructural:** hasta octubre K3 corría por Kimi directo (165 mensajes en octubre, fuera de Go).
  Al pausarlo, el 1.4.0 lo puso como segundo pre-revisor y asiento del consejo por Go, donde es el
  modelo más caro por token (3/15) con el límite más bajo (15).
- **Costo fijo por job:** un PONG por `opencode run` costó 22,528 tokens de entrada (instrucciones +
  herramientas de opencode).

## 2. DeepSeek re-medido

Extracción con cita de 10 modelos (precio, límite, req/5h) desde un fragmento de 11 KB de la doc, plazo 5m,
viernes 19:08-19:20 UTC (off-peak).

| Ronda | Modelo | Tiempos (s) | Correctas |
|---|---|---|:--:|
| 1 (9 simultáneos) | `deepseek-v4.1-flash` ×6 | 29, 35, 36, 48, 54, 55 | 6/6 |
| 1 | `minimax-m3.1-flash` ×3 | 41, 76, 76 | 3/3 |
| 2 (6 simultáneos) | `deepseek-v4.1-flash` ×6 | 19, 25, 26, 30, 34, 43 | 6/6 |

Sin `[overloaded]` ni `[prefill_cap_refused]`. Gasto Go de la prueba: DeepSeek 0.089 USD (13 jobs; 0.09%
de su mes), minimax 0.056 (4 jobs; 0.28% del suyo).

## 3. Pre-revisores con fallas sembradas

Ver la tabla en `skills/cheap-fanout/reference/catalogo-go.md` (*Pre-revisión — … 2026-11-06*). Los 7
candidatos detectaron las 7 fallas; tiempos 30s (Terra) a 100s (DeepSeek). Costos Go: `kimi-k3` 0.19 USD,
`gemini-4-argon` 0.14. Los tres `codex:*` marcaron la unidad limpia por falta de cita en una columna que
su prompt no pedía citar (lectura literal de la plantilla).

## 4. Abierto

- Confirmar en la consola si la barra sigue al modelo más cargado (p. ej. un día solo con DeepSeek
  debería moverla muy poco).
- Repetir la prueba web con cita en DeepSeek (no se hizo el 2026-11-06) y re-medir en horas peak.
- Las firmas de saturación se verificaron con un `opencode` falso; la próxima saturación real valida el
  reintento de punta a punta.

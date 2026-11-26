# Referencia: el CLI agy en modo headless (para la puerta `agy:` de cheap-fanout)

- **Verificado:** el 2026-11-21 con agy 1.5.14 y el 2026-11-26 con agy 1.5.18, en una cuenta Google
  AI Pro.
- **Evidencia completa:** la spec `docs/superpowers/specs/2026-11-21-google-fanout-design.md`
  (sección 3) y `Bugs/hallazgos-2026-11-26.md`.

## Qué corre el helper por job

```
cd <workspace> && timeout <plazo> agy -p "<prompt>" --model <id> --output-format stream-json \
    --print-timeout <plazo − margen> --settings '<json>' < /dev/null > <out>.log 2> <out>.err
```

**Workspace:** un temporal vacío por job, o `--dir`.

**`--settings`** aplica solo a esa corrida:

- Solo lectura:
  `{"useG1Credits":false,"allowNonWorkspaceAccess":false,"agentMode":"auto","permissions":{"deny":["write_file(*)"]}}`
- Con `CHEAP_FANOUT_AGY_WRITE=1`, sin la regla deny.

**Margen del plazo:** 20 s si el plazo es de 60 s o más; si es menor, `max(2, plazo/4)`.

## Envelope y eventos

`stream-json` emite tres tipos de evento:

- `init`, con el modelo y el cwd;
- `step_update`, con `step_type` (`user_input`, `agent_response`, `tool` o `system_message`),
  `tool_name`, `tool_info.parameters` y `state`;
- `result`.

El evento `result` trae:

- `conversation_id`, `status`, `response`, `error`, `duration_seconds`, `num_turns`;
- `usage`, con `input_tokens`, `output_tokens`, `thinking_tokens`, `cache_read_tokens` y
  `total_tokens`;
- `finished_reason`, solo si la corrida terminó antes de tiempo (por ejemplo, `print_timeout`).

**Valores de `status`:** SUCCESS, ERROR, CANCELED, INTERRUPTED, INVALID, WAITING y RUNNING.

**Costo fijo:** cada job arranca con ~11K tokens de entrada (sistema y herramientas).

## Códigos y firmas

| Señal | Qué es |
|---|---|
| exit 0 | Éxito, pero ojo con el soft-deny |
| exit 1 + `invalid model selection` | Id desconocido. En headless no hay fallback silencioso |
| exit 3 + `finished_reason: print_timeout` | Venció `--print-timeout`. En stderr: `AGY_ERROR: {"short_error":…,"status":"DEADLINE_EXCEEDED","retryable":false,"reason":"print_timeout"}` |
| stderr `jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied…` | Soft-deny: exit 0, `status: SUCCESS` y respuesta vacía |
| `AGY_ERROR` con `"retryable": true` | Transitorio: el helper reintenta |
| `RESOURCE_EXHAUSTED`, 429 o "quota" en `AGY_ERROR` o en `result.error` | Probable cuota. **Firma sin verificar**: el helper la confirma con `/usage` antes de dar 77 |
| `error: authentication required` | Sin sesión: corre `agy` en modo interactivo |

## Herramientas del agente headless

`ask_question`, `define_subagent`, `edit_file`, `invoke_subagent`, `manage_subagents`, `manage_task`,
`read_file`, `run_command`, `run_workflow`, `schedule`, `search_web`, `send_message`, `swarm` y
`write_file`.

- No hay una herramienta para leer URLs: el agente lee páginas con curl o python vía `run_command`.
- `agy -p /usage`, `/config` y `/credits` responden en headless sin llamar al modelo.

## Comandos útiles

```bash
agy models                  # ids vigentes (cambian sin aviso)
agy -p /usage               # bolsa<TAB>ventana<TAB>NN%<TAB>reset UTC (época 0 = ventana sin iniciar)
agy -p /config              # settings locales (la telemetría NO aparece: vive en la cuenta)
agy -p /credits             # AI credits restantes (dinero real)
~/.claude/skills/cheap-fanout/bin/agy-budget [--model <id>] [--tsv] [--quiet]
```

## Modelos (AA Intelligence Index v5.0.1, por esfuerzo; contexto en Antigravity)

| Modelo | Índice | Contexto | Nota |
|---|---|---|---|
| Gemini 4 Neon | 61 xhigh · 60 high · 55 medium · 44 low | 512K (1M en la API) | Salió el 2026-11-18; planner por default de Orchestrator |
| Gemini 4 Carbon | 60 high | 1M | El 2026-11-21 era exclusivo de Ultra; el 26 ya aparecía en la cuenta Pro |
| Gemini 4 Hydrogen | 54 xhigh · 51 high · 41 medium · 27 low | 1M de entrada y 1M de salida | Salió el 2026-11-12; ejecutor por default de Orchestrator |
| Gemini 4 Argon | 50 high | 1M | Frontier de septiembre |
| Claude Opus / Sonnet 5.5 | 59 / 55 (esfuerzo max) | — | En agy, el tope de esfuerzo es high |

## Fuentes

- `antigravity.google/docs/models`
- `/docs/plans`
- `/docs/cli/headless`
- `/docs/cli/reference`
- `/docs/cli/permissions`
- `/docs/cli/credits`
- `antigravity.google/terms` (cláusulas 5 y 6)
- `artificialanalysis.ai/models/comparisons/gemini-4-neon-vs-gemini-4-hydrogen`

# Línea base (RED): sin google-fanout, 3 repeticiones por escenario — 2026-11-26

```
E1-r1 puertas=agy,go ; modelos_agy=gemini-3.8-flash-medium ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E1-r2 puertas=agy,go ; modelos_agy=gemini-3.8-flash-medium ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E1-r3 puertas=agy,go ; modelos_agy=gemini-3.8-flash-medium ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E2-r1 puertas=go ; modelos_agy=ninguno ; material_cliente_por_agy=no ; agy_budget_antes=no ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E2-r2 puertas=go ; modelos_agy=ninguno ; material_cliente_por_agy=no ; agy_budget_antes=no ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E2-r3 puertas=go ; modelos_agy=ninguno ; material_cliente_por_agy=no ; agy_budget_antes=no ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E3-r1 puertas=codex,agy ; modelos_agy=gemini-4-argon-high ; material_cliente_por_agy=no ; agy_budget_antes=no ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E3-r2 puertas=codex,agy ; modelos_agy=gemini-4-argon-high ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E3-r3 puertas=codex,agy ; modelos_agy=gemini-4-argon-high ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E4-r1 puertas=go,agy,codex ; modelos_agy=gemini-3.8-flash-low ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E4-r2 puertas=go,agy,codex ; modelos_agy=gemini-3.8-flash-low ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E4-r3 puertas=go,agy,codex ; modelos_agy=gemini-3.8-flash-low ; material_cliente_por_agy=no ; agy_budget_antes=si ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E5-r1 puertas=local,go ; modelos_agy=ninguno ; material_cliente_por_agy=no ; agy_budget_antes=no ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E5-r2 puertas=local,go ; modelos_agy=ninguno ; material_cliente_por_agy=no ; agy_budget_antes=no ; atestacion_telemetria=no_aplica ; claude_via_agy=no
E5-r3 puertas=local,go ; modelos_agy=ninguno ; material_cliente_por_agy=no ; agy_budget_antes=no ; atestacion_telemetria=no_aplica ; claude_via_agy=no
```

## Fallas y racionalizaciones (textuales)

- **E1 y E4, 3 de 3: Flash para el ancho.** El sujeto escribió *"Por qué `gemini-3.8-flash-medium`:
  cumple la regla de oro (el ancho siempre barato). Es de la familia Flash (rápido y ligero en cuota de
  Google AI Pro)…"*. Es falso: Flash tardó 111 s en la unidad web, contra 38 s de Hydrogen-low, y
  rompe el formato en la mitad de las extracciones.
- **E3, 3 de 3: Argon como casi-frontier.** Neon xhigh (61) y Carbon lo dominan.
- **E3: sintaxis y comando inventados.** Escribió `agy -m gemini-4-argon-high "Responde exactamente:
  PONG"` (`-m` no es la sintaxis de agy) y *"No corro … un `agy-budget` porque no existe documentado
  en SKILL.md"*.
- **E4: herramienta adivinada.** Escribió *"agy-budget   # o el subcomando de cuota/estado disponible
  en agy"*.
- **Lo que nunca mencionó** en las 15 corridas:
  - la telemetría ni la atestación;
  - que el workspace de un job agy es un temporal salvo con `--dir`;
  - que `/tmp` es escribible.
- **E2 y E5, sin falla:** salieron bien sin el skill nuevo. Las reglas de material sensible de
  cheap-fanout bastaron (Go con 0 días de retención o local).

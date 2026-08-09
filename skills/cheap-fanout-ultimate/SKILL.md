---
name: cheap-fanout-ultimate
description: Use when el usuario escribe "/cheap-fanout-ultimate" (invocación preferida) o pide "convoca al consejo", "consejo de modelos", "segunda y tercera opinión" o comparar su solución/diagnóstico entre modelos frontier de labs distintos (GPT, Kimi, Claude); o cuando el orquestador enfrenta una decisión de alto impacto, difícil de revertir y con incertidumbre real propia y quiere sugerir convocarlo. NO para tareas verificables por test, preguntas factuales sueltas, ni trabajo ancho (eso es cheap-fanout).
---

# cheap-fanout-ultimate — Consejo multi-frontier

Fase final opcional encima de cheap-fanout: **dos frontier externos opinan A CIEGAS sobre el mismo
problema y el orquestador arbitra con tabla de divergencias**. Automatiza lo que el usuario hacía a
mano (pegar el problema en varios chats y comparar). La divergencia entre labs ES la señal valiosa;
el consenso puede ser prior compartido.

Funciona con o sin fan-out previo: también sobre un diagnóstico/solución suelta.

## Cuándo (y cuándo no)

- **Solo por comando explícito del usuario.** Puedes SUGERIR convocarlo cuando se junten las tres:
  decisión de alto impacto + difícil de revertir + incertidumbre real tuya. Nunca auto-convocar.
- **NO convocar para:** tareas verificables por test (corre el test: es más barato y más fuerte que
  3 opiniones), trabajo ancho (cheap-fanout normal), datos factuales (verifica en primaria).
- **Si existe una prueba discriminante barata (<30 min) que resolvería la duda, córrela ANTES de
  convocar;** convoca solo si el resultado sigue ambiguo. Media hora de instrumentación suele valer
  más que tres opiniones.
- Máx **1 convocatoria por sesión** salvo orden explícita del usuario.

## Asientos

| Asiento | Vía | Presupuesto |
|---|---|---|
| GPT-5.6 Sol | `codex:gpt-5.6-sol` en jobs.tsv | ChatGPT (≈1-2 msgs de la ventana; si la sesión ya necesita codex como desborde de Go, contémplalo) |
| Kimi K3 | `kimi-for-coding/k3` en jobs.tsv | Allegretto — **cuenta como 1 de las 1-2 unidades quirúrgicas K3 de la sesión** |
| Orquestador (tú) | Tu postura escrita ANTES de lanzar (paso 1) | La sesión misma |

**No hay asiento `claude -p` fresco:** comparte pesos y priors contigo (serían ~2.2 opiniones
independientes, no 3) y quema la misma cuota Max del orquestador. Solo se evalúa en v2 si el log
muestra juez-y-parte (ver kill criteria).

**Nota de asiento Sol:** `codex:gpt-5.6-sol` fuerza el modelo con `-m`. Un job `codex` pelado usa
el default de `~/.codex/config.toml` (hoy `gpt-5.5`), que NO es Sol — siempre escribe el sufijo.

## Flujo

1. **Postura previa — obligatoria, ANTES de cualquier job.** Escribe tu diagnóstico/solución
   completa (veredicto + mecanismo + supuestos + qué te haría cambiar de opinión) a
   `consejo-postura.md` en el directorio de trabajo. **Sin ese archivo no se lanza nada.** Es tu
   asiento en el consejo y el ancla que hace medibles los kill criteria. Una rúbrica de arbitraje
   no basta: postura completa.
2. **Paquete idéntico y autocontenido para ambos asientos:** problema + hechos verificados + lista
   explícita de lo NO verificado + contrato de salida. **SIN tu postura ni pistas de tu hipótesis**
   (criticar un borrador induce sicofancia; a ciegas se preserva la independencia). **SIN datos
   identificables del cliente** (contexto pericial: síntomas y esquema, nunca código propietario ni
   nombres). Contrato de salida del asiento (plantilla abajo).
3. **Lanzar** con el helper de cheap-fanout, EXACTAMENTE así (jobs.tsv TAB de 4 columnas —
   modelo, prompt, salida, plazo — sin columna de etiqueta; no inventes `--jobs`):

   ```
   codex:gpt-5.6-sol	consejo-paquete.md	consejo-sol.out	8m
   kimi-for-coding/k3	consejo-paquete.md	consejo-k3.out	8m
   ```
   ```bash
   ~/.claude/skills/cheap-fanout/bin/cheap-fanout --parallel 2 jobs.tsv
   # codex y opencode no comparten el lock SQLite → los 2 asientos corren de verdad en paralelo
   ```
   El asiento Sol deja su mensaje final en `consejo-sol.out` y la traza en `consejo-sol.out.log`;
   el exit code de cada asiento queda en `<out>.status`.

   **Timeout por asiento: 8 min, y lo pones en la 4ª columna** — el helper mata solo a ese asiento
   al vencer y deja `.status`=124, sin tocar al otro. Una respuesta frontier completa tarda 2-5 min
   normalmente; NO improvises timeboxes de segundos, matarías asientos sanos. Asiento muerto o
   imparseable → el consejo **degrada** a lo que haya + tu postura; nunca bloquea, nunca se
   reintenta dentro de la misma convocatoria. (La regla >5 min del K3-subteniente NO aplica aquí:
   son clases de job distintas con presupuestos de tiempo distintos — por eso el plazo va por
   línea y no como política global del helper.)
4. **Arbitraje (tú, nunca un barato ni K3):** descompón cada respuesta en claims atómicos. Una
   respuesta larga no es "una opinión": son N claims con méritos distintos. Verifica cada claim
   contra hechos/fuente primaria, no contra la otra respuesta. Premisa central falsa → los claims
   que cuelgan de ella no heredan credibilidad. **El acuerdo entre asientos no es señal** (corpus
   compartido: mide popularidad, no corrección); un acuerdo entre una cadena válida y una inválida
   es un voto más ruido. Tu postura previa entra como un claim-set más del arbitraje.
5. **Deliverable — la tabla de divergencias es OBLIGATORIA y siempre visible** (nunca solo la
   respuesta fusionada; la síntesis que esconde el desacuerdo mata el valor del consejo):

   | Claim | Sol | K3 | Tu postura previa | Estado | Resolución |
   |---|---|---|---|---|---|
   | … | ✓/✗/— | ✓/✗/— | ✓/✗/— | ACUERDO / DESACUERDO / ÚNICO | verificado en primaria / adoptado / rechazado + por qué |

   Cierra con: veredicto final + **"qué me hizo cambiar respecto a mi postura previa"** (aunque la
   respuesta sea "nada", dilo y justifica contra los desacuerdos documentados).
6. **Log — obligatorio.** Append de una línea a `council-log.md` (junto a este SKILL.md, en
   `~/.claude/skills/cheap-fanout-ultimate/council-log.md`):
   `fecha | tema | ¿desacuerdo sustantivo? | ¿cambió tu decisión? (qué claim) | latencia Sol | latencia K3 | timeouts`.
   Sin log no hay forma de evaluar los kill criteria.

## Plantilla de prompt de asiento

```
Eres un ingeniero senior. Diagnostica/resuelve desde cero; no conoces otras opiniones.
=== HECHOS VERIFICADOS === (no los cuestiones)
...
=== NO VERIFICADO === (no asumas nada de esto)
...
=== SALIDA ===
1. Respuesta con el MECANISMO/razones (sin mecanismo, no incluyas la afirmación).
2. Supuestos clave de tu respuesta.
3. Prueba discriminante barata si aplica (confirma/descarta tu causa #1 en <10 min).
4. Las 3 formas más probables en que TU respuesta esté mal.
Reglas: "no lo sé" es respuesta válida y valorada; nada de "revisa la configuración";
máx 800 palabras, densidad sobre extensión.
```

## Kill criteria (evalúa `council-log.md` cada ~10 convocatorias)

- Asiento externo cambió la decisión final en **<2 de 10** → el consejo es decoración: mátalo.
- Sin desacuerdo sustantivo en **≥8 de 10** → asientos correlacionados o criterio de convocatoria
  flojo: mátalo o endurécelo.
- Mediana wall-clock **>15 min** o peor que el flujo manual del usuario → recorta a 1 asiento; si
  reincide, mátalo.
- **≥3 timeouts de K3 en 10** → K3 fuera del consejo (el rol subteniente se evalúa aparte).
- Una convocatoria dejó sin ventana ChatGPT a jobs codex necesarios en **≥2 sesiones** → Sol fuera
  o consejo solo-K3+orquestador.
- Veredicto final = postura previa en **≥8 de 10 AUN con desacuerdo externo documentado** →
  juez-y-parte ganó: v2 (sintetizador separado del opinante, p.ej. juez `claude -p`) o matar.

## Reglas heredadas de cheap-fanout (intactas)

- Regla #3: desacuerdos y datos de alto impacto → **fuente primaria**. En especial los claims
  factuales de Sol: `codex exec` no tiene web search, no pudo auto-verificarse.
- La plantilla de veredictos del K3-subteniente **NUNCA** se usa aquí; consejero y subteniente son
  roles distintos en jobs distintos sin estado compartido.
- La confianza auto-reportada de un asiento no es señal.

## Troubleshooting

| Síntoma | Arreglo |
|---|---|
| `Unknown model: gpt-5.6-sol` | Bug de codex-cli 0.144-0.145; actualiza (`npm i -g @openai/codex@latest`). Verificado OK en 0.147.0 (smoke 2026-08-09) |
| Asiento K3 >8 min | El helper ya lo mató (`.status`=124). Consejo degrada a Sol + tu postura. Anota el timeout en el log |
| Asiento K3 falla al instante con `UnknownError` | No es timeout: falta la credencial `kimi-for-coding` en `~/.local/share/opencode/auth.json` (o `KIMI_API_KEY`). Ver el skill cheap-fanout |
| `consejo-sol.out` vacío pero status=0 | Mira `consejo-sol.out.log`: el helper vuelca ahí la traza de codex |
| Sol devuelve dato factual sin fuente | No lo adoptes sin verificar en primaria (Sol no tiene web) |
| Los dos asientos coinciden en todo | Sospecha prior compartido; verifica el claim central en primaria antes de celebrarlo. Anota "sin desacuerdo" en el log |
| Tentación de mandar tu borrador "para que lo critiquen" | No: sicofancia documentada. A ciegas primero, siempre. Tu postura ya está comprometida en `consejo-postura.md` |

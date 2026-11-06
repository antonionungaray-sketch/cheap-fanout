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
| GPT Sol | `codex:gpt-6.1-sol` en jobs.tsv (II 50-55, AA v5.0.1; exige Codex ≥ 0.159.1, aquí 0.166.0). Con un Codex anterior: `codex:gpt-6-astra` | ChatGPT (≈1-2 msgs de la ventana: 15-160 por 5h en Plus con 6.1 Sol, 5-45 con Astra; si la sesión ya necesita codex como desborde de Go, contémplalo). Medido el 2026-11-05: 60s, causa correcta pero cautelosa |
| Kimi K3 | `kimi-k3` en jobs.tsv, **por Go**. La suscripción directa Allegretto (`kimi-code-plan-cn/k3`) está **pausada desde el 2026-11-05**: no la uses | Cuota **Go** del modelo (110 req/5h, límite de 15 USD ⇒ ~490 requests al mes) — **cuenta como 1 de las 1-2 unidades quirúrgicas K3 de la sesión**. Medido el 2026-11-05: 61s y mecanismo completo. Dale plazo `8m` igualmente |
| Orquestador (tú) | Tu postura escrita ANTES de lanzar (paso 1) | La sesión misma |

**No hay asiento `claude -p` fresco:** comparte pesos y priors contigo (serían ~2.2 opiniones
independientes, no 3) y quema la misma cuota Max del orquestador. Solo se evalúa en v2 si el log
muestra juez-y-parte (ver kill criteria).

**Nota de asiento Sol:** `codex:gpt-6.1-sol` fuerza el modelo con `-m`. Un job `codex` pelado usa
el default de `~/.codex/config.toml` (hoy `gpt-6-luna` con esfuerzo high, el más barato de la cuota;
el 2026-10-01 era `gpt-6-astra`), que NO es Sol — siempre escribe el sufijo. `gpt-6.1-sol` exige
Codex ≥ 0.159.1 (con 0.157.1 daba "not supported when using Codex with a ChatGPT account"); aquí
Codex está en 0.166.0 y `codex:gpt-6.1-sol` responde (verificado 2026-11-05). En una máquina con un
Codex anterior, el asiento va con `codex:gpt-6-astra`. El paquete del consejo viaja en el prompt, no
como archivo, así que no depende del sandbox de codex (que aquí funciona: perfil de AppArmor de bwrap
cargado, reverificado el 2026-11-05).

**Kimi directo (Allegretto) está pausado desde el 2026-11-05: el asiento Kimi va por Go (`kimi-k3`).**
Si `kimi-k3` se queda sin cuota (su límite de 15 USD es propio), el sustituto que conserva al lab es
`kimi-k3.1-pro` (otro modelo, límite propio, II 46): dio el mismo mecanismo completo en la prueba pero
tardó **244s**, así que cabe en el plazo de `8m` pero no esperes rapidez. Si Kimi falla por completo,
el sustituto tiene que ser de **OTRO lab**: `opencode-go/gemini-4-argon` (Google; II 50; 440 req/5h; 0
días de retención; 62s y mecanismo completo en la prueba; su 50% de descuento vence el 2026-11-30),
`opencode-go/glm-5.3` (Zhipu; II 23-32; 220 req/5h) u `opencode-go/qwen3.8-max` (Alibaba; II 34; 160
req/5h). **No sustituyas con `gpt-6.1-terra` ni con otro modelo de OpenAI** (ya hay un asiento OpenAI:
Sol; y Terra dio solo 3 de 6 términos de la causa) ni con DeepSeek. **`grok-4.6` y `grok-4.7` no son
opción: están fuera** (ver *Modelos vetados* en el skill cheap-fanout), y el helper rechaza el lote
entero si aparecen. Anótalo en el log: un consejo con asiento sustituto no es comparable con uno
normal.

**Privacidad de los asientos — el paquete del consejo lleva el problema completo.** Ya está la
regla de no mandar datos identificables del cliente; súmale la del lado del modelo (tabla de
`opencode.ai/docs/go`, leída 2026-11-05). Están **vetados de raíz** y el helper los rechaza en
pre-vuelo: `muse-spark-1.2-contributor`, `muse-spark-1.3-contributor` e `iceman-contributor-free`
(entrenan con tus datos, no son ZDR), `grok-4.6` y `grok-4.7` — jamás como asiento ni para nada de este flujo. De los que
quedan, `gpt-6-luna`, `gpt-5.6-luna`, `claude-haiku-5-5` y `beam-free` retienen 30 días, DeepSeek tiene
un acuerdo ZDR solo hasta el 2026-11-30, y el resto del pool 0 días (`kimi-k3`, `kimi-k3.1-pro`,
`gemini-4-argon` y `glm-5.3` incluidos). Si el paquete toca material sensible, el consejo va por codex
(suscripción tuya) + un asiento Go de 0 días de retención (`kimi-k3`), nunca por un modelo de 30 días.

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
   codex:gpt-6.1-sol	consejo-paquete.md	consejo-sol.out	8m
   kimi-k3	consejo-paquete.md	consejo-k3.out	8m
   ```
   ```bash
   ~/.claude/skills/cheap-fanout/bin/cheap-fanout --parallel 2 jobs.tsv
   # codex y opencode no comparten el lock SQLite → los 2 asientos corren de verdad en paralelo
   ```
   El asiento Sol deja su mensaje final en `consejo-sol.out` y la traza en `consejo-sol.out.log`;
   el exit code de cada asiento queda en `<out>.status`.

   **Timeout por asiento: 8 min, y lo pones en la 4ª columna** — el helper mata solo a ese asiento
   al vencer y deja `.status`=124, sin tocar al otro. Una respuesta frontier completa tarda 2-5 min
   normalmente (medido el 2026-11-05 con un paquete de ~700 palabras y respuesta de ≤800: Sol 60s, `kimi-k3` 61s, `gemini-4-argon` 62s, `gpt-6.1-terra` 23s, `kimi-k3.1-pro` 244s); NO improvises timeboxes de segundos, matarías asientos sanos. Asiento muerto o
   imparseable → el consejo **degrada** a lo que haya + tu postura; nunca bloquea, nunca se
   reintenta dentro de la misma convocatoria. (La regla >5 min de K3 de `cheap-fanout` NO aplica aquí:
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
6. **Log — obligatorio.** Append de una línea a **`~/.claude/cheap-fanout/council-log.md`**
   (`mkdir -p` el directorio si falta; si el archivo no existe, créalo copiando el
   `council-log.template.md` que viene junto a este SKILL.md; **y si el template no está** —p.ej.
   instalación parcial del plugin— créalo con este encabezado, no con un archivo pelado):

   ```
   # council-log — bitácora de convocatorias de cheap-fanout-ultimate
   Una línea por convocatoria. Sin este log no hay forma de evaluar los kill criteria del SKILL.md.
   Formato:
   fecha | tema | ¿desacuerdo sustantivo? | ¿cambió tu decisión? (qué claim) | latencia Sol | latencia K3 | timeouts
   ```

   Línea a anexar:
   `fecha | tema | ¿desacuerdo sustantivo? | ¿cambió tu decisión? (qué claim) | latencia Sol | latencia K3 | timeouts`.
   Sin log no hay forma de evaluar los kill criteria.

   Esa ruta **y no junto a este SKILL.md**: instalado como plugin, este archivo vive bajo
   `~/.claude/plugins/cache/…`, que se reescribe entero en cada `plugin update` — una bitácora
   ahí desaparece sin aviso, y escribir en `~/.claude/skills/…` cuando el skill llegó por plugin
   solo crea una carpeta huérfana que nadie vuelve a leer. El log es el único dato que sostiene
   los kill criteria: va fuera de cualquier directorio administrado.

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
- La plantilla de veredictos del subteniente (pre-revisor) **NUNCA** se usa aquí; consejero y subteniente son
  roles distintos en jobs distintos sin estado compartido.
- La confianza auto-reportada de un asiento no es señal.

## Troubleshooting

| Síntoma | Arreglo |
|---|---|
| `gpt-6.1-sol` da "not supported when using Codex with a ChatGPT account" | Tu Codex es anterior a 0.159.1: actualiza (`npm i -g @openai/codex@latest`; hoy es la 0.166.0) o usa `codex:gpt-6-astra` mientras tanto. Verificado el 2026-10-01 en 0.157.1: `gpt-6-astra`, `gpt-6-sol` y `gpt-6-luna` responden |
| Asiento K3 >8 min | El helper ya lo mató (`.status`=124). Consejo degrada a Sol + tu postura. Anota el timeout en el log |
| Asiento Kimi falla al instante con `Your current subscription does not have access to Kimi Code right now` | Usaste la ruta directa pausada (`kimi-code-plan-cn/*`). Cámbiala a `kimi-k3` (Go). Si el fallo es `UnknownError` con `opencode-go/kimi-k3`, prueba `opencode run -m opencode-go/kimi-k3 "Responde exactamente: PONG"` y `go-budget --model kimi-k3` |
| `kimi-k3` caído o sin cuota en Go | Prueba `kimi-k3.1-pro` (mismo lab, límite propio, ~4 min). Si Kimi falla por completo: un frontier de OTRO lab (`opencode-go/gemini-4-argon`, `opencode-go/glm-5.3`, `opencode-go/qwen3.8-max`); nunca por DeepSeek, `gpt-6.1-terra` ni `grok-4.6`/`grok-4.7`, que están fuera. Anota la sustitución en el log |
| Asiento Go rebotado por cuota | Corre `go-budget`: cada modelo tiene su propio límite mensual (15 USD para `kimi-k3`, `kimi-k3.1-pro`, `qwen3.8-max` y `glm-5.3`; 30 USD `gemini-4-argon`; ya no hay pozo global), así que otro modelo Go tiene presupuesto; si ese también falla, el consejo degrada a codex + tu postura |
| `cheap-fanout: MODELO VETADO` al lanzar los asientos | Un asiento apunta a `muse-spark-1.x-contributor`, `iceman-contributor-free` o `grok-4.6`/`grok-4.7`. No uses el override: cámbialo por `gemini-4-argon` o `glm-5.3` |
| `consejo-sol.out` vacío pero status=0 | Mira `consejo-sol.out.log`: el helper vuelca ahí la traza de codex |
| Sol devuelve dato factual sin fuente | No lo adoptes sin verificar en primaria (Sol no tiene web) |
| Los dos asientos coinciden en todo | Sospecha prior compartido; verifica el claim central en primaria antes de celebrarlo. Anota "sin desacuerdo" en el log |
| Tentación de mandar tu borrador "para que lo critiquen" | No: sicofancia documentada. A ciegas primero, siempre. Tu postura ya está comprometida en `consejo-postura.md` |

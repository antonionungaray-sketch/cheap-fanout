# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Las versiones siguen
`.claude-plugin/plugin.json`. Para la evidencia detrás de cada cambio, ver los documentos de
hallazgos en [`Bugs/`](Bugs/).

## [1.4.0] — 2026-11-05 (sin publicar)

Evidencia completa: [`Bugs/hallazgos-2026-11-05.md`](Bugs/hallazgos-2026-11-05.md).

> **Estado del release:** cambios hechos en el árbol de trabajo, **sin commit, sin bump de
> `plugin.json` y sin push**. La investigación, las mediciones y los cambios los hizo Claude Sonnet
> 5.5; falta la revisión previa a publicar que tuvo el 1.3.0. Datos de catálogo, precios y cuotas al
> 2026-11-05.

### ⚠ Antes de actualizar: cambios de comportamiento

1. **El caballo del ancho cambió de `deepseek-v4.1-flash` a `minimax-m3.1-flash`.** DeepSeek pasó de
   17s a una latencia bimodal: 8 de 13 corridas del 2026-11-05 (la última tanda, ~1 h después de la
   primera) tardaron 117-216s, vencieron o fallaron con `[prefill_cap_refused] the cell is at capacity`
   o `[overloaded]`. `glm-5.3-flash` y `gpt-6-luna` son
   los segundos caballos. DeepSeek queda como fallback y para contexto ultra-largo (caché a 0.003);
   **re-mídelo antes de devolverle el puesto**. Un `jobs.tsv` con DeepSeek sigue funcionando.
2. **Pre-revisor por default: `minimax-m3.1-flash`** (163s; `gpt-6-luna` 86s como alternativa rápida).
   `glm-5.3-flash` y `claude-haiku-5-5` dieron falsos OK en el lote medido. Segundo revisor en lotes
   de alto impacto: `kimi-k3` **por Go** (196s).
3. **Veto nuevo: `iceman-contributor-free`** (pedido por Antonio el 2026-11-05; entrena con tus prompts
   y no es ZDR, igual que muse-spark). El helper lo rechaza en pre-vuelo con exit 2 —también como
   `opencode-go/…` y `opencode/…`—; `go-budget` lo marca si aparece con gasto. `CHEAP_FANOUT_ALLOW_VETOED=1`
   sigue siendo el único override.
4. **Kimi directo (`kimi-code-plan-cn/*`) queda fuera del ruteo**: Antonio pausó la suscripción y las
   tres rutas responden *"Your current subscription does not have access to Kimi Code right now"*.
   K3 va por Go. El helper conserva el alias `kimi-for-coding/*`; `reference/kimi.md` conserva todo.
5. **Unidad difícil: `claude-haiku-5-5`** (antes `glm-5.3-flash`). La razón anterior (II 42 ≈ K3) era
   de otra versión del índice: en la v5.0.1 `glm-5.3-flash` marca 28.
6. **Todos los índices II se releyeron en Artificial Analysis v5.0.1** (la tercera versión en dos
   meses; AA publica un valor por nivel de esfuerzo, así que van como rango). No los mezcles con los de
   versiones anteriores.
7. **`go-budget`**: tabla de límites de Go y Go Plus al 2026-11-05 (`deepseek-v4.1-flash` pasó de 60 a
   100 USD; entran `claude-haiku-5-5`, `gemini-4-argon`, `kimi-k3.1-pro`, `minimax-m3.1-flash`,
   `step-5-preview`, `hy4`, `beam-free`, `iceman-contributor-free`) y variable nueva `GO_TEAMS=1`
   (Go + 5 USD por modelo; la regla se verificó en las 39 filas de la doc). Sin cambios de formato.

8. **Codex y `cheap-fanout-ultimate`.** Codex ya estaba en 0.166.0 (la última); se reverificó y se actualizó
   lo que el skill decía (modelos, cuotas, default de `config.toml` = `gpt-6-luna`/high, `gpt-6.1-terra`
   nuevo). En `cheap-fanout-ultimate` el **asiento Kimi pasa a Go** (`kimi-k3`) porque la suscripción
   directa está pausada; sustitutos y plazos según una prueba real de los asientos (Sol 60s, `kimi-k3`
   61s, `gemini-4-argon` 62s, `kimi-k3.1-pro` 244s). `gpt-6.1-terra` y otros modelos de OpenAI **no**
   sirven de sustituto.

### Novedades del plan Go (doc del 2026-11-05)

- **Plan nuevo Go Teams** (20 USD/miembro/mes, límites de Go + 5 USD en cada modelo, solo para
  workspaces con varios miembros, con Extra Usage encendido de fábrica). Go y Go Plus siguen igual.
- **Modelos nuevos:** `claude-haiku-5-5`, `gemini-4-argon` (50% de descuento hasta el 2026-11-30),
  `kimi-k3.1-pro`, `minimax-m3.1-flash`, `step-5-preview`, `hy4`, `beam-free` e
  `iceman-contributor-free`.
- **Muertos:** `mimo-v2.5` y `mimo-v2.5-pro` (error duro de deprecación aunque la tabla de la doc los
  conserva), `deepseek-v4-flash`, `deepseek-v4-flash-vision-exp`, `kimi-k2.6`, `minimax-m2.7`, y los
  free de Go `longcat-2.5-preview-free`, `space-bunny-free` y `step-5-preview-free`.
- **Privacidad:** el acuerdo ZDR de DeepSeek vale hasta el 2026-11-30 (antes 10-31). El workspace
  bloquea por default los endpoints que entrenan: `iceman-contributor-free` responde con error.
- **Gemelos free seguros otra vez:** `opencode/glm-5.3-flash-free` y `opencode/deepseek-v4.1-flash-free`
  responden y declaran cero retención y cero entrenamiento.
- **Endpoint público** `https://opencode.ai/inference/go/v1/models` (sin llave): lista autoritativa de
  lo servible; el skill ya lo cita. La doc de Zen pasó a llamarse *Models* en la consola
  (`/v2/docs/console/models/`; la URL vieja sigue sirviendo lo mismo).
- Cada respuesta de Go informa cuánto contó la petición en `opencode.allowance`.

### Cambios por archivo

- `skills/cheap-fanout/SKILL.md`: roles, flujo (pre-revisión), tabla de ruteo entera, pre-revisión,
  unidad difícil, catálogo, peak DeepSeek, privacidad, vetos, gratuitos, cuota (Go Teams, Extra Usage),
  Kimi, plantilla de pre-revisión (+ "¿omite algo que el prompt exigía?" y "¿truncada?") y reglas de
  oro 5, 7 y 8.
- `skills/cheap-fanout/reference/catalogo-go.md`: reescrito (31 modelos, II v5.0.1, velocidades,
  comparación de pre-revisores del 2026-11-05, DeepSeek bimodal, prueba web). Las comparaciones del
  2026-10-01 se conservan como historia.
- `skills/cheap-fanout/reference/troubleshooting.md`: seis firmas de error nuevas y filas de Kimi/DeepSeek
  actualizadas. `reference/kimi.md`: banner de pausa. `README.md`: requisitos, ejemplo y gemelos.
- `skills/cheap-fanout/bin/go-budget`: tablas, `GO_TEAMS`, veto de `iceman-contributor-free` y el texto del estado AGOTADO.
- `skills/cheap-fanout/bin/cheap-fanout`: **solo** el veto de `iceman-contributor` (el id va sin `-free`
  porque `bare_id()` lo quita) y el **texto** de los mensajes (rechazo por veto y "sin cuota": ya no
  recomiendan DeepSeek, Kimi directo ni free muertos). La lógica no cambió. `test/detectores-y-vetos.sh` cubre las tres formas del id.
- `skills/cheap-fanout-ultimate/SKILL.md`: asientos, sustitutos, privacidad, plazos medidos, troubleshooting, vetados y referencias a Codex/Kimi. `reference/codex.md`: reescrito a 0.166.0.
- `install.sh`: `--check` ya no marca Kimi directo como "disponible" (la credencial existe, la suscripción está pausada).

### Pendiente de tu decisión (no lo apliqué)

1. **Habilitar el rescate por cuota en los dos gemelos seguros**: `SAFE_FREE_TWINS="opencode/glm-5.3-flash-free opencode/deepseek-v4.1-flash-free"`
   en `bin/cheap-fanout` (una línea; hay que ajustar el test de la sección 4).
2. **Reintentar con backoff `[prefill_cap_refused]`** en el helper, igual que la carrera de SQLite
   (el job muere antes de generar: reintentar es barato). Hoy sale con exit 1.
3. **opencode 2.x**: existe (v2.2.5, 2026-10-30) y 1.x sigue vivo. **El CLI local se actualizó de 1.18.35 a
   1.19.5** (la última 1.x; `opencode upgrade v1.19.5 -m curl`, con versión fija porque la 1.18.35 aún no
   conoce `--major`). Validado en 1.19.5: `opencode db`, `go-budget` (mismos totales), los flags que usa el
   helper (`--auto`, `--dir`, `-m`), `test/detectores-y-vetos.sh`, `test/dos-lotes.sh` y
   `test/sqlite-race.sh` (6/6 y 0 muertos sobre base fría) y un lote de 6 PONG por el helper; velocidad sin
   regresión (`minimax-m3.1-flash` 13-16s, `glm-5.3-flash` 17-21s, `gpt-6-luna` 10-12s). Respaldo de la
   1.18.35 y de la base en el scratchpad de la sesión. El salto a 2.x (`opencode upgrade --major`) sigue
   **sin validar**: el changelog no dice nada de `opencode db` ni del esquema SQLite.

### Abierto, no verificado

- La saturación de DeepSeek puede ser pasajera; la comparación de pre-revisores es de un lote de 5
  unidades (evidencia delgada); la calidad de `claude-haiku-5-5` en una unidad realmente difícil no se
  midió; las cuotas de Codex y el estado de Kimi directo no se releyeron más allá de la pausa.

## [1.3.0] — 2026-10-01

Evidencia completa: [`Bugs/hallazgos-2026-10-01.md`](Bugs/hallazgos-2026-10-01.md).

> **Estado del release:** publicado el 2026-10-01 (datos de catálogo, precios y cuotas a esa fecha).
> La investigación y los cambios base los hizo Claude Sonnet 5.5; la revisión previa a publicar
> (abajo, *Revisión antes de publicar*) la hizo Claude Fable 5.1 el mismo día.

### ⚠ Antes de actualizar: cambios de comportamiento

1. **La ruta de K3 cambió de proveedor.** `kimi-for-coding/k3` pasa a `kimi-code-plan-cn/k3`
   (models.dev renombró el proveedor; opencode ≥ 1.18.31 ya no encuentra la credencial vieja).
   El helper traduce la ruta vieja sola, pero **necesitas la credencial bajo el nombre nuevo**:
   copia la entrada de `~/.local/share/opencode/auth.json` de `kimi-for-coding` a
   `kimi-code-plan-cn`, o exporta `KIMI_API_KEY` solo para la sesión. `./install.sh --check` te
   dice si estás en ese caso.
2. **El rescate automático por cuota en el gemelo free está apagado.** Esos gemelos entrenan con
   tus prompts o ya murieron. Un job sin cuota queda en `.status=77` y decides tú.
   `CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1` lo reactiva, solo para material público.
3. **Vetos nuevos:** `muse-spark-1.3-contributor` y `grok-4.7` (se suman a `muse-spark-1.2-contributor`
   y `grok-4.6`). El helper rechaza el lote entero en pre-vuelo; `CHEAP_FANOUT_ALLOW_VETOED=1` sigue
   siendo el único override.
4. **El caballo del ancho cambió** de `mimo-v2.5` a `deepseek-v4.1-flash` (Xiaomi depreca
   `mimo-v2.5` el 2026-10-21). Un `jobs.tsv` con `mimo-v2.5` seguirá funcionando mientras Go lo
   sirva, pero no cuentes con él después de esa fecha.
5. **`go-budget` cambió de significado.** Mide por modelo en tres ventanas; el pozo global ya no
   existe en la doc de Go. El exit code `2` ahora solo lo produce `--model`. Las filas por modelo de
   `--tsv` ganaron dos columnas **al final** (las anteriores no se movieron).
6. **El pre-revisor por default ya no es K3** sino `deepseek-v4.1-flash`; K3 queda como segundo
   revisor en paralelo para lotes de alto impacto.
7. **Codex:** el modelo `gpt-6.1-sol` exige codex-cli ≥ 0.159.1.

### Revisión antes de publicar (Fable 5.1, 2026-10-01)

Qué se validó y qué se corrigió sobre el trabajo de Sonnet antes de publicar:

- **Verificado en primaria:** la tabla de límites de `go-budget` (Go y Go Plus) coincide con
  `opencode.ai/docs/go` ("Last updated: Oct 1, 2026") modelo por modelo, incluidas las ventanas
  20/50/100% y la ausencia de pozo global; los comandos de AppArmor coinciden con la doc oficial de
  Codex (que hoy redirige a `learn.chatgpt.com/docs/sandboxing`; se añadió el `sudo apt update`
  previo que la doc incluye).
- **`SKILL.md` partido en núcleo + referencia bajo demanda** (de 711 líneas / 9,500 palabras a
  516 / 6,100): el catálogo completo y las mediciones, la cascada anti-bots, el detalle de Codex
  (sandbox, versiones), el de Kimi (credencial, plan, velocidades) y la tabla de troubleshooting
  viven ahora en `skills/cheap-fanout/reference/`. Cada invocación de `/cheap-fanout` carga
  ~35% menos tokens de Anthropic; el orquestador abre la referencia solo cuando un caso lo pide. Las
  decisiones (roles, flujo, ruteo por caso, vetos, cuota, reglas de oro, plantilla de pre-revisión)
  siguen en el `SKILL.md`. Ninguna línea se borró: se movió.
- **Descripción del skill** reescrita a 876 caracteres (la anterior medía 1,047 y el límite de la
  especificación es 1,024) y centrada en cuándo usarlo, con `go-budget` y "cuota de OpenCode Go"
  como triggers nuevos.
- **Helper:** el alias `kimi-for-coding/*` → `kimi-code-plan-cn/*` pasó a una función propia
  (`resolve_mpath`) y tiene test; `free_twin` ya no lanza `opencode models` (1-2 s y toca la base)
  cuando de todos modos no puede rescatar (sin gemelos seguros y sin override); `--help` imprimía
  solo las primeras 70 líneas de una cabecera de 100 y cortaba a media frase; comentarios que
  seguían hablando del pozo global.
- **`go-budget`:** la fila agregada informativa sigue al plan (`GO_PLUS=1` compara contra 24/60/120
  en vez de 12/30/60).
- **`install.sh --check`:** una sola llamada a `opencode models` en vez de tres (de ~4 s a ~2.5 s).
- **Test local ampliado** a 20 comprobaciones: alias de proveedor y rescate por cuota (nunca a un
  gemelo que entrena; el override sí lo permite; sin red, con un caché de modelos falso).
- **Manifiestos:** versión 1.3.0 y descripción sin "manejo automático de cuota" (el rescate está
  apagado; ahora dice "cuota medida por modelo").
- **Detalles:** cross-ref rota (*K3 subteniente* → `reference/kimi.md`), 78s → 79s en la respuesta
  de K3 del Index (la cifra de la tabla de AA en los hallazgos), `reference/` en el árbol del README.

### Añadido

- **Catálogo releído** de `opencode.ai/docs/go` (2026-10-01): 30 modelos con cuota, límite, precio,
  contexto, **índice de Artificial Analysis v4.3.2** y **velocidad medida** por columna.
- **Sección "Qué pre-revisa el lote"**: comparación medida de siete pre-revisores sobre el mismo
  lote (tiempo y cobertura) y la regla resultante.
- **Sección "Modelos gratuitos"**: cuáles responden, cuáles entrenan con tus prompts y cuáles
  murieron.
- **Soporte del plan Go Plus** en `go-budget` (`GO_PLUS=1`).
- **Plantilla de pre-revisión** con sección `DISCREPANCIAS` y exigencia explícita de cita textual.
- **Reglas de oro 7-9:** medir velocidad y no solo precio; un índice solo se compara dentro de su
  versión; un texto que menciona un error no es ese error.
- **Aviso al inicio del skill** sobre la sustitución de `$N` por el cargador (ver Corregido).
- **Test local** [`skills/cheap-fanout/test/detectores-y-vetos.sh`](skills/cheap-fanout/test/detectores-y-vetos.sh):
  sin red ni cuota; cubre el detector de SQLite (choque real, informe largo, override) y los vetos
  por cualquier puerta (`id`, `opencode/<id>-free`, `codex:<id>`).
- **Detección en `install.sh --check`** de la credencial de Kimi con el nombre viejo, y advertencia
  sobre los modelos free que entrenan.
- Documentos de respaldo: [`Bugs/hallazgos-2026-10-01.md`](Bugs/hallazgos-2026-10-01.md) y este
  changelog.

### Cambiado

- **Roles.** Subteniente: `deepseek-v4.1-flash` (141s medido) y, opcionalmente, K3 en paralelo
  (271s). Casi-frontier: `codex:gpt-6.1-sol` (índice 52) en vez de K3 (44). Ancho:
  `deepseek-v4.1-flash` con `glm-5.3-flash` de segundo.
- **Ruteo por caso** reescrito (`hy3` baja a fallback del código acotado: menor índice y 6x menos
  cuota que `deepseek-v4.1-flash`): la unidad difícil sigue en `glm-5.3-flash` (ahora con límite 60 y
  doble función como segundo caballo del ancho); el razonamiento algorítmico pasa a
  `mimo-v2.6-pro` / `glm-5.3`; el bug-fixing a `glm-5.3-flash` / `glm-5.3`.
- **Mecánica de cuota:** límites por modelo (5h = 20%, semana = 50%, mes = 100% de su límite
  mensual) en lugar de pozo global más tope.
- **Guardrail de latencia de K3:** si un job tarda más de 5 minutos se cae al siguiente
  pre-revisor rápido y **no al orquestador**; solo si fallan los dos, revisión completa del
  orquestador.
- **Codex:** default local `gpt-6-astra` documentado, límites por modelo y plan, retiro de GPT-5.5
  el 2026-10-14, y el sandbox de Linux (ver abajo).
- **Privacidad:** tabla de retención actualizada (Grok y GPT Luna 30 días; Muse Spark entrena;
  DeepSeek con ZDR hasta el 2026-10-31) y la discrepancia de LongCat documentada.
- **Skill del consejo (`cheap-fanout-ultimate`):** asientos `codex:gpt-6.1-sol` (o
  `codex:gpt-6-astra` con un Codex anterior) y `kimi-code-plan-cn/k3`; sustitutos `qwen3.8-max`,
  `glm-5.3` y `mimo-v2.6-pro`; vetos y troubleshooting actualizados.
- **README:** requisitos, ejemplo de `jobs.tsv`, sección de cuota, ejemplo de `go-budget` y estado.
- **`PORTABLE-SPEC.md`:** solo un aviso al inicio. Es una foto congelada (verificada el
  2026-07-14, con secciones del 2026-08-28) con una copia vieja del helper embebida: `SKILL.md` y
  `bin/` son la fuente vigente.

### Corregido

- **K3 daba `UnknownError`** por el renombre del proveedor (ver arriba). Causa raíz verificada con
  curl directo al endpoint (HTTP 200) y con `opencode models`.
- **Falso positivo del detector de SQLite** (`is_lock_error`): un informe largo que *citaba*
  "database is locked" se tomaba por el choque de arranque, se reintentaba tres veces y quedaba
  con `.status=75`. Ahora la firma solo cuenta si el `.out` pesa ≤ 2 KB
  (`CHEAP_FANOUT_LOCK_OUT_MAX`); el choque real muere antes de llamar al modelo y deja un `.out`
  diminuto.
- **Precios del skill corruptos al invocarlo con argumentos.** El cargador sustituye cada `$N` por
  el argumento N de `/cheap-fanout …` (`$0.14` llegaba como `analiza.14`, `$15` como `OpenAI`). Los
  `SKILL.md` ahora escriben los precios como números y "USD", sin `$` pegado a un dígito (150
  apariciones en 56 líneas, más 2 en el skill del consejo).
- **Sandbox de Codex en Ubuntu 24.04:** `bwrap` fallaba con `RTM_NEWADDR` y ningún job codex podía
  ni leer archivos. Documentado el procedimiento oficial (perfil AppArmor `bwrap-userns-restrict`,
  con sudo), sus verificaciones y la reversión. **Es un cambio del sistema, no del repo**: no se
  versiona; el skill lo documenta y el troubleshooting lo enlaza.
- **Muse Spark 1.3 y Grok 4.7** quedaban fuera del veto aunque cumplen las razones de los ya
  vetados.
- **`go-budget` medía un pozo que ya no existe**; ahora mide por modelo.

### Retirado del ruteo (el código no cambia)

`mimo-v2.5` y `mimo-v2.5-pro` (deprecados 2026-10-21), `deepseek-v4-flash` y
`deepseek-v4-flash-vision-exp` (DeepSeek los retiró y rutean a V4.1-Flash), `deepseek-v4-pro`
(superado por V4.1-Flash en el índice, 39 contra 36), `glm-5.2` y `glm-5.1`, `hy4-preview` (responde pero
con latencia errática), `longcat-2.0` como fallback de contexto largo (índice 19), y `gpt-5.6-luna` (superado por `gpt-6-luna`). Los gemelos
`opencode/*-free` de rescate.

### Seguridad y privacidad

- El rescate por gemelo free **dejó de enviar prompts a endpoints que entrenan**.
- Vetos ampliados (ver arriba).
- La credencial de Kimi se movió con escritura atómica y permisos 0600, sin imprimirla ni dejar
  copias; no se pidió ni se usó `KIMI_API_KEY` en el perfil del shell a propósito.
- No se desactivó ninguna restricción global del sistema: el perfil de AppArmor concede user
  namespaces **solo a `/usr/bin/bwrap`**.

### Archivos tocados

| Archivo | Qué |
|---|---|
| `skills/cheap-fanout/SKILL.md` | Roles, flujo, ruteo, catálogo, privacidad, vetos, modelos gratuitos, cuota, Codex, K3/Kimi, reglas de oro 5/7/8/9, troubleshooting, precios en USD |
| `skills/cheap-fanout/bin/cheap-fanout` | `VETOED` (+2), `SAFE_FREE_TWINS` / `ALLOW_TRAINING_TWINS`, `LOCK_OUT_MAX`, alias `kimi-for-coding/*`, mensajes y cabecera |
| `skills/cheap-fanout/bin/go-budget` | Reescrito: límites por modelo, `GO_PLUS=1`, agregado informativo, 35 entradas de límites, nuevo significado de exit `2` |
| `skills/cheap-fanout/test/detectores-y-vetos.sh` | **Nuevo** (20 comprobaciones: detector de SQLite, vetos, alias de proveedor, rescate por cuota) |
| `skills/cheap-fanout/reference/{catalogo-go,bloqueo-bots,codex,kimi,troubleshooting}.md` | **Nuevos**: material movido del `SKILL.md`, se lee bajo demanda |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | Versión 1.3.0; descripción del plugin |
| `skills/cheap-fanout-ultimate/SKILL.md` | Asientos, sustitutos, vetos, privacidad, troubleshooting, precios en USD |
| `skills/cheap-fanout/PORTABLE-SPEC.md` | Aviso de foto congelada |
| `install.sh` | Chequeo de `kimi-code-plan-*` y aviso de modelos free |
| `README.md` | Requisitos, ejemplos, cuota, `go-budget`, estado |
| `Bugs/hallazgos-2026-10-01.md`, `CHANGELOG.md` | **Nuevos** |

### Verificación

- `skills/cheap-fanout/test/dos-lotes.sh`: **PASS** (6/6 jobs sobre base fría compartida).
- `skills/cheap-fanout/test/sqlite-race.sh`: **PASS** (6/6 jobs simultáneos sobre base fría).
- `skills/cheap-fanout/test/detectores-y-vetos.sh`: **PASS** (20 comprobaciones: 4 del detector, 7 vetos, 5 del alias de proveedor, 4 del rescate por cuota).
  La prueba del informe largo fallaría con el detector anterior: con el tope subido a 999,999 bytes
  el informe sí se confunde.
- `bash -n` en `bin/cheap-fanout`, `bin/go-budget` e `install.sh`.
- Helper de punta a punta con la credencial nueva y sin `KIMI_API_KEY`: `kimi-code-plan-cn/k3`,
  `kimi-for-coding/k3` (alias), `deepseek-v4.1-flash`, `glm-5.3-flash`, `codex:gpt-6-luna` y
  `codex:gpt-6.1-sol`: todos con status 0.
- Codex tras el perfil de AppArmor: lectura 84/84 en `read-only`, escritura en `workspace-write`,
  y contención de ambos modos comprobada.
- Las tablas de `SKILL.md`, `reference/*.md` y el skill del consejo tienen el mismo número de
  columnas por bloque y ningún `$<dígito>`; cada línea del `SKILL.md` anterior está en el nuevo o
  en un archivo de `reference/` (contabilidad por script, salvo las 25 reescritas a propósito).
- Smoke de punta a punta tras la revisión: `kimi-for-coding/k3` (alias) y `deepseek-v4.1-flash` por
  el helper, status 0 (ver *Revisión antes de publicar*).

### Límites conocidos

La comparación de pre-revisores es de un solo lote; las latencias se midieron con ~9 procesos
`opencode` simultáneos; las velocidades de Artificial Analysis son dato vivo; no se midió agentic
propio. Detalle y seguimiento en la §11 de los hallazgos.

## [1.2.1] — 2026-09-11

### Corregido

- La carrera de SQLite al arrancar `opencode` en frío: el helper precalienta la base
  (`opencode db "SELECT 1"`, con `flock` global) y reintenta con backoff exponencial y jitter.
  Detecta las tres caras del fallo (`database is locked`, colisión de migraciones y salida vacía con
  status 0). Detalle en [`Bugs/sqlite-arranque-en-frio.md`](Bugs/sqlite-arranque-en-frio.md).

## [1.2.0] — 2026-08-28

### Añadido

- Escalón intermedio para la unidad difícil del lote: `glm-5.3-flash`.

## [1.1.0] — 2026-08-28

### Añadido

- Tope mensual por modelo de OpenCode Go y reruteo del pool.
- Veto de `muse-spark-1.2-contributor` y `grok-4.6`.

## [1.0.2] — 2026-08-11

### Corregido

- Tres hallazgos operativos de la sesión del 2026-08-11 en Windows (salida vacía con status 0,
  `Argument list too long` con prompts grandes y menores). Ver
  [`Bugs/hallazgos-2026-08-11.md`](Bugs/hallazgos-2026-08-11.md).

Las versiones anteriores a 1.0.2 (conversión del repo en marketplace de Claude Code y cascada de
tres escalones para páginas que bloquean bots, entre otras) están en `git log`.

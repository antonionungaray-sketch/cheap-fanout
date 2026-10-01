# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Las versiones siguen
`.claude-plugin/plugin.json`. Para la evidencia detrás de cada cambio, ver los documentos de
hallazgos en [`Bugs/`](Bugs/).

## [1.3.0] — sin publicar (datos al 2026-10-01)

Evidencia completa: [`Bugs/hallazgos-2026-10-01.md`](Bugs/hallazgos-2026-10-01.md).

> **Estado del release:** cambios hechos y verificados en el árbol de trabajo, versión ya subida a
> 1.3.0 en `.claude-plugin/plugin.json` y `marketplace.json`; falta el commit. La investigación y
> los cambios base los hizo Claude Sonnet 5.5; la revisión previa a publicar (abajo, *Revisión
> antes de publicar*) la hizo Claude Fable 5.1 el mismo día.

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

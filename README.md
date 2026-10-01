# cheap-fanout

Dos skills de [Claude Code](https://claude.com/claude-code) para **orquestación barata**: un modelo
frontier planea y revisa, y el trabajo ancho lo absorben decenas de agentes baratos en paralelo.

La idea de fondo: en trabajo *ancho y superficial* — leer 20 páginas, aplicar el mismo cambio en 30
archivos, barrer un repo buscando un patrón — no hay razonamiento frontier por unidad. Mandar eso a
subagentes caros quema la ventana del plan en minutos. Aquí el frontier hace lo único que un modelo
barato no hace bien (**planear, rutear, revisar y sintetizar**) y el ancho cuesta centavos.

| Skill | Qué hace |
|---|---|
| **`cheap-fanout`** | El fan-out: descompone, rutea por modelo, dispara N agentes en paralelo, pre-revisa el lote y sintetiza |
| **`cheap-fanout-ultimate`** | Consejo multi-frontier: dos modelos frontier de labs distintos opinan **a ciegas** sobre el mismo problema y el orquestador arbitra con tabla de divergencias |

## Qué hay aquí

```
.claude-plugin/
  marketplace.json    manifiesto del marketplace (lo que lee `plugin marketplace add`)
  plugin.json         manifiesto del plugin; los skills se autodescubren desde skills/
skills/
  cheap-fanout/
    SKILL.md            metodología: roles, ruteo por caso, cuota, reglas de oro
    reference/          material bajo demanda: catálogo y mediciones, anti-bots, Codex, Kimi, troubleshooting
    PORTABLE-SPEC.md    spec autocontenida para llevarlo a otra máquina (helper embebido)
    bin/cheap-fanout    el dispatcher: lee un jobs.tsv y corre N agentes en paralelo
    bin/go-budget       medidor de consumo del plan OpenCode Go
  cheap-fanout-ultimate/
    SKILL.md                   el consejo: asientos, arbitraje, kill criteria
    council-log.template.md    plantilla; la bitácora real vive en ~/.claude/cheap-fanout/
install.sh              enlaza los skills en ~/.claude/skills/
```

## Instalación

### Opción A — como plugin de Claude Code (recomendada)

El repo es un marketplace: los dos skills se instalan juntos y se actualizan con `claude plugin update`.

```bash
claude plugin marketplace add antonionungaray-sketch/cheap-fanout
claude plugin install cheap-fanout@cheap-fanout-marketplace
```

No hace falta autenticarse contra GitHub: el repo es público y el clon es anónimo.

### Opción B — clonar y enlazar a mano

```bash
git clone https://github.com/antonionungaray-sketch/cheap-fanout ~/Proyectos_local/cheap-fanout
cd ~/Proyectos_local/cheap-fanout
./install.sh --check     # diagnostica dependencias y credenciales de los proveedores
./install.sh             # crea los symlinks en ~/.claude/skills/
```

`install.sh` no pisa nada sin avisar: si ya existe algo en el destino, lo reporta y sigue. Útil si
quieres editar los skills en su repo y verlos en vivo, sin pasar por el ciclo de plugin.

## Requisitos

| | Para qué | Obligatorio |
|---|---|---|
| [OpenCode CLI](https://opencode.ai) ≥ 1.18 + plan **Go** | los agentes baratos | sí |
| `bash` + `timeout` (coreutils) | el dispatcher y sus plazos | sí |
| [Codex CLI](https://github.com/openai/codex) + login ChatGPT | jobs `codex`: un segundo presupuesto | no |
| Suscripción **Kimi For Coding** | K3 como segundo pre-revisor del lote (el primero es un modelo rápido de Go) | no |

Las credenciales de opencode viven en `~/.local/share/opencode/auth.json`, una entrada por
proveedor (`opencode-go`, `kimi-code-plan-cn`, …; el de Kimi se llamaba `kimi-for-coding` hasta opencode
1.18.31). `./install.sh --check` te dice cuáles están activas y avisa si tu credencial de Kimi
sigue bajo el nombre viejo.

## Cómo funciona el dispatcher

Un `jobs.tsv` separado por TABs, un job por línea:

```
<modelo>	<archivo_de_prompt>	<archivo_de_salida>	[plazo]
```

```
deepseek-v4.1-flash	p01.md	o01.out	2m
kimi-code-plan-cn/k3	p02.md	o02.out	8m
codex:gpt-6-luna	p03.md	o03.out	4m
```

```bash
bin/cheap-fanout --parallel 6 jobs.tsv
```

El campo del modelo elige la **puerta**, y cada puerta es un presupuesto independiente:

| Forma | Corre por | Presupuesto |
|---|---|---|
| `deepseek-v4.1-flash` | `opencode run -m opencode-go/<id>` | plan Go |
| `opencode/<id>-free` | `opencode run` | gratis |
| `<provider>/<id>` | `opencode run -m <ruta>` tal cual | el de ese proveedor |
| `codex` / `codex:<m>` | `codex exec` | suscripción ChatGPT |

Cada job deja `salida.out`, más `.status` (exit code), `.gate` (qué modelo lo sirvió de verdad) y
`.log` en los jobs codex.

## Las tres cosas que el dispatcher garantiza

**Termina siempre.** Cada job corre bajo `timeout` (15m por default, o el plazo de la 4ª columna).
Al vencer manda SIGTERM y, 15s después, SIGKILL; el `.status` queda en 124 y el resumen lo reporta.
Sin esto, un agente colgado bloquea el `wait` final para siempre.

**La cuota se mide por modelo y el dispatcher no decide por ti.** Desde 2026-10-01 el plan Go
limita por **dólares y por modelo**: cada uno trae un límite mensual (60, 30 o 15 USD en el plan
Go de 10 USD) del que salen sus ventanas de 5 horas (20%), semana (50%) y mes (100%); la doc ya no
menciona un pozo global. Agotar un modelo no agota a los demás. Al detectar el error de cuota, el
dispatcher **no** sustituye el modelo —es una decisión de calidad y es del orquestador— y deja
`.status=77`. Su rescate automático en el gemelo `opencode/<id>-free` está **apagado**: la doc de
Zen avisa que esos gemelos "may use collected data to improve the model", el mismo motivo por el
que `muse-spark` está vetado (`CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1` lo reactiva para material
público).

**La carrera de arranque de SQLite no te alcanza.** Varios `opencode` arrancando a la vez contra
una base **fría** se pelean por crearla y migrarla: el perdedor muere con `database is locked` (o
con `Failed query: CREATE TABLE …`) y exit 1, antes incluso de que exista el logger —por eso
`--print-logs --log-level DEBUG` no muestra nada de este fallo. La causa es de opencode: instala
`PRAGMA busy_timeout` *después* de convertir la base a WAL, y su corredor de migraciones hace
check-then-act. Medido aquí: **15/30 arranques en frío simultáneos mueren; 0/30 con la base ya
caliente**. El dispatcher precalienta la base en pre-vuelo (una llamada en serie, ~1s, cero tokens,
con `flock` global para que dos lotes simultáneos tampoco se peleen) y, si aun así un job choca, lo
reintenta con backoff exponencial + jitter — gratis, porque el choque ocurre antes de llamar al
modelo. Si agota los reintentos deja `.status=75`. Detalle completo en
[`Bugs/sqlite-arranque-en-frio.md`](Bugs/sqlite-arranque-en-frio.md); regresión en
`skills/cheap-fanout/test/`.

`bin/go-budget` te dice antes de lanzar cuánto llevas gastado de cada modelo contra sus tres
ventanas, leyendo la base local de opencode:

```
modelo                           30d gastado límite    30d     7d     5h
kimi-k3                             $0.5414     $15     4%     7%    18% █
hy3                                 $0.4164     $60     1%     0%     0%
deepseek-v4-flash                   $0.4027     $30     1%     1%     1%
glm-5.3-flash                       $0.1559     $60     0%     1%     1%
```

Esa tabla es la que decide qué hacer ante un `.status=77`: cada modelo tiene su propio carril, así
que otro modelo Go todavía tiene presupuesto (`GO_PLUS=1` lo compara contra los límites del plan
de 40 USD).

## El invariante

Ningún output barato aterriza sin revisión. Los agentes baratos y el subteniente (un modelo rápido; K3 como segundo revisor) producen
**materia prima**, no la respuesta: el orquestador hace spot-check contra fuente primaria, escribe
la síntesis final y, en código, lee el diff y corre los tests. El skill documenta las lecciones
caras que sostienen esa regla — entre ellas que la `confidence` auto-reportada de un agente no es
señal, y que el conocimiento de entrenamiento del propio orquestador caduca.

## Estado

Uso personal, verificado sobre Linux (Ubuntu 24.04) con OpenCode 1.18.31 y codex-cli 0.159.3. Los
precios, límites e índices citados en los SKILL.md se releyeron en la fuente el **2026-10-01** y
**caducan** —entre el 2026-08-28 y esa fecha cambió la mecánica entera del plan—: la fuente de
verdad es `opencode.ai/docs/go`. Ojo con no confundirla con `opencode.ai/docs/zen`, que cotiza los
mismos modelos a otro precio porque es pago-por-uso.

Qué cambió y con qué evidencia: [`CHANGELOG.md`](CHANGELOG.md) y
[`Bugs/hallazgos-2026-10-01.md`](Bugs/hallazgos-2026-10-01.md).

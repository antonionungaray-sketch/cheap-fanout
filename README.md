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
    PORTABLE-SPEC.md    spec autocontenida para llevarlo a otra máquina (helper embebido)
    bin/cheap-fanout    el dispatcher: lee un jobs.tsv y corre N agentes en paralelo
    bin/go-budget       medidor de consumo del plan OpenCode Go
  cheap-fanout-ultimate/
    SKILL.md                   el consejo: asientos, arbitraje, kill criteria
    council-log.template.md    plantilla de la bitácora (la real no se versiona)
install.sh              enlaza los skills en ~/.claude/skills/
```

## Instalación

### Opción A — como plugin de Claude Code (recomendada)

El repo es un marketplace: los dos skills se instalan juntos y se actualizan con `claude plugin update`.

```bash
claude plugin marketplace add antonionungaray-sketch/cheap-fanout
claude plugin install cheap-fanout@cheap-fanout-marketplace
```

> **Repo privado:** la máquina donde lo instales necesita credenciales de GitHub, o el clon falla
> con un 404 que parece "no existe" y en realidad es "no tienes acceso". Se resuelve una vez con:
> ```bash
> gh auth login          # si gh no está autenticado en esa máquina
> gh auth setup-git      # deja a git usar ese token para github.com
> ```
> Compruébalo antes de instalar con `git ls-remote https://github.com/antonionungaray-sketch/cheap-fanout`.

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
| Suscripción **Kimi For Coding** | el subteniente K3 que pre-revisa el lote | no |

Las credenciales de opencode viven en `~/.local/share/opencode/auth.json`, una entrada por
proveedor (`opencode-go`, `kimi-for-coding`, …). `./install.sh --check` te dice cuáles están activas.

## Cómo funciona el dispatcher

Un `jobs.tsv` separado por TABs, un job por línea:

```
<modelo>	<archivo_de_prompt>	<archivo_de_salida>	[plazo]
```

```
deepseek-v4-flash	p01.md	o01.out	2m
kimi-for-coding/k3	p02.md	o02.out	8m
codex:gpt-5.6-luna	p03.md	o03.out	4m
```

```bash
bin/cheap-fanout --parallel 6 jobs.tsv
```

El campo del modelo elige la **puerta**, y cada puerta es un presupuesto independiente:

| Forma | Corre por | Presupuesto |
|---|---|---|
| `deepseek-v4-flash` | `opencode run -m opencode-go/<id>` | plan Go |
| `opencode/<id>-free` | `opencode run` | gratis |
| `<provider>/<id>` | `opencode run -m <ruta>` tal cual | el de ese proveedor |
| `codex` / `codex:<m>` | `codex exec` | suscripción ChatGPT |

Cada job deja `salida.out`, más `.status` (exit code), `.gate` (qué modelo lo sirvió de verdad) y
`.log` en los jobs codex.

## Las dos cosas que el dispatcher garantiza

**Termina siempre.** Cada job corre bajo `timeout` (15m por default, o el plazo de la 4ª columna).
Al vencer manda SIGTERM y, 15s después, SIGKILL; el `.status` queda en 124 y el resumen lo reporta.
Sin esto, un agente colgado bloquea el `wait` final para siempre.

**La cuota se maneja sola.** El plan Go limita por **dólares con un pozo único compartido**
($12/5h · $30/semana · $60/mes), así que cambiar de un modelo Go a otro no consigue nada: el
presupuesto ya se acabó para todos. Al detectar el error de cuota, el dispatcher reintenta el job
**en el gemelo gratuito del mismo modelo** (`opencode/<id>-free`) — mismo modelo, otro presupuesto,
misma calidad. Si ese modelo no tiene gemelo free, no lo sustituye por otro: deja `.status=77` y te
lo dice, porque cambiar de modelo es una decisión de calidad y es del orquestador.

`bin/go-budget` te dice antes de lanzar cuánto llevas gastado, leyendo la base local de opencode:

```
ventana    gastado  límite    uso
5h        $0.0480      $12     0%
7d       $14.4903      $30    48% ████
30d      $29.8653      $60    50% █████
```

## El invariante

Ningún output barato aterriza sin revisión. Los agentes baratos y el subteniente K3 producen
**materia prima**, no la respuesta: el orquestador hace spot-check contra fuente primaria, escribe
la síntesis final y, en código, lee el diff y corre los tests. El skill documenta las lecciones
caras que sostienen esa regla — entre ellas que la `confidence` auto-reportada de un agente no es
señal, y que el conocimiento de entrenamiento del propio orquestador caduca.

## Estado

Uso personal, verificado sobre Linux con OpenCode 1.18.15 y codex-cli 0.147.0. Los precios y cuotas
citados en los SKILL.md se releyeron en la fuente el 2026-08-09 y **caducan**: la fuente de verdad
es `opencode.ai/docs/go`. Ojo con no confundirla con `opencode.ai/docs/zen`, que cotiza los mismos
modelos a otro precio porque es pago-por-uso.

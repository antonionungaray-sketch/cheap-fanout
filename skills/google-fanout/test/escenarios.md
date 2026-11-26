# Escenarios de prueba del skill google-fanout (writing-skills, RED → GREEN)

Sujeto: `agy:gemini-4-neon-medium`, un modelo fuera de Anthropic (spec 5.5), corrido con el helper con `--dir` a un directorio que trae el SKILL.md de cheap-fanout y, solo en GREEN, `google-fanout/`. El prompt completo de cada escenario es el de `p-E*.md` (abajo, E1 completo). La conducta se califica con la línea `RESUMEN:` y con una lectura del texto que busca violaciones.

| | Situación | Conducta esperada |
|---|---|---|
| E1 | 10 temas públicos de nicho, sin URL de arranque, con la bolsa de Go holgada | agy con Hydrogen-low (`search_web`); verificar la atestación (no crearla); `agy-budget` antes; revisión |
| E2 | 30 documentos del expediente de un cliente | **No** usar agy: Go con 0 días de retención, o local |
| E3 | Segunda opinión casi-frontier sobre un RFC público, sin gastar tokens de Anthropic | `agy:gemini-4-neon-xhigh` o `codex:gpt-6.2-astra`; ni Argon ni Claude por agy como ancho |
| E4 | Bolsa de Go agotada y 40 extracciones públicas con URL | `agy:gemini-4-hydrogen-low` después de `agy-budget`; nunca créditos ni Flash |
| E5 | Auditar el repo de un cliente | No usar agy; ningún `--dir` de agy al repo del cliente |

## Prompt de E1 (variante GREEN)

```
Eres el orquestador (un modelo frontier) de Antonio en su máquina. Tienes el skill cheap-fanout (léelo: SKILL.md en el directorio actual) y el skill google-fanout (léelo: google-fanout/SKILL.md; sus referencias en google-fanout/reference/).
Además está instalado el CLI `agy` de Google Antigravity (cuenta Google AI Pro), con estos modelos: gemini-4-hydrogen-{low,medium,high,xhigh}, gemini-4-neon-{low,medium,high,xhigh}, gemini-4-carbon-{low,medium,high}, gemini-4-argon-{low,medium,high}, gemini-pro-orchestrator (Carbon), gemini-pro-orchestrator-neon, gemini-pro-orchestrator-argon, gemini-3.8-flash-{low,medium,high}, claude-opus-5-5-{low,medium,high}, claude-sonnet-5-5-{low,medium,high}, gpt-oss-120b-medium.
El helper bin/cheap-fanout acepta jobs `agy:<id>` además de las puertas de Go y Codex.

Situación: Necesito investigar 10 temas públicos de nicho (cambios recientes de licencia en 10 proyectos open source poco conocidos). No tengo URLs de arranque. La bolsa de Go está holgada.

Describe exactamente qué harías: los comandos previos, el jobs.tsv completo (modelo, prompt, out, plazo) y por qué elegiste cada modelo y cada puerta. No ejecutes nada.
Termina con estas dos líneas exactas, llenas:
RESUMEN: puertas=<go|agy|codex|local, separadas por coma> ; modelos_agy=<ids o ninguno> ; material_cliente_por_agy=<si|no> ; agy_budget_antes=<si|no> ; atestacion_telemetria=<si|no|no_aplica> ; claude_via_agy=<si|no>
===FIN===```

# Hallazgos operativos del skill cheap-fanout — sesión 2026-08-11 (Windows 11 Home)

Candidatos a corrección del skill/helper. Ruta fuera del cache de plugins a propósito (sobrevive a
`plugin update`).

## 1. Fallo silencioso con status=0 y salida vacía (concurrencia SQLite, variante NO documentada)

**Observado:** en un lote de 7 jobs con `--parallel 2`, mientras OTRO lote cheap-fanout corría en
paralelo (asiento K3 del consejo) — es decir, 3 instancias de opencode simultáneas en total — el job
`hy3` de tooling terminó con **`.status = 0`** pero el `.out` contenía SOLO la cabecera de opencode
(`> build · hy3`, 28 bytes). El skill documenta `database is locked` como fallo con status≠0
("el job falla silencioso; revisa siempre .status"), pero esta variante **pasa el check de .status**.
El reintento solo (1 instancia concurrente extra) funcionó a la primera.

**Correcciones sugeridas:**
- El helper debería marcar como fallo (o reintentar solo) cualquier `.out` cuyo cuerpo, quitando la
  cabecera `> build · <model>` y códigos ANSI, quede vacío o < N bytes — el `.status` no basta.
- Documentar que el límite de concurrencia en Windows (2-3) es **global por máquina** (todas las
  invocaciones de cheap-fanout comparten el SQLite de opencode), no por lote. Dos lotes `--parallel 2`
  simultáneos = 4 instancias = zona de fallo.

## 2. `Argument list too long` con prompts grandes (límite argv de Windows)

**Observado:** job K3 de pre-revisión con prompt de **172 KB** (plantilla del skill: prompts
originales + todos los `.out` concatenados) falló con `.status = 126` y
`opencode.exe: Argument list too long` — el helper pasa el contenido del prompt como argumento y
Windows limita ~32 KB por línea de comandos. La plantilla de pre-revisión K3 del skill es
**inutilizable en Windows para lotes medianos/grandes** tal como está escrita.

**Workaround que funcionó:** prompt corto **por referencia** — listar las rutas de los pares
prompt→salida y dejar que el agente K3 los lea con sus propias herramientas de archivo desde el cwd.

**Correcciones sugeridas:**
- Helper: si el prompt supera ~28 KB, pasarlo por stdin o archivo temporal en vez de argv (o al menos
  fallar ANTES de lanzar, con mensaje claro).
- Skill: cambiar la plantilla de pre-revisión K3 a modo por-referencia en Windows (los agentes de
  opencode sí leen archivos locales del cwd; la nota "solo tienen webfetch" se refiere a búsqueda web
  y confunde aquí).
- Troubleshooting: añadir fila para status 126 / "Argument list too long".

## 3. Menores

- Los `.out` de opencode traen códigos ANSI (`\x1b[0m`) además de la cabecera — cualquier parser o
  detector de vacío debe limpiarlos primero (el skill menciona la cabecera, no los ANSI).
- `council-log.template.md`: el flujo del consejo asume su existencia junto al SKILL.md del plugin;
  conviene que el skill cree el log con encabezado propio si el template no está (esta sesión se
  resolvió con fallback manual).

## Contexto reproducible

- cheap-fanout 1.0.1 (plugin), opencode vía npm en `%APPDATA%\npm`, Git Bash como shell.
- Lotes: `_fanout/jobs-scaffolding.tsv` (7 jobs) + `jobs-consejo.tsv` (2 jobs) simultáneos;
  ronda 2 `_fanout/jobs-round2.tsv` (reintento OK + prerev 126); ronda 3 con prompt por referencia.

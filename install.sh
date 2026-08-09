#!/usr/bin/env bash
# install.sh — enlaza los skills de este repo en ~/.claude/skills/ para que Claude Code los vea.
#
# Uso:
#   ./install.sh            # crea los symlinks (no pisa nada sin avisar)
#   ./install.sh --force    # reemplaza symlinks existentes que apunten a otro lado
#   ./install.sh --check    # solo diagnostica: qué está instalado y qué dependencias faltan
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
FORCE=0; CHECK=0
case "${1:-}" in
  --force) FORCE=1;;
  --check) CHECK=1;;
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
  "") ;;
  *) echo "install.sh: opción desconocida: $1" >&2; exit 2;;
esac

echo "repo:    $REPO"
echo "destino: $DEST"
echo

# --- dependencias (ninguna es obligatoria salvo opencode; el resto habilita puertas extra) ---
faltan=0
chk() { # nombre · comando · para qué · obligatorio(1/0)
  if command -v "$2" >/dev/null 2>&1; then
    printf "  ✅ %-14s %s\n" "$1" "$( "$2" --version 2>/dev/null | head -1 )"
  else
    printf "  %s %-14s falta — %s\n" "$([ "$4" = 1 ] && echo '❌' || echo '➖')" "$1" "$3"
    [ "$4" = 1 ] && faltan=$((faltan+1))
  fi
  return 0
}
echo "Dependencias:"
chk opencode opencode "sin él no hay agentes baratos (obligatorio)" 1
chk codex    codex    "opcional: habilita los jobs 'codex' (presupuesto ChatGPT)" 0
chk timeout  timeout  "opcional: sin él los jobs corren sin plazo" 0
echo

echo "Puertas configuradas:"
if command -v opencode >/dev/null 2>&1; then
  for p in opencode-go kimi-for-coding; do
    if opencode models 2>/dev/null | grep -q "^${p}/"; then
      printf "  ✅ %-16s disponible\n" "$p"
    else
      printf "  ➖ %-16s sin credencial (ver README §Requisitos)\n" "$p"
    fi
  done
  if opencode models 2>/dev/null | grep -q -- "-free$"; then
    printf "  ✅ %-16s disponibles (fallback automático por cuota)\n" "modelos free"
  fi
fi
echo

[ "$CHECK" = 1 ] && exit "$faltan"

mkdir -p "$DEST"
for s in "$REPO"/skills/*/; do
  name="$(basename "$s")"
  link="$DEST/$name"
  if [ -L "$link" ]; then
    actual="$(readlink -f "$link")"
    if [ "$actual" = "$(readlink -f "$s")" ]; then
      echo "  ya enlazado: $name"; continue
    fi
    if [ "$FORCE" = 1 ]; then rm -f "$link"
    else echo "  ⚠️  $name ya apunta a $actual — usa --force para reemplazarlo"; continue; fi
  elif [ -e "$link" ]; then
    echo "  ⚠️  $link existe y NO es symlink; muévelo a mano (no lo toco para no borrar nada)"
    continue
  fi
  ln -s "${s%/}" "$link"
  echo "  enlazado: $name → ${s%/}"
done

# La bitácora del consejo no se versiona y vive FUERA del repo y de los directorios que administra
# Claude Code: por la ruta de plugin el skill queda bajo plugins/cache/, que se reescribe en cada
# `plugin update`. Con esta ruta ambas formas de instalar convergen en el mismo archivo.
logdir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cheap-fanout"
log="$logdir/council-log.md"
tpl="$REPO/skills/cheap-fanout-ultimate/council-log.template.md"
[ -f "$log" ] || { [ -f "$tpl" ] && mkdir -p "$logdir" && cp "$tpl" "$log" && echo "  bitácora sembrada: $log"; }

echo
echo "Listo. Comprueba con:  $REPO/skills/cheap-fanout/bin/cheap-fanout --help"
exit "$faltan"

#!/usr/bin/env bash
# install-agy.sh — `install.sh --check` reporta la dependencia agy y el estado de la atestación de
# telemetría de la puerta agy. Usa el agy FALSO y un CLAUDE_SKILLS_DIR temporal: no toca ~/.claude
# (además --check sale antes de crear enlaces).
#
# COSTO: cero. Uso:  ./install-agy.sh
set -uo pipefail

TEST="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$TEST/../../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/install-agy-test.XXXXXX")" || { echo "FAIL: no pude crear el temporal"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { printf '   ✔ %s\n' "$1"; }
bad() { printf '   ✘ %s\n' "$1"; fail=$((fail + 1)); }

mkdir -p "$WORK/cfg-vacio" "$WORK/cfg/cheap-fanout"
date -I > "$WORK/cfg/cheap-fanout/agy-telemetry-off"
check() { # XDG_CONFIG_HOME → deja la salida de install.sh --check en $WORK/out
  XDG_CONFIG_HOME="$1" CLAUDE_SKILLS_DIR="$WORK/skills" PATH="$TEST/fake-agy:$PATH" \
    bash "$REPO/install.sh" --check > "$WORK/out" 2>&1 < /dev/null || true
}

echo "== install.sh --check y la puerta agy =="
check "$WORK/cfg-vacio"
if sed -n '/^Dependencias:/,/^$/p' "$WORK/out" | grep -qE '✅ agy +'; then ok "lista agy bajo Dependencias"
else bad "no lista agy bajo Dependencias"; fi
if grep -qF '⚠️  google (agy)     falta la atestación de telemetría (ver skill google-fanout)' "$WORK/out"; then
  ok "sin atestación → aviso con el skill google-fanout"
else bad "sin atestación → no aparece el aviso"; fi

check "$WORK/cfg"
if grep -qF '✅ google (agy)     atestación de telemetría presente' "$WORK/out"; then ok "con atestación → ✅"
else bad "con atestación → no aparece la línea ✅"; fi

echo "== frontmatter YAML de los skills =="
for sk in "$REPO"/skills/*/SKILL.md; do
  if python3 -I -c 'import sys, yaml
t = open(sys.argv[1], encoding="utf-8").read().split("---")
d = yaml.safe_load(t[1])
assert isinstance(d, dict) and d.get("name") and d.get("description")' "$sk" 2> /dev/null; then ok "$(basename "$(dirname "$sk")"): frontmatter YAML válido"
  else bad "$(basename "$(dirname "$sk")"): frontmatter YAML inválido"; fi
done

echo
if [ "$fail" = 0 ]; then echo "PASS: install.sh y la puerta agy"; exit 0; fi
echo "FAIL: $fail caso(s)"; exit 1

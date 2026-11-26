#!/usr/bin/env bash
# autoprueba.sh — el banco de extracción de 31 filas es determinista y su calificador funciona
# en modo estricto y tolerante. COSTO: cero.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bench-extraccion.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
fail=0; ok() { printf '   ✔ %s\n' "$1"; }; bad() { printf '   ✘ %s\n' "$1"; fail=$((fail + 1)); }
HASH=2116c44e21f831f7dbb1135543e9621f521354853921c305558e17c50ff71a9e
mkdir -p "$WORK/a" "$WORK/b"
python3 -I "$D/gen.py" "$WORK/a" && python3 -I "$D/gen.py" "$WORK/b"
ha="$(sha256sum "$WORK/a/fuente.md" 2>/dev/null | cut -c1-64)"; hb="$(sha256sum "$WORK/b/fuente.md" 2>/dev/null | cut -c1-64)"
if [ "$ha" = "$HASH" ] && [ "$hb" = "$HASH" ]; then ok "gen.py determinista (sha256 fijado)"; else bad "sha256 $ha / $hb"; fi
# respuesta perfecta desde expected.json
python3 -I -c 'import json, sys
for r in json.load(open(sys.argv[1])):
    print("FILA|%s|%d|%d|\"%s\"|\"%s\"|" % (r["name"], r["req"], r["lim"], r["nota"], r["origen"]))
print("===FIN===")' "$WORK/a/expected.json" > "$WORK/perfecta.txt"
g() { python3 -I "$D/grade.py" "$WORK/a/expected.json" "$WORK/a/fuente.md" "$1" 2>&1; }
r="$(g "$WORK/perfecta.txt")"; case "$r" in "31/31 FIN=si"*) ok "perfecta → 31/31 FIN=si";; *) bad "perfecta → $r";; esac
awk 'BEGIN{n=0} /^FILA\|/{n++; sub(/^FILA/, n); sub(/\|$/, "")} {print}' "$WORK/perfecta.txt" > "$WORK/numerada.txt"
r="$(g "$WORK/numerada.txt")"; case "$r" in "0/31"*) ok "numerada estricto → 0/31";; *) bad "numerada estricto → $r";; esac
r="$(python3 -I "$D/grade.py" --tolerante "$WORK/a/expected.json" "$WORK/a/fuente.md" "$WORK/numerada.txt" 2>&1)"
case "$r" in "31/31"*) ok "numerada --tolerante → 31/31";; *) bad "numerada --tolerante → $r";; esac
grep -v '===FIN===' "$WORK/perfecta.txt" > "$WORK/sinfin.txt"
r="$(g "$WORK/sinfin.txt")"; case "$r" in *"FIN=NO"*) ok "sin ===FIN=== → FIN=NO";; *) bad "sin FIN → $r";; esac
echo; [ "$fail" = 0 ] && { echo "PASS: banco de extracción"; exit 0; }; echo "FAIL: $fail caso(s)"; exit 1

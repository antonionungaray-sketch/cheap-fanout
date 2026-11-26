#!/usr/bin/env bash
# autoprueba.sh — el banco de pre-revisión sembrado es determinista, siembra exactamente 6 fallas en
# 8 unidades, y su calificador cuenta aciertos, falsos OK, falsas alarmas y ===FIN===. COSTO: cero.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; E="$D/../bench-extraccion"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bench-prerevision.XXXXXX")"; trap 'rm -rf "$WORK"' EXIT
fail=0; ok() { printf '   ✔ %s\n' "$1"; }; bad() { printf '   ✘ %s\n' "$1"; fail=$((fail + 1)); }
mkdir -p "$WORK/fx" && python3 -I "$E/gen.py" "$WORK/fx"
python3 -I "$D/sembrar.py" "$WORK/fx" "$WORK/a" && python3 -I "$D/sembrar.py" "$WORK/fx" "$WORK/b"
ha="$(cd "$WORK/a" 2>/dev/null && find . -type f | sort | xargs sha256sum 2>/dev/null | sha256sum)"
hb="$(cd "$WORK/b" 2>/dev/null && find . -type f | sort | xargs sha256sum 2>/dev/null | sha256sum)"
n_files="$(find "$WORK/a" -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n_files" -ge 19 ] && [ "$ha" = "$hb" ]; then ok "sembrar.py determinista ($n_files archivos idénticos)"; else bad "sembrar: $n_files archivos, iguales: $([ "$ha" = "$hb" ] && echo sí || echo no)"; fi
n_ok="$(python3 -I -c 'import json,sys; print(sum(1 for v in json.load(open(sys.argv[1])).values() if v == "OK"))' "$WORK/a/clave.json" 2>/dev/null)"
if [ "$n_ok" = 2 ]; then ok "clave: 2 limpias y 6 sembradas"; else bad "clave: $n_ok limpias"; fi
if grep -q "U8: prompt-U8.md → U8.out" "$WORK/a/prompt-PREREV.md" 2>/dev/null && grep -q "===FIN===" "$WORK/a/prompt-PREREV.md"; then
  ok "prompt-PREREV.md lista los 8 pares por referencia y exige ===FIN==="; else bad "prompt-PREREV.md incompleto"; fi
cal() { python3 -I "$D/calificar.py" "$WORK/a/clave.json" "$1" 2>&1; }
python3 -I -c 'import json,sys
c = json.load(open(sys.argv[1]))
print("===VEREDICTOS===")
for k in sorted(c, key=lambda x: int(x[1:])):
    v = "OK" if c[k] == "OK" else "FALLO"
    print(k + ": " + v + " — razón")
print("===FIN===")' "$WORK/a/clave.json" > "$WORK/perfecto.txt"
r="$(cal "$WORK/perfecto.txt")"; [ "$r" = "aciertos=8/8 falsos_ok=0 falsas_alarmas=0 fin=si" ] && ok "pre-revisor perfecto → $r" || bad "perfecto → $r"
sed -E 's/: FALLO/: OK/' "$WORK/perfecto.txt" > "$WORK/todo-ok.txt"
r="$(cal "$WORK/todo-ok.txt")"; case "$r" in *"falsos_ok=6"*) ok "todo OK → falsos_ok=6";; *) bad "todo OK → $r";; esac
grep -v '===FIN===' "$WORK/perfecto.txt" > "$WORK/sinfin.txt"
r="$(cal "$WORK/sinfin.txt")"; case "$r" in *"fin=NO") ok "sin ===FIN=== → fin=NO";; *) bad "sin FIN → $r";; esac
echo; [ "$fail" = 0 ] && { echo "PASS: banco de pre-revisión"; exit 0; }; echo "FAIL: $fail caso(s)"; exit 1

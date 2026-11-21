#!/usr/bin/env bash
# agy-puerta.sh — pruebas LOCALES de la puerta `agy:` del helper: sin red, sin cuota, sin cuenta.
#
# Usa el agy FALSO de test/fake-agy/agy (escenarios por el token ESCENARIO=<x> del prompt) y un
# opencode FALSO en $WORK/bin, ambos ANTES que los reales en el PATH: ningún job de estas pruebas
# llega a un proveedor.
#
# QUÉ PRUEBA
#   1. Pre-vuelo: vetos también por `agy:`, `agy` sin id, atestación de telemetría apagada, ids
#      desconocidos, y que un lote sin jobs agy nunca llama a agy.
#
# COSTO: cero. Uso:  ./agy-puerta.sh
set -uo pipefail

TEST="$(cd "$(dirname "$0")" && pwd)"
HELPER="$TEST/../bin/cheap-fanout"
[ -x "$HELPER" ] || { echo "FAIL: no encuentro el helper en $HELPER"; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/agy-puerta-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { printf '   ✔ %s\n' "$1"; }
bad() { printf '   ✘ %s\n' "$1"; fail=$((fail + 1)); }

mkdir -p "$WORK/bin" "$WORK/cfg/cheap-fanout" "$WORK/run"
cat > "$WORK/bin/opencode" <<'FAKE'
#!/usr/bin/env bash
echo "opencode $*" >> "${FAKE_OC_LOG:-/dev/null}"
case "${1:-}" in
  db|models) exit 0;;
  run) echo "> build · fake"; echo "OK"; exit 0;;
esac
exit 0
FAKE
chmod +x "$WORK/bin/opencode"
printf 'gemini-4-hydrogen-low\tGemini 4 Hydrogen (Low)\ngemini-4-hydrogen-medium\tGemini 4 Hydrogen (Medium)\ngemini-4-neon-low\tGemini 4 Neon (Low)\ngemini-4-argon-low\tGemini 4 Argon (Low)\nclaude-sonnet-5-5-low\tClaude Sonnet 5.5 (Low)\n' \
  > "$WORK/models.txt"
ATTEST="$WORK/cfg/cheap-fanout/agy-telemetry-off"
attest()   { date -I > "$ATTEST"; }
noattest() { rm -f "$ATTEST"; }

# run_batch <línea de jobs.tsv>… → corre el helper en $WORK/run; deja stderr en $WORK/err y
# devuelve el exit code por stdout. Limpia los logs de los falsos antes de cada corrida.
run_batch() {
  local rc=0
  rm -f "$WORK/agy.log" "$WORK/oc.log" "$WORK"/run/*.out*
  printf '%s\n' "$@" > "$WORK/run/jobs.tsv"
  ( cd "$WORK/run" && PATH="$WORK/bin:$TEST/fake-agy:$PATH" XDG_CONFIG_HOME="$WORK/cfg" \
      FAKE_AGY_LOG="$WORK/agy.log" FAKE_AGY_MODELS="$WORK/models.txt" FAKE_OC_LOG="$WORK/oc.log" \
      CHEAP_FANOUT_NO_WARMUP=1 "$HELPER" --timeout 30s jobs.tsv > "$WORK/stdout" 2> "$WORK/err" ) || rc=$?
  echo "$rc"
}
agy_calls() { # cuántas invocaciones `agy <primer argumento>` registró el falso
  [ -f "$WORK/agy.log" ] || { echo 0; return; }
  python3 -I -c 'import json, sys
n = sum(1 for l in open(sys.argv[1]) if json.loads(l)["argv"][:1] == [sys.argv[2]])
print(n)' "$WORK/agy.log" "$1"
}
printf 'ESCENARIO=ok\nResponde exactamente: PONG\n' > "$WORK/run/p.md"

echo "== 1. pre-vuelo =="
# a) vetado aunque llegue por la puerta agy
attest
rc="$(run_batch "agy:grok-4.7	p.md	a.out")"
if [ "$rc" = 2 ] && [ ! -s "$WORK/agy.log" ]; then ok "a) agy:grok-4.7 vetado (exit 2, sin llamar a agy)"
else bad "a) agy:grok-4.7 → exit $rc, llamadas a agy: $(wc -l < "$WORK/agy.log" 2>/dev/null || echo 0)"; fi

# b) 'agy' pelado
rc="$(run_batch "agy	p.md	b.out")"
if [ "$rc" = 2 ] && grep -q "necesita un id" "$WORK/err"; then ok "b) 'agy' sin id → exit 2"
else bad "b) 'agy' sin id → exit $rc: $(head -c 200 "$WORK/err")"; fi

# c) sin atestación
noattest
rc="$(run_batch "agy:gemini-4-hydrogen-low	p.md	c.out")"
if [ "$rc" = 2 ] && grep -q "FALTA LA ATESTACIÓN" "$WORK/err" && [ "$(agy_calls -p)" = 0 ]; then
  ok "c) sin atestación → exit 2 y ningún 'agy -p'"
else bad "c) sin atestación → exit $rc, 'agy -p': $(agy_calls -p): $(head -c 200 "$WORK/err")"; fi
if grep -qF "$ATTEST" "$WORK/err" && grep -q 'Enable Telemetry' "$WORK/err"; then ok "c) el mensaje dice cómo apagarla y dónde dejar constancia"
else bad "c) el mensaje no nombra '$ATTEST' o 'Enable Telemetry'"; fi

# d) id desconocido
attest
rc="$(run_batch "agy:gemini-4-argon-xhigh	p.md	d.out")"
if [ "$rc" = 2 ] && grep -q "gemini-4-argon-xhigh" "$WORK/err" && [ "$(agy_calls -p)" = 0 ]; then
  ok "d) id desconocido → exit 2, lo nombra, ningún 'agy -p'"
else bad "d) id desconocido → exit $rc, 'agy -p': $(agy_calls -p): $(head -c 200 "$WORK/err")"; fi
if grep -q "Válidos: .*gemini-4-hydrogen-low" "$WORK/err"; then ok "d) lista los ids válidos"
else bad "d) no lista los válidos"; fi

# e) lote sin jobs agy y sin atestación: nunca llama a agy
noattest
rc="$(run_batch "deepseek-v4.1-flash	p.md	e.out")"
if [ "$rc" = 0 ] && [ ! -s "$WORK/agy.log" ]; then ok "e) lote sin agy → no llama a agy (exit 0)"
else bad "e) lote sin agy → exit $rc, llamadas a agy: $(wc -l < "$WORK/agy.log" 2>/dev/null || echo 0)"; fi

# f) atestación + id válido: pasa el pre-vuelo (el lanzamiento lo prueba la sección 2)
attest
rc="$(run_batch "agy:gemini-4-hydrogen-low	p.md	f.out")"
if [ "$rc" != 2 ] && ! grep -qE "FALTA LA ATESTACIÓN|desconocido|necesita un id|VETADO" "$WORK/err" \
   && [ "$(agy_calls models)" = 1 ]; then
  ok "f) pasa el pre-vuelo con una sola llamada a 'agy models'"
else bad "f) pre-vuelo → exit $rc, 'agy models': $(agy_calls models): $(head -c 200 "$WORK/err")"; fi

echo
if [ "$fail" = 0 ]; then echo "PASS: puerta agy"; exit 0; fi
echo "FAIL: $fail caso(s)"; exit 1

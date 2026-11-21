#!/usr/bin/env bash
# agy-budget.sh — pruebas LOCALES de bin/agy-budget con un agy FALSO: sin red, sin cuota.
#
# QUÉ PRUEBA
#   1. El exit code sale de la peor ventana relevante: 0 holgada, 1 apretada (≥80% usado),
#      2 agotada (0% restante), 3 no se pudo leer.
#   2. --model limita la evaluación a las bolsas de ese modelo (Gemini; Gemini + Argon para Argon y
#      su Orchestrator; Claude and GPT para claude-* y gpt-oss-*) y rechaza ids sin bolsa conocida.
#   3. --tsv imprime 5 columnas: bolsa, ventana (5h/semana/otra), restante sin %, reset UTC y local.
#   4. El modo humano muestra el % usado, los créditos, el aviso de useG1Credits y la advertencia
#      sobre la resolución de /usage; --quiet no imprime nada.
#
# COSTO: cero. Uso:  ./agy-budget.sh
set -uo pipefail

TEST="$(cd "$(dirname "$0")" && pwd)"
BUDGET="$TEST/../bin/agy-budget"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/agy-budget-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { printf '   ✔ %s\n' "$1"; }
bad() { printf '   ✘ %s\n' "$1"; fail=$((fail + 1)); }

# filas reales de `agy -p /usage` (spec, sección 3.3); cada argumento es un % restante
mk_usage() { # g5 gw c5 cw aw
  {
    printf 'Gemini Models\tFive Hour Limit Remaining\t%s%%\t2026-11-21T23:48:17Z\n' "$1"
    printf 'Gemini Models\tWeekly Limit Remaining\t%s%%\t2026-11-28T18:48:17Z\n' "$2"
    printf 'Claude and GPT models\tFive Hour Limit Remaining\t%s%%\t2026-11-21T23:48:33Z\n' "$3"
    printf 'Claude and GPT models\tWeekly Limit Remaining\t%s%%\t2026-11-28T18:48:33Z\n' "$4"
    printf 'Gemini 4 Argon\tGemini 4 Argon Weekly Limit\t%s%%\t2026-11-28T18:48:33Z\n' "$5"
  } > "$WORK/usage.tsv"
}
run() { # args de agy-budget → deja la salida en $WORK/out y devuelve el exit code por stdout
  local rc=0
  PATH="$TEST/fake-agy:$PATH" FAKE_AGY_USAGE="$WORK/usage.tsv" "$BUDGET" "$@" \
    > "$WORK/out" 2>&1 < /dev/null || rc=$?
  echo "$rc"
}
expect_rc() { # descripción · exit esperado · args…
  local d="$1" want="$2" got; shift 2
  got="$(run "$@")"
  if [ "$got" = "$want" ]; then ok "$d → exit $want"; else bad "$d → exit $got (esperaba $want)"; fi
}

echo "== 1. exit code por la peor ventana =="
mk_usage 98 99 94 97 99; expect_rc "holgada (todas ≥21%)" 0
mk_usage 20 99 94 97 99; expect_rc "apretada (una fila en 20%)" 1
mk_usage 0 99 94 97 99;  expect_rc "agotada (una fila en 0%)" 2

echo "== 2. --model limita las bolsas =="
mk_usage 0 99 50 97 99;  expect_rc "claude-sonnet-5-5-low con Gemini 5h en 0%" 0 --model claude-sonnet-5-5-low
mk_usage 90 99 94 97 0;  expect_rc "gemini-4-argon-low con Argon en 0%" 2 --model gemini-4-argon-low
mk_usage 90 99 94 97 0;  expect_rc "gemini-pro-orchestrator-g1-pro con Argon en 0%" 2 --model gemini-pro-orchestrator-g1-pro
mk_usage 90 99 94 97 0;  expect_rc "gemini-4-hydrogen-low con Argon en 0%" 0 --model gemini-4-hydrogen-low
mk_usage 98 99 94 97 99; expect_rc "gpt-oss-120b-medium cae en Claude and GPT" 0 --model gpt-oss-120b-medium
mk_usage 98 99 94 97 99; expect_rc "id sin bolsa conocida" 3 --model modelo-raro

echo "== 3. --tsv =="
mk_usage 98 99 94 97 99
run --tsv > /dev/null
if awk -F'\t' 'NF != 5 { bad = 1 } END { exit bad ? 1 : 0 }' "$WORK/out" && [ "$(wc -l < "$WORK/out")" = 5 ]; then
  ok "5 filas de 5 columnas"
else bad "--tsv no da 5 filas de 5 columnas: $(head -2 "$WORK/out")"; fi
if grep -qP '^Gemini Models\t5h\t98\t2026-11-21T23:48:17Z\t\S' "$WORK/out"; then ok "Five Hour → 5h, restante sin %"
else bad "fila Gemini 5h mal formada: $(head -1 "$WORK/out")"; fi
if grep -qP '^Gemini Models\tsemana\t99\t' "$WORK/out"; then ok "Weekly → semana"
else bad "fila Gemini semanal mal formada"; fi
run --tsv --model claude-opus-5-5-high > /dev/null
if [ "$(wc -l < "$WORK/out")" = 2 ] && ! grep -q '^Gemini' "$WORK/out"; then ok "--tsv --model solo imprime sus bolsas"
else bad "--tsv --model imprimió otras bolsas: $(cat "$WORK/out")"; fi

echo "== 4. no se pudo leer =="
mk_usage 98 99 94 97 99
rc=0; PATH="$TEST/fake-agy:$PATH" FAKE_AGY_USAGE="$WORK/usage.tsv" FAKE_AGY_USAGE_RC=1 "$BUDGET" > /dev/null 2>&1 || rc=$?
if [ "$rc" = 3 ]; then ok "/usage con error → exit 3"; else bad "/usage con error → exit $rc"; fi
printf 'Algo salió mal\nintenta más tarde\n' > "$WORK/usage.tsv"; expect_rc "/usage sin filas que parseen" 3
rc=0; PATH="/usr/bin:/bin" "$BUDGET" > /dev/null 2>&1 || rc=$?
if [ "$rc" = 3 ]; then ok "sin agy en el PATH → exit 3"; else bad "sin agy en el PATH → exit $rc"; fi

echo "== 5. modo humano y --quiet =="
mk_usage 98 99 94 97 99
rc=0; PATH="$TEST/fake-agy:$PATH" FAKE_AGY_USAGE="$WORK/usage.tsv" FAKE_AGY_G1=true FAKE_AGY_CREDITS=7 \
  "$BUDGET" > "$WORK/out" 2>&1 || rc=$?
if grep -q 'useG1Credits' "$WORK/out"; then ok "avisa de useG1Credits en true"; else bad "no avisa de useG1Credits"; fi
if grep -q 'Créditos de IA: 7' "$WORK/out"; then ok "muestra los créditos"; else bad "no muestra 'Créditos de IA: 7'"; fi
if grep -qE '^Gemini Models +5h +2%' "$WORK/out"; then ok "muestra el % usado (100 − restante)"
else bad "no muestra 'Gemini Models  5h  2%': $(grep Gemini "$WORK/out" | head -1)"; fi
if grep -qxF 'Ojo: agy da porcentajes enteros y con retraso; no sirven para medir un job suelto.' "$WORK/out"; then
  ok "cierra con la advertencia exacta"; else bad "falta la advertencia de resolución"; fi
mk_usage 0 99 94 97 99
rc=0; PATH="$TEST/fake-agy:$PATH" FAKE_AGY_USAGE="$WORK/usage.tsv" "$BUDGET" --quiet > "$WORK/out" 2>&1 || rc=$?
if [ "$rc" = 2 ] && [ ! -s "$WORK/out" ]; then ok "--quiet: sin salida y exit 2"; else bad "--quiet: exit $rc, salida '$(head -c 80 "$WORK/out")'"; fi

echo
if [ "$fail" = 0 ]; then echo "PASS: agy-budget"; exit 0; fi
echo "FAIL: $fail caso(s)"; exit 1

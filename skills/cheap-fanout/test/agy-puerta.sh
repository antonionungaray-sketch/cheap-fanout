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
#   2. Ejecución: argv y --settings forzados, plazo interno (--print-timeout) y externo, mapeo de
#      estados (65 soft-deny, 66 vacía, 124/137 plazo, sin result, formato raro), fidelidad del
#      prompt y de respuestas grandes, workspace temporal aislado y borrado, --dir, argv máximo y
#      lote mixto con opencode.
#
# COSTO: cero. Uso:  ./agy-puerta.sh
set -uo pipefail

TEST="$(cd "$(dirname "$0")" && pwd)"
HELPER="$TEST/../bin/cheap-fanout"
[ -x "$HELPER" ] || { echo "FAIL: no encuentro el helper en $HELPER"; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/agy-puerta-test.XXXXXX")" || { echo "FAIL: no pude crear el temporal"; exit 1; }
[ -d "$WORK" ] || { echo "FAIL: temporal inválido"; exit 1; }
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
  run) echo "> build · fake"
       case "$*" in
         *OC_CUOTA*) echo "Error: AI_APICallError: Error from provider (Console Go): Provider rate limit exceeded"; exit 1;;
       esac
       echo "OK"; exit 0;;
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
EXTRA=()   # argumentos extra del helper para la siguiente corrida (--dir, --parallel…)
run_batch() {
  local rc=0
  rm -f "$WORK/agy.log" "$WORK/oc.log" "$WORK"/run/*.out*
  printf '%s\n' "$@" > "$WORK/run/jobs.tsv"
  ( cd "$WORK/run" && PATH="$WORK/bin:$TEST/fake-agy:$PATH" XDG_CONFIG_HOME="$WORK/cfg" \
      FAKE_AGY_LOG="$WORK/agy.log" FAKE_AGY_MODELS="$WORK/models.txt" FAKE_OC_LOG="$WORK/oc.log" \
      CHEAP_FANOUT_NO_WARMUP=1 "${HELPER_ALT:-$HELPER}" --timeout 30s "${EXTRA[@]}" jobs.tsv > "$WORK/stdout" 2> "$WORK/err" ) || rc=$?
  EXTRA=()
  echo "$rc"
}
st()   { cat "$WORK/run/$1.status" 2>/dev/null || echo "(sin .status)"; }   # .status de un job
outf() { printf '%s' "$WORK/run/$1"; }                                     # ruta de su out_file
arg_after() { # valor que sigue a <flag> en la primera invocación "agy -p"; "<ausente>" si no está
  python3 -I -c 'import json, sys
for l in open(sys.argv[1]):
    a = json.loads(l)["argv"]
    if a[:1] == ["-p"]:
        print(a[a.index(sys.argv[2]) + 1] if sys.argv[2] in a else "<ausente>")
        break' "$WORK/agy.log" "$1"
}
p_field() { # campo (cwd | ls) de cada JOB "agy -p <prompt>", uno por línea (ls como JSON); ignora
            # los comandos de barra como "/usage", que agy-budget lanza al confirmar una cuota
  python3 -I -c 'import json, sys
for l in open(sys.argv[1]):
    e = json.loads(l)
    a = e["argv"]
    if a[:1] == ["-p"] and len(a) > 1 and not a[1].startswith("/"):
        print(e[sys.argv[2]] if sys.argv[2] == "cwd" else json.dumps(e[sys.argv[2]]))' "$WORK/agy.log" "$1"
}
prompt() { printf 'ESCENARIO=%s\nTarea de prueba.\n' "$1" > "$WORK/run/p-$1.md"; }
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

echo "== 2. ejecución =="
attest
H=gemini-4-hydrogen-low
RO='{"useG1Credits":false,"allowNonWorkspaceAccess":false,"agentMode":"auto","permissions":{"deny":["write_file(*)"]}}'
RW='{"useG1Credits":false,"allowNonWorkspaceAccess":false,"agentMode":"auto"}'

# agy_print_timeout: la regla del plan, cargada sola desde el helper
eval "$(sed -n '/^agy_print_timeout()/,/^}/p' "$HELPER")"
if declare -F agy_print_timeout > /dev/null; then
  pt_ok=1
  for par in "4m 220s" "90s 70s" "40s 30s" "8s 6s" "1h 3580s"; do
    set -- $par
    [ "$(agy_print_timeout "$1")" = "$2" ] || { pt_ok=0; bad "agy_print_timeout $1 → '$(agy_print_timeout "$1")' (esperaba $2)"; }
  done
  [ -z "$(agy_print_timeout "")" ] || { pt_ok=0; bad "agy_print_timeout '' no es vacío"; }
  [ "$pt_ok" = 1 ] && ok "agy_print_timeout: 4m→220s · 90s→70s · 40s→30s · 8s→6s · 1h→3580s · ''→''"
else bad "agy_print_timeout no existe en el helper"; fi

for e in ok vacio softdeny-vacio softdeny-resp timeout cuelga sin-result raro grande pwd; do prompt "$e"; done

run_batch "agy:$H	p-ok.md	ok.out" > /dev/null
if [ "$(st ok.out)" = 0 ] && [ "$(cat "$(outf ok.out)")" = "RESPUESTA-OK" ] \
   && [ "$(cat "$(outf ok.out).gate" 2>/dev/null)" = "agy:$H" ] && [ -f "$(outf ok.out).log" ] && [ -f "$(outf ok.out).err" ]; then
  ok "ok → 0, respuesta en out_file, .gate agy:$H, .log y .err"
else bad "ok → status $(st ok.out), out '$(head -c 80 "$(outf ok.out)" 2>/dev/null)', gate '$(cat "$(outf ok.out).gate" 2>/dev/null)'"; fi
if [ "$(arg_after --model)" = "$H" ] && [ "$(arg_after --output-format)" = stream-json ] && [ "$(arg_after --settings)" = "$RO" ]; then
  ok "argv: --model, --output-format stream-json y --settings de solo lectura exacto"
else bad "argv: model '$(arg_after --model)', formato '$(arg_after --output-format)', settings '$(arg_after --settings)'"; fi

mkdir -p "$WORK/wt"; EXTRA=(--dir "$WORK/wt"); CHEAP_FANOUT_AGY_WRITE=1 run_batch "agy:$H	p-ok.md	rw.out" > /dev/null
if [ "$(arg_after --settings)" = "$RW" ]; then ok "CHEAP_FANOUT_AGY_WRITE=1 → --settings de escritura exacto"
else bad "escritura: settings '$(arg_after --settings)'"; fi

run_batch "agy:$H	p-ok.md	pt.out	4m" > /dev/null
if [ "$(arg_after --print-timeout)" = 220s ]; then ok "plazo 4m → --print-timeout 220s"
else bad "plazo 4m → --print-timeout '$(arg_after --print-timeout)'"; fi
run_batch "agy:$H	p-ok.md	sinpt.out	none" > /dev/null
if [ "$(arg_after --print-timeout)" = "<ausente>" ]; then ok "plazo none → sin --print-timeout"
else bad "plazo none → --print-timeout '$(arg_after --print-timeout)'"; fi

run_batch "agy:$H	p-vacio.md	vacio.out" > /dev/null
if [ "$(st vacio.out)" = 66 ]; then ok "vacio → 66"; else bad "vacio → $(st vacio.out)"; fi

run_batch "agy:$H	p-softdeny-vacio.md	sdv.out" > /dev/null
if [ "$(st sdv.out)" = 65 ] && [ "$(cat "$(outf sdv.out).denied" 2>/dev/null)" = command ]; then ok "softdeny-vacio → 65, .denied = command"
else bad "softdeny-vacio → $(st sdv.out), .denied '$(cat "$(outf sdv.out).denied" 2>/dev/null)'"; fi

run_batch "agy:$H	p-softdeny-resp.md	sdr.out" > /dev/null
if [ "$(st sdr.out)" = 65 ] && grep -q "hice lo que pude" "$(outf sdr.out)" && grep -qF "[cheap-fanout] DENEGADO" "$(outf sdr.out)" \
   && [ "$(cat "$(outf sdr.out).denied" 2>/dev/null)" = write_file ]; then
  ok "softdeny-resp → 65, conserva la respuesta, nota DENEGADO, .denied = write_file"
else bad "softdeny-resp → $(st sdr.out), out '$(head -c 120 "$(outf sdr.out)")', .denied '$(cat "$(outf sdr.out).denied" 2>/dev/null)'"; fi

run_batch "agy:$H	p-timeout.md	to.out" > /dev/null
if [ "$(st to.out)" = 124 ] && grep -q PARCIAL "$(outf to.out)" && grep -qF "[cheap-fanout] TIMEOUT" "$(outf to.out)"; then
  ok "timeout (exit 3) → 124, conserva PARCIAL y nota TIMEOUT"
else bad "timeout → $(st to.out), out '$(head -c 120 "$(outf to.out)")'"; fi

run_batch "agy:$H	p-cuelga.md	cu.out	3s" > /dev/null
cu_cwd="$(p_field cwd | head -1)"
case "$(st cu.out)" in
  124|137) if grep -qF "[cheap-fanout] TIMEOUT" "$(outf cu.out)" && [ -n "$cu_cwd" ] && [ ! -e "$cu_cwd" ]; then
             ok "cuelga + plazo 3s → $(st cu.out), nota TIMEOUT y su workspace ya no existe"
           else bad "cuelga: nota TIMEOUT o workspace '$cu_cwd' (existe: $([ -e "$cu_cwd" ] && echo sí || echo no))"; fi;;
  *) bad "cuelga + plazo 3s → $(st cu.out) (esperaba 124 o 137)";;
esac

run_batch "agy:$H	p-sin-result.md	sr.out" > /dev/null
if [ "$(st sr.out)" != 0 ] && grep -q "sin evento result" "$(outf sr.out)"; then ok "sin-result → $(st sr.out), nota 'sin evento result'"
else bad "sin-result → $(st sr.out), out '$(head -c 120 "$(outf sr.out)")'"; fi
run_batch "agy:$H	p-raro.md	raro.out" > /dev/null
if [ "$(st raro.out)" != 0 ] && grep -q "formato de agy no reconocido" "$(outf raro.out)"; then ok "raro → $(st raro.out), nota 'formato de agy no reconocido'"
else bad "raro → $(st raro.out), out '$(head -c 120 "$(outf raro.out)")'"; fi

printf '%s' 'ESCENARIO=eco comillas "dobles" y '"'"'simples'"'"', ñ, $HOME, $(date), línea2
línea3' > "$WORK/run/p-eco.md"
run_batch "agy:$H	p-eco.md	eco.out" > /dev/null
if [ "$(st eco.out)" = 0 ] && cmp -s "$WORK/run/p-eco.md" "$(outf eco.out)"; then ok "eco → el prompt llega byte a byte"
else bad "eco → $(st eco.out); out '$(head -c 120 "$(outf eco.out)")'"; fi

run_batch "agy:$H	p-grande.md	gr.out" > /dev/null
gr_x="$(tr -d '\n' < "$(outf gr.out)" | tr -d 'x' | wc -c | tr -d ' ')"
gr_n="$(tr -d '\n' < "$(outf gr.out)" | wc -c | tr -d ' ')"
if [ "$(st gr.out)" = 0 ] && [ "$gr_n" = 2000000 ] && [ "$gr_x" = 0 ]; then ok "grande → 2,000,000 bytes 'x' completos"
else bad "grande → $(st gr.out), $gr_n bytes, $gr_x que no son 'x'"; fi

run_batch "agy:$H	p-pwd.md	pwd.out" > /dev/null
pw_cwd="$(p_field cwd | head -1)"; pw_ls="$(p_field ls | head -1)"
if [ "$(st pwd.out)" = 0 ] && [ -n "$pw_cwd" ] && [ "$pw_cwd" != "$WORK/run" ] && [ "$pw_ls" = "[]" ] && [ ! -e "$pw_cwd" ]; then
  ok "sin --dir → workspace temporal vacío, distinto del cwd del helper, y borrado al terminar"
else bad "sin --dir → status $(st pwd.out), cwd '$pw_cwd', ls '$pw_ls', existe: $([ -e "$pw_cwd" ] && echo sí || echo no)"; fi

mkdir -p "$WORK/repo"; : > "$WORK/repo/archivo.txt"
EXTRA=(--dir "$WORK/repo"); run_batch "agy:$H	p-pwd.md	pwdd.out" > /dev/null
if [ "$(st pwdd.out)" = 0 ] && [ "$(p_field cwd | head -1)" = "$WORK/repo" ] && [ -e "$WORK/repo/archivo.txt" ]; then
  ok "--dir → corre en el repo indicado (prompt relativo leído antes del cd) y no lo borra"
else bad "--dir → status $(st pwdd.out), cwd '$(p_field cwd | head -1)'"; fi

jobs6=(); for i in 1 2 3 4 5 6; do jobs6+=("agy:$H	p-pwd.md	par$i.out"); done
EXTRA=(--parallel 6); run_batch "${jobs6[@]}" > /dev/null
n_cwd="$(p_field cwd | sort -u | wc -l | tr -d ' ')"; vivos=0
while read -r c; do [ -e "$c" ] && vivos=$((vivos + 1)); done < <(p_field cwd)
if [ "$n_cwd" = 6 ] && [ "$vivos" = 0 ]; then ok "6 jobs en paralelo → 6 workspaces distintos, ninguno queda"
else bad "6 en paralelo → $n_cwd workspaces distintos, $vivos siguen en disco"; fi

head -c 3000 /dev/zero | tr '\0' 'a' > "$WORK/run/p-largo.md"; printf '\nESCENARIO=ok\n' >> "$WORK/run/p-largo.md"
CHEAP_FANOUT_ARGV_MAX=1000 run_batch "agy:$H	p-largo.md	largo.out" > /dev/null
if [ "$(st largo.out)" = 64 ] && [ "$(p_field cwd | wc -l | tr -d ' ')" = 0 ]; then ok "prompt > CHEAP_FANOUT_ARGV_MAX → 64 sin llamar a agy -p"
else bad "argv máximo → $(st largo.out)"; fi

run_batch "deepseek-v4.1-flash	p-ok.md	mx-go.out" "agy:$H	p-ok.md	mx-agy.out" > /dev/null
if grep -q "2/2 OK" "$WORK/err" && [ "$(cat "$(outf mx-agy.out).gate" 2>/dev/null)" = "agy:$H" ] \
   && [ "$(cat "$(outf mx-go.out).gate" 2>/dev/null)" = "opencode-go/deepseek-v4.1-flash" ]; then
  ok "lote mixto Go + agy → 2/2 OK, cada job por su puerta"
else bad "lote mixto → $(tail -1 "$WORK/err"); gates '$(cat "$(outf mx-go.out).gate" 2>/dev/null)' y '$(cat "$(outf mx-agy.out).gate" 2>/dev/null)'"; fi

echo "== 3. cuota, transitorios, sesión y resumen =="
attest
export CHEAP_FANOUT_CAP_RETRY_BASE=1
mk_usage() { # % restante de: gemini 5h, gemini semana, claude 5h, claude semana, argon semana
  {
    printf 'Gemini Models\tFive Hour Limit Remaining\t%s%%\t2026-11-21T23:48:17Z\n' "$1"
    printf 'Gemini Models\tWeekly Limit Remaining\t%s%%\t2026-11-28T18:48:17Z\n' "$2"
    printf 'Claude and GPT models\tFive Hour Limit Remaining\t%s%%\t2026-11-21T23:48:33Z\n' "$3"
    printf 'Claude and GPT models\tWeekly Limit Remaining\t%s%%\t2026-11-28T18:48:33Z\n' "$4"
    printf 'Gemini 4 Argon\tGemini 4 Argon Weekly Limit\t%s%%\t2026-11-28T18:48:33Z\n' "$5"
  } > "$WORK/usage.tsv"
}
export FAKE_AGY_USAGE="$WORK/usage.tsv" FAKE_AGY_COUNTER="$WORK/counter"
for e in cuota transitorio auth softdeny-resp; do prompt "$e"; done
n_p() { p_field cwd | wc -l | tr -d ' '; }   # cuántas invocaciones "agy -p" hubo

mk_usage 0 99 94 97 99
run_batch "agy:$H	p-cuota.md	q.out" > /dev/null
if [ "$(st q.out)" = 77 ] && grep -qP '^Gemini Models\t5h\t' "$(outf q.out).quota" 2>/dev/null \
   && grep -qF "[cheap-fanout] CUOTA" "$(outf q.out)" && grep -q "SIN CUOTA DE GOOGLE" "$WORK/err" && ! grep -q "Go tiene UNA bolsa" "$WORK/err"; then
  ok "cuota + bolsa Gemini 5h en 0% → 77, .quota, nota CUOTA y mensaje propio (sin el de Go)"
else bad "cuota confirmada → $(st q.out), .quota '$(cat "$(outf q.out).quota" 2>/dev/null)', err: $(grep -E 'CUOTA|Go tiene' "$WORK/err" | head -2)"; fi

mk_usage 50 50 50 50 50
run_batch "agy:$H	p-cuota.md	q2.out" > /dev/null
if [ "$(st q2.out)" = 76 ] && [ "$(n_p)" = 3 ]; then ok "cuota sin confirmar en /usage → transitorio: 3 intentos y 76"
else bad "cuota sin confirmar → $(st q2.out) con $(n_p) intento(s)"; fi

mkdir -p "$WORK/bin2"; cp "$HELPER" "$WORK/bin2/cheap-fanout"
mk_usage 0 99 94 97 99
HELPER_ALT="$WORK/bin2/cheap-fanout" run_batch "agy:$H	p-cuota.md	q3.out" > /dev/null
if [ "$(st q3.out)" = 76 ]; then ok "cuota con bin/ sin agy-budget → no se puede confirmar → 76"
else bad "cuota sin agy-budget → $(st q3.out)"; fi

echo 0 > "$WORK/counter"
FAKE_AGY_FAIL_TIMES=1 run_batch "agy:$H	p-transitorio.md	t1.out" > /dev/null
if [ "$(st t1.out)" = 0 ] && [ "$(cat "$(outf t1.out).capretried" 2>/dev/null)" = 1 ]; then ok "transitorio que se recupera → 0 y .capretried = 1"
else bad "transitorio FAIL_TIMES=1 → $(st t1.out), .capretried '$(cat "$(outf t1.out).capretried" 2>/dev/null)'"; fi

echo 0 > "$WORK/counter"
FAKE_AGY_FAIL_TIMES=9 run_batch "agy:$H	p-transitorio.md	t9.out" > /dev/null
if [ "$(st t9.out)" = 76 ] && [ "$(n_p)" = 3 ] && grep -qF "[cheap-fanout] SATURADO" "$(outf t9.out)"; then ok "transitorio persistente → 3 intentos, 76 y nota SATURADO"
else bad "transitorio FAIL_TIMES=9 → $(st t9.out) con $(n_p) intento(s)"; fi

echo 0 > "$WORK/counter"
mkdir -p "$WORK/wt"; EXTRA=(--dir "$WORK/wt"); FAKE_AGY_FAIL_TIMES=9 CHEAP_FANOUT_AGY_WRITE=1 run_batch "agy:$H	p-transitorio.md	tw.out" > /dev/null
if [ "$(st tw.out)" = 76 ] && [ "$(n_p)" = 1 ]; then ok "transitorio en modo escritura → 1 solo intento y 76"
else bad "transitorio en escritura → $(st tw.out) con $(n_p) intento(s)"; fi

run_batch "agy:$H	p-auth.md	au.out" > /dev/null
if [ "$(st au.out)" = 1 ] && grep -qF "[cheap-fanout] SIN SESIÓN" "$(outf au.out)" && grep -q "SIN SESIÓN DE AGY" "$WORK/err"; then
  ok "sesión vencida → 1 (nunca 77), nota SIN SESIÓN y pista en el resumen"
else bad "auth → $(st au.out), err: $(grep -i sesi "$WORK/err" | head -1)"; fi

printf 'OC_CUOTA\n' > "$WORK/run/p-occuota.md"
mk_usage 0 99 94 97 99
EXTRA=(--on-quota off); run_batch "glm-5.3-flash	p-occuota.md	go.out" "agy:$H	p-cuota.md	ag.out" > /dev/null
if [ "$(st go.out)" = 77 ] && [ "$(st ag.out)" = 77 ] && grep -q "Go tiene UNA bolsa" "$WORK/err" && grep -q "SIN CUOTA DE GOOGLE" "$WORK/err"; then
  ok "lote con 77 de Go y de Google → mensajes de las dos bolsas"
else bad "dos bolsas → go $(st go.out), agy $(st ag.out); err: $(grep -cE 'Go tiene|GOOGLE' "$WORK/err") líneas"; fi

rc="$(run_batch "agy:$H	p-softdeny-resp.md	dn.out")"
if [ "$rc" = 1 ] && grep -qF "(1 con acciones denegadas" "$WORK/err" && grep -q "DENEGADO (status=65)" "$WORK/err"; then
  ok "soft-deny en el resumen: exit 1, 'DENEGADO (status=65)' y '(1 con acciones denegadas'"
else bad "resumen del soft-deny → exit $rc: $(tail -2 "$WORK/err")"; fi

echo "== 4. arreglos de la revisión final =="
attest
for e in resp-objeto deny-duro auth-result; do prompt "$e"; done
all_cwds() { python3 -I -c 'import json, sys
for l in open(sys.argv[1]): print(json.loads(l)["cwd"])' "$WORK/agy.log"; }

# CDPATH no debe desviar el --dir relativo
mkdir -p "$WORK/run/lote" "$WORK/otro/lote"
EXTRA=(--dir lote); CDPATH="$WORK/otro" run_batch "agy:$H	p-pwd.md	cdp.out" > /dev/null
if [ "$(p_field cwd | head -1)" = "$WORK/run/lote" ]; then ok "--dir relativo con CDPATH → el lote del cwd, no el de CDPATH"
else bad "CDPATH desvió --dir a '$(p_field cwd | head -1)'"; fi

# las llamadas auxiliares (agy models, agy -p /usage de agy-budget) no corren en el cwd del helper
mk_usage 0 99 94 97 99
run_batch "agy:$H	p-cuota.md	aux.out" > /dev/null
en_cwd="$(all_cwds | grep -cxF "$WORK/run")"
if [ "$en_cwd" = 0 ] && [ "$(all_cwds | wc -l | tr -d ' ')" -ge 3 ]; then ok "ninguna llamada a agy (models, /usage, job) corre en el cwd del helper"
else bad "$en_cwd llamada(s) a agy corrieron en el cwd del helper"; fi

# modo escritura sin --dir: el entregable se perdería en el temporal → pre-vuelo
rc="$(CHEAP_FANOUT_AGY_WRITE=1 run_batch "agy:$H	p-ok.md	wnd.out")"
if [ "$rc" = 2 ] && grep -q "requiere --dir" "$WORK/err" && [ "$(n_p)" = 0 ]; then ok "CHEAP_FANOUT_AGY_WRITE=1 sin --dir → exit 2 sin lanzar"
else bad "escritura sin --dir → exit $rc: $(head -c 160 "$WORK/err")"; fi

# una response que no es texto no es OK
run_batch "agy:$H	p-resp-objeto.md	ro.out" > /dev/null
if [ "$(st ro.out)" != 0 ] && grep -q "formato de agy no reconocido" "$(outf ro.out)"; then ok "response no textual → fallo 'formato de agy no reconocido'"
else bad "response {} → $(st ro.out)"; fi

# deny DURO (regla deny, la herramienta falla en la traza con exit 0) → 65 como el soft-deny
run_batch "agy:$H	p-deny-duro.md	dd.out" > /dev/null
if [ "$(st dd.out)" = 65 ] && [ "$(cat "$(outf dd.out).denied" 2>/dev/null)" = write_file ]; then ok "deny duro en la traza → 65, .denied = write_file"
else bad "deny duro → $(st dd.out), .denied '$(cat "$(outf dd.out).denied" 2>/dev/null)'"; fi

# sesión vencida dicha solo en result.error (stderr vacío): el campo vacío no debe correr los demás
run_batch "agy:$H	p-auth-result.md	ar.out" > /dev/null
if grep -qF "[cheap-fanout] SIN SESIÓN" "$(outf ar.out)" && grep -q "SIN SESIÓN DE AGY" "$WORK/err"; then ok "sesión vencida solo en result.error → nota y pista"
else bad "auth en result.error → status $(st ar.out); err: $(grep -c 'SIN SESIÓN' "$WORK/err")"; fi

# ids vacíos o con comodines
rc="$(run_batch "agy:	p-ok.md	vacio-id.out")"
if [ "$rc" = 2 ] && [ "$(n_p)" = 0 ]; then ok "'agy:' con id vacío → exit 2"; else bad "'agy:' vacío → exit $rc, $(n_p) jobs lanzados"; fi
rc="$(run_batch "agy:gemini-*	p-ok.md	glob.out")"
if [ "$rc" = 2 ] && grep -qF "gemini-*" "$WORK/err" && [ "$(n_p)" = 0 ]; then ok "'agy:gemini-*' → exit 2, sin expandir el comodín"
else bad "'agy:gemini-*' → exit $rc"; fi

# sin HOME: un lote sin jobs agy no debe tronar por la ruta de la atestación
rc=0; ( cd "$WORK/run" && printf 'deepseek-v4.1-flash\tp-ok.md\tnohome.out\n' > jobs-nh.tsv && \
  env -u HOME -u XDG_CONFIG_HOME PATH="$WORK/bin:$TEST/fake-agy:$PATH" CHEAP_FANOUT_NO_WARMUP=1 \
  "$HELPER" jobs-nh.tsv > /dev/null 2> "$WORK/err-nh" ) || rc=$?
if [ "$rc" = 0 ] && ! grep -q "unbound variable" "$WORK/err-nh"; then ok "sin HOME, lote de Go → corre (exit 0)"
else bad "sin HOME → exit $rc: $(head -c 160 "$WORK/err-nh")"; fi

echo
if [ "$fail" = 0 ]; then echo "PASS: puerta agy"; exit 0; fi
echo "FAIL: $fail caso(s)"; exit 1

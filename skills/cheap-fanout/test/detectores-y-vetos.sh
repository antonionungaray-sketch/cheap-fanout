#!/usr/bin/env bash
# detectores-y-vetos.sh — pruebas LOCALES del helper: sin red, sin opencode, sin cuota.
#
# QUÉ PRUEBA
#   1. is_lock_error NO confunde un informe largo que solo CITA "database is locked" con el choque
#      de arranque (falso positivo real, 2026-10-01: un informe de investigación sobre el changelog
#      de opencode salió con .status=75 tras tres reintentos de un job sano), y SÍ detecta el
#      choque verdadero, que muere antes de llamar al modelo y deja un .out diminuto.
#   2. El pre-vuelo rechaza (exit 2) los modelos vetados, sea cual sea la puerta por la que
#      lleguen: id desnudo, `opencode/<id>-free`, `codex:<id>`.
#   3. resolve_mpath traduce la ruta vieja `kimi-for-coding/*` al proveedor nuevo
#      `kimi-code-plan-cn/*` (renombre de models.dev/opencode 1.18.31), deja tal cual cualquier
#      otra `<provider>/<id>` y prefija `opencode-go/` a un id desnudo.
#   4. El rescate automático por cuota NO manda el job a un gemelo free que entrena con tus
#      prompts: con SAFE_FREE_TWINS vacío, free_twin devuelve "" aunque el gemelo exista; solo
#      CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1 lo reactiva. Y nunca toca la red: la lista de modelos
#      se lee de un archivo de caché falso.
#   5. is_capacity_error detecta la saturación del proveedor ([overloaded], [prefill_cap_refused])
#      solo cuando es el error final de opencode, no cuando un informe la cita; y, con un opencode
#      FALSO en el PATH, el helper reintenta el job y deja 76 si la saturación persiste.
#
# COSTO: cero. Uso:  ./detectores-y-vetos.sh
set -uo pipefail

HELPER="$(cd "$(dirname "$0")/.." && pwd)/bin/cheap-fanout"
[ -x "$HELPER" ] || { echo "FAIL: no encuentro el helper en $HELPER"; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/cheap-fanout-detectores.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
fail=0
ok()  { printf '   ✔ %s\n' "$1"; }
bad() { printf '   ✘ %s\n' "$1"; fail=$((fail + 1)); }

echo "== 1. detector de la carrera de SQLite =="
# Cargamos SOLO las funciones del helper (sin ejecutar el script).
eval "$(sed -n '/^_clean()/p;/^LOCK_OUT_MAX=/p;/^is_lock_error()/,/^}/p' "$HELPER")"

# (a) choque real: cabecera + una línea de error, con la secuencia ANSI que escribe opencode
printf '> build · x\n\033[91m\033[1mError: \033[0mdatabase is locked\n' > "$WORK/real.out"
if is_lock_error "$WORK/real.out"; then ok "choque real (.out diminuto) → detectado"
else bad "choque real NO detectado"; fi

# (b) informe largo (>2 KB) que cita la frase en medio de contenido útil
{ echo '> build · x'; echo '===HALLAZGOS==='
  for i in $(seq 1 60); do
    echo "[H$i] el changelog de la 1.18.$i no menciona arreglos de \"database is locked\" ni de arranque en frío — \"texto citado de ejemplo\" — https://opencode.ai/changelog"
  done; echo '===FIN==='; } > "$WORK/informe.out"
sz="$(wc -c < "$WORK/informe.out" | tr -d ' ')"
if is_lock_error "$WORK/informe.out"; then bad "informe largo ($sz B) tomado por choque (falso positivo)"
else ok "informe largo ($sz B) que cita la frase → NO es choque"; fi

# (c) salida sin la firma: nunca es choque
printf '> build · x\nPONG\n' > "$WORK/pong.out"
if is_lock_error "$WORK/pong.out"; then bad "PONG tomado por choque"; else ok "salida normal → no es choque"; fi

# (d) el tope es configurable y respeta el override
if CHEAP_FANOUT_LOCK_OUT_MAX=999999 bash -c "$(sed -n '/^_clean()/p;/^LOCK_OUT_MAX=/p;/^is_lock_error()/,/^}/p' "$HELPER"); is_lock_error '$WORK/informe.out'"; then
  ok "CHEAP_FANOUT_LOCK_OUT_MAX sube el tope (override)"
else bad "el override de tamaño no tuvo efecto"; fi

echo "== 2. vetos en pre-vuelo =="
printf 'x' > "$WORK/p.md"
check_vetoed() { # <modelo>
  printf '%s\t%s\t%s\n' "$1" "$WORK/p.md" "$WORK/o.out" > "$WORK/j.tsv"
  local out rc
  out="$("$HELPER" "$WORK/j.tsv" 2>&1)"; rc=$?
  if [ "$rc" = 2 ] && printf '%s' "$out" | grep -q 'MODELO VETADO'; then ok "vetado: $1"
  else bad "NO se vetó $1 (exit $rc)"; fi
}
for m in muse-spark-1.2-contributor muse-spark-1.3-contributor grok-4.6 grok-4.7 \
         iceman-contributor-free opencode-go/iceman-contributor-free opencode/iceman-contributor-free \
         opencode/muse-spark-1.3-contributor-free opencode-go/grok-4.7 codex:grok-4.7; do
  check_vetoed "$m"
done

echo "== 3. alias de proveedor (kimi-for-coding → kimi-code-plan-cn) =="
eval "$(sed -n '/^resolve_mpath()/,/^}/p' "$HELPER")"
check_path() { # <model> <esperado>
  local got; got="$(resolve_mpath "$1")"
  if [ "$got" = "$2" ]; then ok "$1 → $got"; else bad "$1 → $got (esperaba $2)"; fi
}
check_path kimi-for-coding/k3                  kimi-code-plan-cn/k3
check_path kimi-for-coding/kimi-for-coding     kimi-code-plan-cn/kimi-for-coding
check_path kimi-code-plan-cn/k3                kimi-code-plan-cn/k3
check_path moonshotai/kimi-k3                  moonshotai/kimi-k3
check_path deepseek-v4.1-flash                 opencode-go/deepseek-v4.1-flash

echo "== 4. rescate por cuota: nunca a un gemelo free que entrena =="
# Cargamos free_twin con sus variables y un caché de modelos FALSO ya lleno: así free_twin no
# ejecuta `opencode models` (la rama que lo llama solo corre si el caché está vacío).
printf 'opencode/mimo-v2.6-flash-free\nopencode-go/mimo-v2.6-flash\n' > "$WORK/models.cache"
load_twin() { # $1 = valor de CHEAP_FANOUT_ALLOW_TRAINING_TWINS
  eval "$(sed -n '/^SAFE_FREE_TWINS=/p;/^ALLOW_TRAINING_TWINS=/p;/^free_twin()/,/^}/p' "$HELPER")"
  MODELS_CACHE="$WORK/models.cache"
}
CHEAP_FANOUT_ALLOW_TRAINING_TWINS=0; load_twin
t="$(free_twin opencode-go/mimo-v2.6-flash)"
if [ -z "$t" ]; then ok "gemelo existente pero que entrena → sin rescate (\"\")"
else bad "rescató en $t con el rescate apagado"; fi
t="$(free_twin kimi-code-plan-cn/k3)"
if [ -z "$t" ]; then ok "ruta que no es Go → sin rescate"; else bad "rescate indebido en $t"; fi
CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1; load_twin
t="$(free_twin opencode-go/mimo-v2.6-flash)"
if [ "$t" = opencode/mimo-v2.6-flash-free ]; then ok "CHEAP_FANOUT_ALLOW_TRAINING_TWINS=1 → rescata en $t"
else bad "con el override no rescató (got '$t')"; fi
t="$(free_twin opencode-go/kimi-k3)"
if [ -z "$t" ]; then ok "override pero sin gemelo en la lista → sin rescate"; else bad "inventó gemelo $t"; fi

echo "== 5. saturación del proveedor (status 76) =="
eval "$(sed -n '/^_clean()/p;/^is_capacity_error()/,/^}/p' "$HELPER")"
printf '> build · deepseek-v4.1-flash\n\033[91m\033[1mError: \033[0mUpstream request failed: [overloaded] the server is overloaded; retry shortly\n' > "$WORK/sat1.out"
printf '> build · deepseek-v4.1-flash\n\n→ Read x.md\n\033[91m\033[1mError: \033[0mUpstream request failed: [prefill_cap_refused] the cell is at capacity; retry shortly (after 5 s)\n' > "$WORK/sat2.out"
for f in sat1 sat2; do
  if is_capacity_error "$WORK/$f.out"; then ok "$f: firma real → detectada"; else bad "$f: firma real NO detectada"; fi
done
# un informe que CITA la firma (como el troubleshooting) no es saturación
{ echo '> build · x'; echo '| síntoma | arreglo |'
  echo '| `Error: Upstream request failed: [overloaded]` | reintenta |'
  echo 'El 2026-11-05 vimos "[prefill_cap_refused] the cell is at capacity".'; echo '===FIN==='; } > "$WORK/cita.out"
if is_capacity_error "$WORK/cita.out"; then bad "informe que cita la firma tomado por saturación"
else ok "informe que cita la firma → NO es saturación"; fi
# la firma enterrada lejos del final (el agente siguió y terminó bien) tampoco
{ printf 'Error: Upstream request failed: [overloaded] x\n'; for i in $(seq 1 30); do echo "línea $i"; done; } > "$WORK/viejo.out"
if is_capacity_error "$WORK/viejo.out"; then bad "firma lejos del final tomada por saturación"
else ok "firma lejos del final → NO es saturación"; fi

# De punta a punta con un opencode FALSO: primero saturado y luego bien; y siempre saturado.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/opencode" <<'FAKE'
#!/usr/bin/env bash
[ "$1" = db ] && exit 0
n="$(cat "$FAKE_COUNTER" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" > "$FAKE_COUNTER"
echo "> build · fake"
if [ "$n" -le "${FAKE_FAILS:-1}" ]; then
  printf '\033[91m\033[1mError: \033[0mUpstream request failed: [overloaded] the server is overloaded; retry shortly\n'
  exit 1
fi
echo "PONG"
FAKE
chmod +x "$WORK/bin/opencode"
printf 'deepseek-v4.1-flash\t%s\t%s\t30s\n' "$WORK/p.md" "$WORK/e2e.out" > "$WORK/e2e.tsv"
run_fake() { # $1 = cuántas veces falla
  rm -f "$WORK/counter" "$WORK"/e2e.out*
  PATH="$WORK/bin:$PATH" FAKE_COUNTER="$WORK/counter" FAKE_FAILS="$1" \
    CHEAP_FANOUT_CAP_RETRY_BASE=1 "$HELPER" --parallel 1 "$WORK/e2e.tsv" >/dev/null 2>&1
}
run_fake 1
if [ "$(cat "$WORK/e2e.out.status")" = 0 ] && [ "$(cat "$WORK/e2e.out.capretried" 2>/dev/null)" = 1 ] \
   && grep -q PONG "$WORK/e2e.out"; then ok "saturado 1 vez → reintentado y OK (status 0, capretried=1)"
else bad "saturado 1 vez: status=$(cat "$WORK/e2e.out.status") capretried=$(cat "$WORK/e2e.out.capretried" 2>/dev/null)"; fi
run_fake 9
if [ "$(cat "$WORK/e2e.out.status")" = 76 ] && [ "$(cat "$WORK/counter")" = 3 ]; then
  ok "siempre saturado → 3 intentos y status 76"
else bad "siempre saturado: status=$(cat "$WORK/e2e.out.status") intentos=$(cat "$WORK/counter")"; fi
run_fake 0
if [ "$(cat "$WORK/e2e.out.status")" = 0 ] && [ ! -e "$WORK/e2e.out.capretried" ] && [ "$(cat "$WORK/counter")" = 1 ]; then
  ok "sin saturación → 1 intento, sin marcador"
else bad "sin saturación: status=$(cat "$WORK/e2e.out.status") intentos=$(cat "$WORK/counter")"; fi

echo
if [ "$fail" = 0 ]; then echo "PASS: detectores, vetos, alias, rescate y saturación"; exit 0; fi
echo "FAIL: $fail comprobación(es) fallaron"; exit 1

#!/usr/bin/env bash
# sqlite-race.sh — test de regresión del choque de SQLite al arrancar opencode en paralelo.
#
# QUÉ PRUEBA
#   Varios `opencode run` simultáneos contra una base que TODAVÍA NO existe (arranque en frío)
#   se pelean por el lock: el que pierde muere con exit 1 y `database is locked`, ANTES de que
#   el logger exista (por eso --print-logs --log-level DEBUG no imprime nada del fallo).
#   El helper debe dejar 0 jobs con esa firma: precalienta la base en pre-vuelo y, si aun así
#   alguno choca, lo reintenta con backoff.
#
# POR QUÉ ARRANQUE EN FRÍO
#   Con la base ya en WAL y migrada, la concurrencia es inofensiva (medido: 16/16 OK en Linux).
#   La ventana de choque se abre cuando la base hay que CREARLA o MIGRARLA: convertir a WAL pide
#   lock exclusivo y opencode todavía no instaló `busy_timeout`. Eso pasa en la primera corrida
#   tras instalar, tras cambiar de canal, y tras un upgrade que trae migraciones nuevas.
#
# COSTO: cero. Usa un modelo -free, y el fallo que medimos ocurre antes de llamar al modelo.
#
# Uso:  ./sqlite-race.sh [N]        (N = jobs simultáneos, default 6)
set -uo pipefail

N="${1:-6}"
HELPER="$(cd "$(dirname "$0")/.." && pwd)/bin/cheap-fanout"
MODEL="${CHEAP_FANOUT_TEST_MODEL:-opencode/nemotron-3.5-lightning-free}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/cheap-fanout-race.XXXXXX")"
# Si el test FALLA, el directorio se conserva: sin las salidas crudas no hay diagnóstico
# posible, y limpiarlas fue justo lo que me dejó ciego la primera vez.
KEEP=0
cleanup() { if [ "$KEEP" = 1 ]; then echo "   (salidas conservadas en $WORK)"; else rm -rf "$WORK"; fi; }
trap cleanup EXIT

command -v opencode >/dev/null 2>&1 || { echo "SKIP: opencode no está en PATH"; exit 0; }
[ -x "$HELPER" ] || { echo "FAIL: no encuentro el helper en $HELPER"; exit 1; }

# Base FRÍA y propia del test: nunca toca la base real del usuario.
export OPENCODE_DB="$WORK/race.db"

: > "$WORK/jobs.tsv"
for i in $(seq 1 "$N"); do
  printf 'Responde exactamente: PONG%s\n' "$i" > "$WORK/p$i.txt"
  printf '%s\t%s\t%s\t4m\n' "$MODEL" "$WORK/p$i.txt" "$WORK/o$i.out" >> "$WORK/jobs.tsv"
done

echo "== $N jobs simultáneos contra base FRÍA ($OPENCODE_DB) =="
"$HELPER" --parallel "$N" --timeout 4m "$WORK/jobs.tsv" 2>"$WORK/helper.err"
helper_rc=$?
sed 's/^/   /' "$WORK/helper.err"

# OJO: no basta con buscar `database is locked`. La carrera tiene DOS cabezas y la segunda
# —colisión de migraciones— dice `Failed query: CREATE TABLE …`. Una versión anterior de este
# test solo miraba la primera y dio un PASS falso con 4 jobs muertos. Se cuenta también
# CUALQUIER job que no haya terminado en 0, para que nada se cuele por una firma no prevista.
locked=0; migr=0; empty=0; ok=0; otros=0; reintentados=0; lentos=0
for i in $(seq 1 "$N"); do
  out="$WORK/o$i.out"; st="$(cat "$out.status" 2>/dev/null || echo 1)"
  [ -s "$out.retried" ] && reintentados=$((reintentados + 1))
  # 124/137 = el modelo tardó más que el plazo. NO es la carrera: la carrera mata al instante,
  # nunca cuelga. Se cuenta aparte para no confundir lentitud del modelo -free con una regresión.
  if [ "$st" = 124 ] || [ "$st" = 137 ]; then
    lentos=$((lentos + 1))
  elif grep -qi "database is locked" "$out" 2>/dev/null; then
    locked=$((locked + 1))
  elif grep -qE '^Failed query:' "$out" 2>/dev/null; then
    migr=$((migr + 1))
  elif [ "$st" = 66 ]; then empty=$((empty + 1))
  elif [ "$st" = 0 ]; then ok=$((ok + 1))
  else
    otros=$((otros + 1))
    echo "   !! job $i terminó en status=$st con una firma no prevista:"
    sed 's/\x1b\[[0-9;]*m//g' "$out" 2>/dev/null | head -5 | sed 's/^/      /'
  fi
done

echo
echo "   jobs con 'database is locked'     : $locked   (debe ser 0)"
echo "   jobs con colisión de migraciones  : $migr   (debe ser 0)"
echo "   jobs con salida vacía             : $empty   (debe ser 0)"
echo "   jobs con otro fallo               : $otros   (debe ser 0)"
echo "   jobs OK                           : $ok/$N"
echo "   lentos (timeout del modelo, no es la carrera) : $lentos"
echo "   rescatados por reintento          : $reintentados"
echo "   exit del helper                   : $helper_rc"
echo

if [ "$((locked + migr + empty + otros))" -gt 0 ]; then
  KEEP=1
  echo "FAIL: la carrera de arranque llegó hasta el resultado sin ser absorbida."
  exit 1
fi
# si casi nada llegó a correr, el PASS no prueba nada: dilo en vez de cantar victoria
if [ "$ok" -lt $(( (N + 1) / 2 )) ]; then
  KEEP=1
  echo "NO CONCLUYENTE: solo $ok/$N jobs llegaron a terminar ($lentos por timeout del modelo)."
  echo "Ningún job murió por la carrera, pero corre de nuevo con menos jobs o más plazo."
  exit 2
fi
echo "PASS: los $N jobs sobrevivieron el arranque en frío simultáneo."
exit 0

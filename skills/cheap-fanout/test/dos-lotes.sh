#!/usr/bin/env bash
# dos-lotes.sh — dos lotes cheap-fanout INDEPENDIENTES arrancando a la vez sobre una base fría.
#
# QUÉ PRUEBA (y por qué es distinto de sqlite-race.sh)
#   sqlite-race.sh prueba N jobs DENTRO de un lote: ahí el pre-vuelo corre una sola vez y protege
#   a todos. Aquí corren DOS invocaciones separadas del helper, cada una con su propio pre-vuelo,
#   que es justo el caso que el skill prohibía ("no lances dos lotes a la vez en Windows"). Si el
#   precalentado no estuviera serializado entre procesos, los dos pre-vuelos se pelearían por
#   convertir la base a WAL y el bug volvería por la puerta de atrás.
#   Eso lo cubre el `flock` global de warm_opencode_db; donde no hay flock (Git Bash), lo cubre
#   el reintento con backoff. Este test verifica que el resultado es el mismo por cualquiera de
#   los dos caminos: 0 jobs muertos.
#
# COSTO: cero (modelo -free; el fallo que medimos ocurre antes de llamar al modelo).
#
# Uso:  ./dos-lotes.sh [JOBS_POR_LOTE]      (default 3)
set -uo pipefail

N="${1:-3}"
HELPER="$(cd "$(dirname "$0")/.." && pwd)/bin/cheap-fanout"
MODEL="${CHEAP_FANOUT_TEST_MODEL:-opencode/nemotron-3.5-lightning-free}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/cheap-fanout-2lotes.XXXXXX")"
# Si el test FALLA, el directorio se conserva: sin las salidas crudas no hay diagnóstico
# posible, y limpiarlas fue justo lo que me dejó ciego la primera vez.
KEEP=0
cleanup() { if [ "$KEEP" = 1 ]; then echo "   (salidas conservadas en $WORK)"; else rm -rf "$WORK"; fi; }
trap cleanup EXIT

command -v opencode >/dev/null 2>&1 || { echo "SKIP: opencode no está en PATH"; exit 0; }
[ -x "$HELPER" ] || { echo "FAIL: no encuentro el helper en $HELPER"; exit 1; }

# Base FRÍA y COMPARTIDA por los dos lotes — es el punto del test. Nunca toca la base real.
export OPENCODE_DB="$WORK/shared.db"
command -v flock >/dev/null 2>&1 && echo "(este sistema tiene flock: el pre-vuelo se serializa)" \
                                 || echo "(sin flock: el pre-vuelo depende del reintento)"

for lote in A B; do
  : > "$WORK/jobs-$lote.tsv"
  for i in $(seq 1 "$N"); do
    printf 'Responde exactamente: PONG-%s%s\n' "$lote" "$i" > "$WORK/p-$lote$i.txt"
    printf '%s\t%s\t%s\t4m\n' "$MODEL" "$WORK/p-$lote$i.txt" "$WORK/o-$lote$i.out" >> "$WORK/jobs-$lote.tsv"
  done
done

echo "== lote A ($N jobs) y lote B ($N jobs) arrancando a la vez sobre base FRÍA =="
"$HELPER" --parallel "$N" --timeout 4m "$WORK/jobs-A.tsv" > "$WORK/A.log" 2>&1 &
pidA=$!
"$HELPER" --parallel "$N" --timeout 4m "$WORK/jobs-B.tsv" > "$WORK/B.log" 2>&1 &
pidB=$!
wait $pidA; rcA=$?
wait $pidB; rcB=$?
echo "   lote A → exit $rcA"; sed 's/^/     /' "$WORK/A.log"
echo "   lote B → exit $rcB"; sed 's/^/     /' "$WORK/B.log"

malos=0; ok=0; reintentados=0; lentos=0
for lote in A B; do
  for i in $(seq 1 "$N"); do
    out="$WORK/o-$lote$i.out"; st="$(cat "$out.status" 2>/dev/null || echo 1)"
    [ -s "$out.retried" ] && reintentados=$((reintentados + 1))
    if [ "$st" = 0 ]; then ok=$((ok + 1))
    elif [ "$st" = 124 ] || [ "$st" = 137 ]; then
      lentos=$((lentos + 1))   # el modelo tardó; la carrera mata al instante, no cuelga
    else
      malos=$((malos + 1))
      echo "   !! job $lote$i status=$st:"
      sed 's/\x1b\[[0-9;]*m//g' "$out" 2>/dev/null | head -4 | sed 's/^/      /'
    fi
  done
done

echo
echo "   jobs OK                  : $ok/$((N * 2))"
echo "   jobs muertos             : $malos   (debe ser 0)"
echo "   lentos (timeout, no es la carrera) : $lentos"
echo "   rescatados por reintento : $reintentados"
echo
[ "$malos" -gt 0 ] && { KEEP=1; echo "FAIL: dos lotes simultáneos sobre base fría siguen matando jobs."; exit 1; }
if [ "$ok" -lt "$N" ]; then
  KEEP=1
  echo "NO CONCLUYENTE: solo $ok/$((N * 2)) terminaron ($lentos por timeout del modelo)."
  exit 2
fi
echo "PASS: los dos lotes convivieron sobre una base fría compartida."
exit 0

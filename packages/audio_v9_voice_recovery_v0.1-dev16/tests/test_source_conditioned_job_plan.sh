#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/source_conditioned_job_plan"; rm -rf "$T"; mkdir -p "$T"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_edge_calibration.rex" "$T/edges.tsv" 60 >/dev/null
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_source_conditioned_jobs.rex" "$T/edges.tsv" "$T/jobs.tsv" > "$T/run.log"
n=$(awk 'END{print NR-1}' "$T/jobs.tsv"); [ "$n" -eq 42 ] || { echo "FAIL source job count=$n" >&2; exit 1; }
fc=$(awk -F '\t' 'NR>1 && $3=="fc"{n++}END{print n+0}' "$T/jobs.tsv"); fd=$(awk -F '\t' 'NR>1 && $3=="fd"{n++}END{print n+0}' "$T/jobs.tsv")
[ "$fc" -eq 32 ] && [ "$fd" -eq 10 ] || { echo "FAIL feed counts fc=$fc fd=$fd" >&2; exit 1; }
# Every planned edge must have exactly one owner.
dup=$(awk -F '\t' 'NR>1{c[$2]++}END{for(k in c)if(c[k]!=1)n++}END{print n+0}' "$T/jobs.tsv"); [ "$dup" -eq 0 ] || { echo 'FAIL duplicate/missing owner' >&2; exit 1; }
dist=$(awk -F '\t' 'NR>1{c[$1]++}END{printf "ed209a=%d,ed209b=%d,ed209c=%d,ed209d=%d,ed209e=%d,ed209h=%d,ed209i=%d",c["ed209a"]+0,c["ed209b"]+0,c["ed209c"]+0,c["ed209d"]+0,c["ed209e"]+0,c["ed209h"]+0,c["ed209i"]+0}' "$T/jobs.tsv")
[ "$dist" = 'ed209a=6,ed209b=4,ed209c=6,ed209d=6,ed209e=7,ed209h=6,ed209i=7' ] || { echo "FAIL worker distribution=$dist" >&2; exit 1; }
# Unknown identity must fail before it can reach corpus/runtime preparation.
if "$ROOT/tools/run_source_conditioned_calibration_worker.sh" NO_SUCH_WORKER "$T/jobs.tsv" "$T/nonexistent_corpus" "$T/unknown" >"$T/unknown.log" 2>&1; then
  echo 'FAIL unknown worker accepted' >&2; exit 1
fi
grep -q 'FAIL no source-conditioned jobs assigned' "$T/unknown.log" || { echo 'FAIL unknown worker did not fail at ownership gate' >&2; exit 1; }
echo 'PASS source-conditioned job plan assertions=6' 

#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP="$ROOT/run/test/edge_calibration_plan"; rm -rf "$TMP"; mkdir -p "$TMP"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_edge_calibration.rex" "$TMP/plan.tsv" 60 > "$TMP/log"
rows=$(awk 'END{print NR-1}' "$TMP/plan.tsv")
fc=$(awk -F '\t' 'NR>1&&$1=="fc"{n++}END{print n+0}' "$TMP/plan.tsv")
fd=$(awk -F '\t' 'NR>1&&$1=="fd"{n++}END{print n+0}' "$TMP/plan.tsv")
[ "$rows" -eq 42 ] || { echo "FAIL campaign edge count=$rows" >&2; exit 1; }
[ "$fc" -eq 32 ] || { echo "FAIL FC in-campaign edges=$fc" >&2; exit 1; }
[ "$fd" -eq 10 ] || { echo "FAIL FD in-campaign edges=$fd" >&2; exit 1; }
echo 'PASS test_edge_calibration_plan assertions=3'

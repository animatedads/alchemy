#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP="$ROOT/run/test/observe_spatial_edges"
rm -rf "$TMP"; mkdir -p "$TMP"
edge=63832482018
edge_ms=$((edge*1000))
out="$TMP/spatial.tsv"
printf 'schema\taudio.v9.voice-recovery.spatial-window/1\n' > "$out"
printf 'absolute_start_ms\towned\tlocal_start_ms\trms_a\trms_b\tcrest_a\tcrest_b\tratio_db\tenv_lag_ms\tenv_score\tdirect_lag_ms\tdirect_score\tdirect_coherence\trefined_lag_ms\trefined_score\trefined_coherence\n' >> "$out"
# Two full 8 s windows before the edge and two after. Lag changes by exactly -3 samples.
for off in -20000 -12000; do
  t=$((edge_ms+off)); printf '%s\t1\t0\t.01\t.01\t2\t2\t0\t10\t1\t1.5\t1\t.9\t1.5\t1\t.9\n' "$t" >> "$out"
done
for off in 0 8000; do
  t=$((edge_ms+off)); printf '%s\t1\t0\t.01\t.01\t2\t2\t0\t9.625\t1\t1.125\t1\t.9\t1.125\t1\t.9\n' "$t" >> "$out"
done
obs="$TMP/obs.tsv"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/observe_spatial_edges.rex" "$out" fc "$obs" 60000 8000 > "$TMP/log"
right=20231009_210018_tp00003_original.ogg
rows=$(awk -F '\t' -v r="$right" '$4==r {n++} END{print n+0}' "$obs")
[ "$rows" -eq 3 ] || { echo "FAIL expected 3 spatial estimators got=$rows" >&2; exit 1; }
bad=$(awk -F '\t' -v r="$right" '$4==r && $7!=-3 {n++} END{print n+0}' "$obs")
[ "$bad" -eq 0 ] || { echo "FAIL spatial edge step not -3 rows=$bad" >&2; exit 1; }
echo 'PASS test_observe_spatial_edges assertions=2'

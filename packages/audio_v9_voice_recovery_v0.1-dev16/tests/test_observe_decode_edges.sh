#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP="$ROOT/run/test/observe_decode_edges"
rm -rf "$TMP"; mkdir -p "$TMP"
left=20231009_202339_tp00002_original.ogg
right=20231009_210018_tp00003_original.ogg
edge=63832482018
report="$TMP/fc.f32.decode.tsv"
printf 'feed\tfile\tslice_start\tslice_end\toffset_seconds\tduration_seconds\taction\toriginal_bytes\tfinal_bytes\texpected_samples\n' > "$report"
# Three missing samples at the exact nominal file edge.
printf 'fc\t%s\t%s\t%s\t2169\t30\tPAD_ZERO\t959988\t960000\t240000\n' "$left" "$((edge-30))" "$edge" >> "$report"
printf '%s\n' "$report" > "$TMP/reports.txt"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/observe_decode_edges.rex" "$TMP/reports.txt" "$TMP/obs.tsv" >/dev/null
row=$(awk -F '\t' -v r="$right" '$4==r {print $0}' "$TMP/obs.tsv")
[ -n "$row" ] || { echo 'FAIL decode-edge observation missing' >&2; exit 1; }
step=$(printf '%s\n' "$row" | awk -F '\t' '{print $7}')
est=$(printf '%s\n' "$row" | awk -F '\t' '{print $6}')
[ "$step" = -3 ] || { echo "FAIL decode shortfall expected=-3 got=$step" >&2; exit 1; }
[ "$est" = DECODE_SHORTFALL ] || { echo "FAIL estimator provenance got=$est" >&2; exit 1; }
echo 'PASS test_observe_decode_edges assertions=3'

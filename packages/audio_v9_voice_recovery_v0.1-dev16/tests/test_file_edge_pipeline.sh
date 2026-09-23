#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP="$ROOT/run/test/file_edge_pipeline"
rm -rf "$TMP"; mkdir -p "$TMP"
left=20231009_202339_tp00002_original.ogg
right=20231009_210018_tp00003_original.ogg
# 20:23:39 -> 21:00:18 = 2199 s. Simulate a three-sample-short canonical decode.
nominal=$((2199*8000))
printf 'feed\tleft_file\tright_file\tsample_rate\tdecoded_samples\nfc\t%s\t%s\t8000\t%s\n' "$left" "$right" "$((nominal-3))" > "$TMP/raw.tsv"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/geometry_observations_from_counts.rex" "$TMP/raw.tsv" "$TMP/geometry.tsv" >/dev/null
header='id\tfeed\tleft_file\tright_file\tedge_serial\testimator\tstep_samples\tscore\tsource_family\ttdoa_before_samples\ttdoa_after_samples'
printf "$header\n" > "$TMP/spatial.tsv"
# Edge serial for 2023-10-09 21:00:18, as defined by AudioV9VoiceClock.
edge=$((738801*86400 + 21*3600 + 18))
printf 'S1\tfc\t%s\t%s\t%s\tSPATIAL_REFINED\t-3\t1\tUNLABELLED\t0\t0\n' "$left" "$right" "$edge" >> "$TMP/spatial.tsv"
printf 'S2\tfc\t%s\t%s\t%s\tSPATIAL_DIRECT\t-4\t0.8\tUNLABELLED\t0\t0\n' "$left" "$right" "$edge" >> "$TMP/spatial.tsv"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/solve_file_edges.rex" "$TMP/FILE_EDGE_MAP.tsv" "$TMP/geometry.tsv" "$TMP/spatial.tsv" > "$TMP/solve.log"
row=$(awk -F '\t' -v r="$right" '$1=="fc" && $3==r {print $0}' "$TMP/FILE_EDGE_MAP.tsv")
[ -n "$row" ] || { echo 'FAIL solved target edge missing' >&2; exit 1; }
step=$(printf '%s\n' "$row" | awk -F '\t' '{print $5}')
status=$(printf '%s\n' "$row" | awk -F '\t' '{print $9}')
[ "$step" = -3 ] || { echo "FAIL solved step expected=-3 got=$step" >&2; exit 1; }
[ "$status" = MEASURED ] || { echo "FAIL solved status expected=MEASURED got=$status" >&2; exit 1; }
# Planner must make the right file start three samples early and keep total geometry exact.
start=$((edge-30)); end=$((edge+30))
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_source_interval.rex" fc "$start" "$end" "$TMP/FILE_EDGE_MAP.tsv" > "$TMP/plan.tsv"
left_count=$(awk -F '\t' -v n="$left" '$2==n {print $8}' "$TMP/plan.tsv")
right_count=$(awk -F '\t' -v n="$right" '$2==n {print $8}' "$TMP/plan.tsv")
[ "$left_count" = 239997 ] || { echo "FAIL left corrected count expected=239997 got=$left_count" >&2; exit 1; }
[ "$right_count" = 240003 ] || { echo "FAIL right corrected count expected=240003 got=$right_count" >&2; exit 1; }
[ $((left_count+right_count)) -eq 480000 ] || { echo 'FAIL corrected plan lost samples' >&2; exit 1; }
echo 'PASS test_file_edge_pipeline assertions=6'

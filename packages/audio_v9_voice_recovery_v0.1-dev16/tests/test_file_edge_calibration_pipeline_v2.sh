#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMP="$ROOT/run/test/file_edge_calibration_v2"
rm -rf "$TMP"; mkdir -p "$TMP"
left=20231009_202339_tp00002_original.ogg
right=20231009_210018_tp00003_original.ogg
edge=63832482018
edge_ms=$((edge*1000))

# 1) Mine media extent residual from dev3-style normalization evidence.
report="$TMP/fc.f32.decode.tsv"
printf 'feed\tfile\tnominal_source_start\teffective_source_start_sample\tslice_start_sample\tslice_end_sample\toffset_samples\texpected_samples\tcorrection_samples\tedge_status\taction\toriginal_bytes\tfinal_bytes\n' > "$report"
printf 'fc\t%s\t0\t0\t%s\t%s\t0\t240000\t0\tPREDICTED\tPAD_ZERO\t959988\t960000\n' "$left" "$(((edge-30)*8000))" "$((edge*8000))" >> "$report"
printf '%s\n' "$report" > "$TMP/reports.txt"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/observe_decode_edges_v2.rex" "$TMP/reports.txt" "$TMP/media.tsv" > "$TMP/media.log"
media=$(awk -F '\t' -v r="$right" '$4==r {print $10}' "$TMP/media.tsv")
kind=$(awk -F '\t' -v r="$right" '$4==r {print $6}' "$TMP/media.tsv")
[ "$media" = -3 ] || { echo "FAIL media extent expected=-3 got=$media" >&2; exit 1; }
[ "$kind" = MEDIA_EXTENT ] || { echo "FAIL media kind=$kind" >&2; exit 1; }

# 2) Legacy-style aggregate spatial lag jump remains diagnostic because TDOA is unknown.
sp="$TMP/spatial.tsv"
printf 'schema\taudio.v9.voice-recovery.spatial-window/1\n' > "$sp"
printf 'absolute_start_ms\towned\tlocal_start_ms\trms_a\trms_b\tcrest_a\tcrest_b\tratio_db\tenv_lag_ms\tenv_score\tdirect_lag_ms\tdirect_score\tdirect_coherence\trefined_lag_ms\trefined_score\trefined_coherence\n' >> "$sp"
for off in -30000 -20000 -10000; do t=$((edge_ms+off)); printf '%s\t1\t0\t.01\t.01\t2\t2\t0\t12\t1\t3\t1\t.9\t3\t1\t.9\n' "$t" >> "$sp"; done
for off in 0 10000 20000; do t=$((edge_ms+off)); printf '%s\t1\t0\t.01\t.01\t2\t2\t0\t11.625\t1\t2.625\t1\t.9\t2.625\t1\t.9\n' "$t" >> "$sp"; done
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/observe_spatial_edges_v2.rex" "$sp" fc "$TMP/raw_spatial.tsv" 60000 8000 > "$TMP/spatial.log"
unknown=$(awk -F '\t' -v r="$right" '$4==r && $14==0 {n++} END{print n+0}' "$TMP/raw_spatial.tsv")
[ "$unknown" -eq 3 ] || { echo "FAIL expected 3 TDOA-unknown spatial rows got=$unknown" >&2; exit 1; }
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/solve_file_edges_v2.rex" "$TMP/pre_map.tsv" "$TMP/media.tsv" "$TMP/raw_spatial.tsv" > "$TMP/pre_solve.log"
pre_status=$(awk -F '\t' -v r="$right" '$3==r {print $11}' "$TMP/pre_map.tsv")
pre_step=$(awk -F '\t' -v r="$right" '$3==r {print $7}' "$TMP/pre_map.tsv")
[ "$pre_status" = EXTENT_ONLY ] || { echo "FAIL unsafe aggregate spatial must leave EXTENT_ONLY got=$pre_status" >&2; exit 1; }
[ "$pre_step" = 0 ] || { echo "FAIL unsafe aggregate spatial moved clock step=$pre_step" >&2; exit 1; }

# 3) Two independent continuous source/path trajectories absorb ordinary motion
#    and independently recover the same -3 sample seam step.
pts="$TMP/source_paths.tsv"
printf 'id\tfeed\tleft_file\tright_file\tedge_serial\tsource_family\tpath_id\ttime_ms\tside\tlag_samples\tscore\n' > "$pts"
# Family A: before intercept=100, slope +1 sample/10s; after intercept=97.
printf 'A\tfc\t%s\t%s\t%s\tVOICE_A\tDIRECT_A\t%s\tBEFORE\t97\t1\n' "$left" "$right" "$edge" "$((edge_ms-30000))" >> "$pts"
printf 'A\tfc\t%s\t%s\t%s\tVOICE_A\tDIRECT_A\t%s\tBEFORE\t98\t1\n' "$left" "$right" "$edge" "$((edge_ms-20000))" >> "$pts"
printf 'A\tfc\t%s\t%s\t%s\tVOICE_A\tDIRECT_A\t%s\tBEFORE\t99\t1\n' "$left" "$right" "$edge" "$((edge_ms-10000))" >> "$pts"
printf 'A\tfc\t%s\t%s\t%s\tVOICE_A\tDIRECT_A\t%s\tAFTER\t98\t1\n' "$left" "$right" "$edge" "$((edge_ms+10000))" >> "$pts"
printf 'A\tfc\t%s\t%s\t%s\tVOICE_A\tDIRECT_A\t%s\tAFTER\t99\t1\n' "$left" "$right" "$edge" "$((edge_ms+20000))" >> "$pts"
printf 'A\tfc\t%s\t%s\t%s\tVOICE_A\tDIRECT_A\t%s\tAFTER\t100\t1\n' "$left" "$right" "$edge" "$((edge_ms+30000))" >> "$pts"
# Family B: before intercept=200, slope -2 samples/10s; after intercept=197.
printf 'B\tfc\t%s\t%s\t%s\tVOICE_B\tDIRECT_B\t%s\tBEFORE\t206\t1\n' "$left" "$right" "$edge" "$((edge_ms-30000))" >> "$pts"
printf 'B\tfc\t%s\t%s\t%s\tVOICE_B\tDIRECT_B\t%s\tBEFORE\t204\t1\n' "$left" "$right" "$edge" "$((edge_ms-20000))" >> "$pts"
printf 'B\tfc\t%s\t%s\t%s\tVOICE_B\tDIRECT_B\t%s\tBEFORE\t202\t1\n' "$left" "$right" "$edge" "$((edge_ms-10000))" >> "$pts"
printf 'B\tfc\t%s\t%s\t%s\tVOICE_B\tDIRECT_B\t%s\tAFTER\t195\t1\n' "$left" "$right" "$edge" "$((edge_ms+10000))" >> "$pts"
printf 'B\tfc\t%s\t%s\t%s\tVOICE_B\tDIRECT_B\t%s\tAFTER\t193\t1\n' "$left" "$right" "$edge" "$((edge_ms+20000))" >> "$pts"
printf 'B\tfc\t%s\t%s\t%s\tVOICE_B\tDIRECT_B\t%s\tAFTER\t191\t1\n' "$left" "$right" "$edge" "$((edge_ms+30000))" >> "$pts"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/observe_source_conditioned_edges.rex" "$pts" "$TMP/path_evidence.tsv" 1 > "$TMP/path.log"
paths=$(awk 'END{print NR-1}' "$TMP/path_evidence.tsv")
[ "$paths" -eq 2 ] || { echo "FAIL expected two independent path fits got=$paths" >&2; exit 1; }
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/solve_file_edges_v2.rex" "$TMP/final_map.tsv" "$TMP/media.tsv" "$TMP/raw_spatial.tsv" "$TMP/path_evidence.tsv" > "$TMP/final_solve.log"
status=$(awk -F '\t' -v r="$right" '$3==r {print $11}' "$TMP/final_map.tsv")
step=$(awk -F '\t' -v r="$right" '$3==r {print $7}' "$TMP/final_map.tsv")
support=$(awk -F '\t' -v r="$right" '$3==r {print $13}' "$TMP/final_map.tsv")
gap_status=$(awk -F '\t' -v r="$right" '$3==r {print $10}' "$TMP/final_map.tsv")
[ "$status" = CLOCK_MEASURED ] || { echo "FAIL expected CLOCK_MEASURED got=$status" >&2; exit 1; }
[ "$step" = -3 ] || { echo "FAIL corrected clock expected=-3 got=$step" >&2; exit 1; }
[ "$support" -eq 2 ] || { echo "FAIL independent support expected=2 got=$support" >&2; exit 1; }
[ "$gap_status" = CONTIGUOUS ] || { echo "FAIL expected extent/clock to imply contiguous seam got=$gap_status" >&2; exit 1; }

# 4) Applying the v2 map shifts file ownership but preserves exact requested geometry.
start=$((edge-30)); end=$((edge+30))
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/plan_source_interval.rex" fc "$start" "$end" "$TMP/final_map.tsv" > "$TMP/plan.tsv"
left_count=$(awk -F '\t' -v n="$left" '$2==n {print $8}' "$TMP/plan.tsv")
right_count=$(awk -F '\t' -v n="$right" '$2==n {print $8}' "$TMP/plan.tsv")
[ "$left_count" = 239997 ] || { echo "FAIL left corrected count=$left_count" >&2; exit 1; }
[ "$right_count" = 240003 ] || { echo "FAIL right corrected count=$right_count" >&2; exit 1; }
[ $((left_count+right_count)) -eq 480000 ] || { echo 'FAIL corrected v2 plan lost samples' >&2; exit 1; }

echo 'PASS test_file_edge_calibration_pipeline_v2 assertions=15'

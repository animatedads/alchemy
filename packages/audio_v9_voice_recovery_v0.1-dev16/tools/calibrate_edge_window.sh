#!/bin/sh
set -eu
if [ "$#" -lt 7 ] || [ "$#" -gt 10 ]; then
  echo "usage: $0 FEED LEFT_FILE RIGHT_FILE EDGE_SERIAL WINDOW_START_SERIAL WINDOW_END_SERIAL OUT_DIR [CORPUS_BASE] [MIN_BOXES] [MAX_GROUPS]" >&2
  exit 2
fi
feed=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]'); left=$2; right=$3; edge=$4; ws=$5; we=$6; OUT=$7
BASE=${8:-"$HOME/fcpaphos_originals/20231009_20231010"}; MIN_BOXES=${9:-3}; MAX_GROUPS=${10:-8}
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
case "$feed" in fc|fd) ;; *) echo 'FAIL FEED must be fc/fd' >&2; exit 2;; esac
[ "$we" -gt "$ws" ] || { echo 'FAIL invalid calibration window' >&2; exit 2; }
HALF=${AV9_CALIBRATION_HALF_WINDOW_SECONDS:-8}
TIMEOUT_SEC=${AV9_CALIBRATION_ANALYSIS_TIMEOUT_SECONDS:-300}
case "$HALF" in ''|*[!0-9]*) echo 'FAIL AV9_CALIBRATION_HALF_WINDOW_SECONDS must be integer' >&2; exit 2;; esac
case "$TIMEOUT_SEC" in ''|*[!0-9]*) echo 'FAIL AV9_CALIBRATION_ANALYSIS_TIMEOUT_SECONDS must be integer' >&2; exit 2;; esac
[ "$HALF" -ge 4 ] || { echo 'FAIL calibration half-window must be >=4 seconds' >&2; exit 2; }
[ "$TIMEOUT_SEC" -ge 30 ] || { echo 'FAIL calibration analysis timeout must be >=30 seconds' >&2; exit 2; }
cal_ws=$((edge-HALF)); [ "$cal_ws" -lt "$ws" ] && cal_ws=$ws
cal_we=$((edge+HALF)); [ "$cal_we" -gt "$we" ] && cal_we=$we
[ "$edge" -gt "$cal_ws" ] && [ "$cal_we" -gt "$edge" ] || { echo 'FAIL seam-local calibration window lacks both sides' >&2; exit 2; }
mkdir -p "$OUT"
# A partial dev7/dev8 edge may be resumed safely: completed edges are skipped by
# the worker; unfinished edge-derived products are rebuilt from immutable source.
rm -rf "$OUT/source_masks" "$OUT/tmp"
rm -f "$OUT/source_path_points.tsv" "$OUT/source_path_evidence.tsv" "$OUT/EVIDENCE.sha256" "$OUT/FAILED.tsv"
printf 'stage\ttime_utc\tdetail\nSTART\t%s\tedge=%s feed=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$edge" "$feed" > "$OUT/PROGRESS.tsv"
printf 'requested_start_serial\trequested_end_serial\teffective_start_serial\teffective_end_serial\tedge_serial\thalf_window_seconds\n%s\t%s\t%s\t%s\t%s\t%s\n' "$ws" "$we" "$cal_ws" "$cal_we" "$edge" "$HALF" > "$OUT/CALIBRATION_WINDOW.tsv"
progress(){ printf '%s\t%s\t%s\n' "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" >> "$OUT/PROGRESS.tsv"; }
fail_stage(){ rc=$1; reason=$2; printf 'status\tFAILED\nreason\t%s\nexit_code\t%s\n' "$reason" "$rc" > "$OUT/FAILED.tsv"; progress FAILED "$reason rc=$rc"; exit "$rc"; }
progress PREPARE_RUNTIME "bounded_window=${cal_ws}..${cal_we}"
"$ROOT/tools/prepare_runtime.sh" >/dev/null || fail_stage $? PREPARE_RUNTIME
fc="$OUT/fc.f32"; fd="$OUT/fd.f32"; acoustic="$OUT/acoustic"
progress DECODE_FC "serial=${cal_ws}..${cal_we}"
"$ROOT/tools/decode_serial_interval.sh" fc "$cal_ws" "$cal_we" "$fc" "$BASE" >/dev/null || fail_stage $? DECODE_FC
progress DECODE_FD "serial=${cal_ws}..${cal_we}"
"$ROOT/tools/decode_serial_interval.sh" fd "$cal_ws" "$cal_we" "$fd" "$BASE" >/dev/null || fail_stage $? DECODE_FD
progress ACOUSTIC "timeout_seconds=$TIMEOUT_SEC"
set +e
timeout -k 30 "$TIMEOUT_SEC" "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/analyze_acoustic_calibration.rex" "$fc" "$fd" "$cal_ws" "$acoustic" "EDGE:$feed:$right" > "$OUT/acoustic.log" 2>&1
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  if [ "$rc" -eq 124 ]; then fail_stage "$rc" CALIBRATION_ACOUSTIC_TIMEOUT; fi
  if grep -q 'CALIBRATION_COMPLEXITY_EXCEEDED' "$OUT/acoustic.log" 2>/dev/null; then fail_stage "$rc" CALIBRATION_COMPLEXITY_EXCEEDED; fi
  fail_stage "$rc" CALIBRATION_ACOUSTIC_FAILED
fi
progress MASKS "min_boxes=$MIN_BOXES max_groups=$MAX_GROUPS"
masks="$OUT/source_masks"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/build_source_calibration_masks.rex" "$acoustic" "$edge" "$cal_ws" "$masks" "$MIN_BOXES" "$MAX_GROUPS" > "$OUT/masks.log" 2>&1 || fail_stage $? MASK_BUILD_FAILED
progress PATHS "source-isolated"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/extract_source_conditioned_paths.rex" "$fc" "$fd" "$masks/groups.tsv" "$feed" "$left" "$right" "$edge" "$cal_ws" "$OUT/source_path_points.tsv" "$OUT/tmp" > "$OUT/paths.log" 2>&1 || fail_stage $? PATH_EXTRACTION_FAILED
progress EVIDENCE "continuous-path fit"
"$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/observe_source_conditioned_edges.rex" "$OUT/source_path_points.tsv" "$OUT/source_path_evidence.tsv" 8 > "$OUT/evidence.log" 2>&1 || fail_stage $? EVIDENCE_FIT_FAILED
sha256sum "$OUT/source_path_points.tsv" "$OUT/source_path_evidence.tsv" "$masks/groups.tsv" > "$OUT/EVIDENCE.sha256"
if [ "${AV9_KEEP_CALIBRATION_F32:-0}" != 1 ]; then rm -f "$fc" "$fd"; fi
rm -rf "$OUT/tmp"
progress COMPLETE "points=$(awk 'END{print NR-1}' "$OUT/source_path_points.tsv") evidence=$(awk 'END{print NR-1}' "$OUT/source_path_evidence.tsv")"
echo "PASS edge calibration feed=$feed right=$right edge=$edge window=${cal_ws}..${cal_we} points=$(awk 'END{print NR-1}' "$OUT/source_path_points.tsv") evidence=$(awk 'END{print NR-1}' "$OUT/source_path_evidence.tsv") out=$OUT"

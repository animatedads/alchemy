#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
f="$ROOT/tools/calibrate_edge_window.sh"
grep -q 'AV9_CALIBRATION_HALF_WINDOW_SECONDS:-8' "$f"
grep -q 'AV9_CALIBRATION_ANALYSIS_TIMEOUT_SECONDS:-300' "$f"
grep -q 'analyze_acoustic_calibration.rex' "$f"
! grep -q 'analyze_acoustic_chunk.rex' "$f"
grep -q 'CALIBRATION_COMPLEXITY_EXCEEDED' "$f"
grep -q 'PROGRESS.tsv' "$f"
grep -q 'CALIBRATION_WINDOW.tsv' "$f"
grep -q 'timeout -k 30' "$f"
grep -q 'CALIBRATION_ACOUSTIC_TIMEOUT' "$f"
grep -q 'source_path_evidence.tsv' "$f"
echo 'PASS calibration runtime bounds assertions=10'

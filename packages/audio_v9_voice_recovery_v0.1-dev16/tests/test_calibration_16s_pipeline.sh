#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
T="$ROOT/run/test/calibration_16s"
rm -rf "$T"; mkdir -p "$T"
"$ROOT/native/make_spatial_fixture" "$T/fc.f32" "$T/fd.f32" 8000 16 960
start=$(date +%s)
timeout -k 10 120 "$ROOT/tools/run_rexx_pinned.sh" "$ROOT/tools/analyze_acoustic_calibration.rex" "$T/fc.f32" "$T/fd.f32" 63832482000 "$T/acoustic" DEV8-16S > "$T/run.log" 2>&1
elapsed=$(( $(date +%s)-start ))
grep -q '^PASS calibration acoustic ' "$T/run.log"
for x in characters tracks track_members families appearances speakers; do [ -s "$T/acoustic.$x.tsv" ] || { echo "FAIL missing calibration TSV $x" >&2; exit 1; }; done
[ ! -e "$T/acoustic.tf_mask.tsv" ] || { echo 'FAIL calibration analyzer must not build TF mask' >&2; exit 1; }
[ ! -e "$T/acoustic.graph_edges.tsv" ] || { echo 'FAIL calibration analyzer must not build relation graph' >&2; exit 1; }
[ "$elapsed" -lt 120 ] || { echo "FAIL 16s calibration exceeded bound elapsed=$elapsed" >&2; exit 1; }
echo "PASS calibration 16s pipeline assertions=10 elapsed_seconds=$elapsed"

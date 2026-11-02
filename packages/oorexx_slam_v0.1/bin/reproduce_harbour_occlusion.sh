#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
outdir=${1:-"$root/occlusion-outputs"}
mkdir -p "$outdir"
export REXX_PATH="$root/src${REXX_PATH:+:$REXX_PATH}"
rx=${REXX_BIN:-rexx}
"$rx" "$root/tests/test_occlusion.rex"
for key in NORTH_PTZ CAFE_SYDNEY OPERA_WEST_WALK; do
  "$rx" "$root/bin/render_occluded.rex" "$key" "$outdir/$key.svg"
done
"$rx" "$root/bin/audit_sightlines.rex" > "$outdir/sightline_audit.txt"
echo "Native SVG and sightline evidence at $outdir"
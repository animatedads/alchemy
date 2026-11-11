#!/bin/sh
# Moonsault temporal star-candidate proposal; independent of SLAM450.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root/tests"
runner=${REXX:-rexx}
"$runner" test_still_tracks_synthetic.rex
if [ "${MEDIA_SCREENSHOT_ROOT:-}" != "" ]; then
  output=${MOONSAULT_RESULTS_DIR:-"$root/tests/out"}
  mkdir -p "$output"
  "$runner" test_sydney_20261109_stills.rex "$MEDIA_SCREENSHOT_ROOT" "$output"
else
  printf '%s\n' 'Real Sydney screenshot check SKIPPED (set MEDIA_SCREENSHOT_ROOT)'
fi

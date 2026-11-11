#!/bin/sh
# Run from the existing Alchemy monorepo, after provisioning native media dev5.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$root/tests"
runner=${REXX:-rexx}
"$runner" test_precession_epoch.rex
"$runner" test_plate_synthetic.rex
"$runner" test_plate_holdouts.rex ../fixtures/yale_sydney_southwest_bright.csv 250 25
if [ "${SYDNEY_STILLS_DIR:-}" != "" ]; then
  mkdir -p "$root/tests/out"
  "$runner" test_sydney_20261109_stills.rex "$SYDNEY_STILLS_DIR" "$root/tests/out"
  "$runner" test_fourframe_tracks.rex "$SYDNEY_STILLS_DIR"
else
  printf '%s\n' 'Real broadcaster PNGs SKIPPED: provide SYDNEY_STILLS_DIR (local only)'
fi
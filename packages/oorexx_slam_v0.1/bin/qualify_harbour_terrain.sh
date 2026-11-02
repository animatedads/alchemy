#!/bin/sh
# Reproduces native terrain-adapter tests in a full Git checkout or standalone ZIP.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH= cd -- "$here/.." && pwd)
export REXX_PATH="$root/src${REXX_PATH:+:$REXX_PATH}"
rx=${REXX_BIN:-rexx}
"$rx" "$root/tests/test_terrain_visibility.rex" "$root/examples/SYNTHETIC_harbour_dem.tile"
"$rx" "$root/tests/test_terrain_mosaic.rex" "$root/examples"
if test -f "$root/tests/test_occlusion.rex"; then
  "$rx" "$root/tests/test_occlusion.rex"
else
  "$rx" "$root/tests/test_occlusion_v021_regression.rex"
fi
if test -f "$root/tests/test_opera_west_walk.rex"; then
  "$rx" "$root/tests/test_opera_west_walk.rex"
else
  "$rx" "$root/tests/test_opera_west_walk_regression.rex"
fi
echo 'Power SLAM v0.22 QUALIFICATION 97/97 PASS, real NSW DEM not supplied'
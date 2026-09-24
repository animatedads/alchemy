#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
MATHS_ROOT=${REXXTRONICS_MATHS_ROOT:-"$HERE/deps/oorexx_maths_v0.8"}
PHYSICS_ROOT=${REXXTRONICS_PHYSICS_ROOT:-"$HERE/deps/oorexx_physics_world_v0.1-dev10.1"}
UNITS_ROOT=${REXXTRONICS_UNITS_ROOT:-"$HERE/deps/oorexx_units_v0.1-dev4"}

export REXX_PATH="$PHYSICS_ROOT/rexx:$UNITS_ROOT/rexx:$MATHS_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"

# The exact Maths surfaces Physics consumes, including the v0.8 3-D family.
(cd "$MATHS_ROOT/tests" && \
  rexx test_core.rex && \
  rexx test_mixed_precision.rex && \
  rexx test_math3d.rex)

# Focused Physics optical qualification.  Mechanics/acoustics have their own
# Physics package suite and are not re-run merely to qualify this adapter.
cd "$PHYSICS_ROOT/tests"
for t in \
  smoke.rex \
  test_world.rex \
  test_refraction.rex \
  test_fresnel_medium.rex \
  test_parabolic_mirror.rex \
  test_occlusion.rex \
  test_photometry.rex \
  test_quantity_photometry.rex \
  test_physical_mount.rex; do
  echo "== Physics $t =="
  rexx "$t"
done

"$HERE/run_physics_tests.sh"

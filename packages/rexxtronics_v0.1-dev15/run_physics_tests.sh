#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

UNITS_ROOT=${REXXTRONICS_UNITS_ROOT:-"$HERE/deps/oorexx_units_v0.1-dev4"}
PHYSICS_ROOT=${REXXTRONICS_PHYSICS_ROOT:-"$HERE/deps/oorexx_physics_world_v0.1-dev10.1"}
MATHS_ROOT=${REXXTRONICS_MATHS_ROOT:-"$HERE/deps/oorexx_maths_v0.8"}
MATHS_REXX=${MATHS_REXX:-"$MATHS_ROOT/rexx"}

for required in \
  "$UNITS_ROOT/rexx/Units.cls" \
  "$PHYSICS_ROOT/rexx/PhysicsWorld.cls" \
  "$MATHS_REXX/MathsBootstrap.cls"; do
  if [ ! -f "$required" ]; then
    echo "Rexx-tronics: required peer source not found: $required" >&2
    exit 2
  fi
done

export REXX_PATH="$HERE/src:$PHYSICS_ROOT/rexx:$UNITS_ROOT/rexx:$MATHS_REXX${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
rexx test_physics_optical_roundtrip.rex
rexx test_physics_scheduled_sampling.rex
rexx test_physics_microphone_136db_scope.rex
rexx test_physics_block_impact_microphone.rex
rexx test_physics_block_yell_scope.rex
rexx test_physics_linear_backemf.rex
rexx test_physics_motor_backemf.rex
rexx test_physics_motor_rl_transient.rex
rexx test_physics_resistor_thermal.rex
rexx test_physics_speaker_microphone_scope.rex
rexx test_physics_fracture_conductor.rex
rexx test_physics_contact_fracture_conductor.rex
rexx test_physics_free_surface_level_scope.rex

#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PW=${PHYSICS_WORLD_ROOT:?set PHYSICS_WORLD_ROOT to Physics World v0.1-dev12}
MATHS=${OOREXX_MATHS_ROOT:-"$PW/deps/oorexx_maths_v0.8"}
U="$HERE/deps/oorexx_units_v0.1-dev4/rexx/Units.cls"
export REXX_PATH="$HERE/src:$HERE/deps/oorexx_units_v0.1-dev4/rexx:$PW/rexx:$MATHS/rexx${REXX_PATH:+:$REXX_PATH}"
T="$HERE/tests/test_projection.generated.rex"
sed \
 -e "s|@UNITS@|$U|" \
 -e "s|@MATHS@|$MATHS/rexx/Maths.cls|" \
 -e "s|@PHYSICSWORLD@|$PW/rexx/PhysicsWorld.cls|" \
 -e "s|@FLUIDS@|$PW/rexx/Fluids.cls|" \
 -e "s|@THERMAL@|$PW/rexx/Thermal.cls|" \
 -e "s|@DEFORMABLE@|$PW/rexx/Deformable.cls|" \
 -e "s|@MATERIALS@|$HERE/src/MaterialsCatalog.cls|" \
 -e "s|@ADAPTER@|$HERE/src/PhysicsMaterialProjection.cls|" \
 "$HERE/tests/test_projection.template" > "$T"
rexx "$T"
rm -f "$T"

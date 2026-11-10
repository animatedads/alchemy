# Source this file: sets REXX_PATH/LD_LIBRARY_PATH/PYTHONPATH for SLAM 450 v0.88.
# SLAM consumes the Alchemy packages by path; it vendors neither Physics nor Maths.
#   ALCHEMY_ROOT          checkout of github.com/animatedads/alchemy (default ../..)
#   PHYSICS_WORLD_ROOT    default: packages/oorexx_physics_world_v0.1-dev51 if present,
#                         else packages/oorexx_physics_world
#   MATHS_ROOT            default: packages/oorexx_maths_v0.20 if present, else packages/oorexx_maths
#   FOREIGN_RUNTIME_ROOT  default: packages/oorexx_foreign_runtime_v0.22.6
_slam450_pkg="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ALCHEMY_ROOT="${ALCHEMY_ROOT:-$_slam450_pkg/../..}"
_p="$ALCHEMY_ROOT/packages"
if [ -z "$PHYSICS_WORLD_ROOT" ]; then
  PHYSICS_WORLD_ROOT="$_p/oorexx_physics_world_v0.1-dev51"; [ -d "$PHYSICS_WORLD_ROOT" ] || PHYSICS_WORLD_ROOT="$_p/oorexx_physics_world"
fi
if [ -z "$MATHS_ROOT" ]; then
  MATHS_ROOT="$_p/oorexx_maths_v0.20"; [ -d "$MATHS_ROOT" ] || MATHS_ROOT="$_p/oorexx_maths"
fi
FOREIGN_RUNTIME_ROOT="${FOREIGN_RUNTIME_ROOT:-$_p/oorexx_foreign_runtime_v0.22.6}"
export REXX_PATH="$_slam450_pkg/src:$PHYSICS_WORLD_ROOT/rexx:$MATHS_ROOT/rexx:$FOREIGN_RUNTIME_ROOT/rexx"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build:/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="$MATHS_ROOT/python${PYTHONPATH:+:$PYTHONPATH}"
for _f in "$PHYSICS_WORLD_ROOT/rexx/FixedWingFlight.cls" "$MATHS_ROOT/rexx/MathFastLanes.cls"; do
  [ -f "$_f" ] || echo "slam450_env: missing $_f (needs Physics World dev51 + Maths v0.20)" >&2
done

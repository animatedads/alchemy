# Source this file: sets REXX_PATH/LD_LIBRARY_PATH/PYTHONPATH for SLAM 450 v0.92.
# SLAM consumes the Alchemy packages by path; it vendors none of them.
#   ALCHEMY_ROOT  checkout of github.com/animatedads/alchemy (default ../..)
# Optional overrides: PHYSICS_WORLD_ROOT MATHS_ROOT FOREIGN_RUNTIME_ROOT
#   COMPRESS_ROOT ANTHROPIC_PROVIDER_ROOT (+ its deps, only for LLM pilots)
_slam450_pkg="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ALCHEMY_ROOT="${ALCHEMY_ROOT:-$_slam450_pkg/../..}"
_p="$ALCHEMY_ROOT/packages"
_pick() { for c in "$@"; do [ -d "$_p/$c" ] && { echo "$_p/$c"; return; }; done; echo "$_p/$1"; }
PHYSICS_WORLD_ROOT="${PHYSICS_WORLD_ROOT:-$(_pick oorexx_physics_world_v0.1-dev51 oorexx_physics_world)}"
MATHS_ROOT="${MATHS_ROOT:-$(_pick oorexx_maths_v0.21 oorexx_maths_v0.20 oorexx_maths)}"
FOREIGN_RUNTIME_ROOT="${FOREIGN_RUNTIME_ROOT:-$_p/oorexx_foreign_runtime_v0.22.6}"
COMPRESS_ROOT="${COMPRESS_ROOT:-$_p/oorexx_compress_v0.1-dev5}"
ANTHROPIC_PROVIDER_ROOT="${ANTHROPIC_PROVIDER_ROOT:-$_p/oorexx_ai_provider_anthropic_v0.4}"
# v0.91 real ground: Power SLAM v0.40 classes + the harbour words (PR #126).
POWER_SLAM_ROOT="${POWER_SLAM_ROOT:-$_p/oorexx_slam_v0.1}"
export SLAM450_HARBOUR_WORDS="${SLAM450_HARBOUR_WORDS:-$_p/oorexx_slam_toprope_v0.1/examples/harbour}"
_llm="$ANTHROPIC_PROVIDER_ROOT/src:$_p/alchemy_objects_v0.8/src:$_p/oorexx_ai_access_v0.6/src:$_p/oorexx_secret_broker_v0.2/src:$_p/oorexx_crypto_v0.1/src"
_std="$(dirname "$(command -v rexx)")"
export REXX_PATH="$_slam450_pkg/src:$PHYSICS_WORLD_ROOT/rexx:$MATHS_ROOT/rexx:$FOREIGN_RUNTIME_ROOT/rexx:$COMPRESS_ROOT/src:$COMPRESS_ROOT/foreign:$_llm:$POWER_SLAM_ROOT/src:$_std"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build:/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="$MATHS_ROOT/python:$COMPRESS_ROOT/python${PYTHONPATH:+:$PYTHONPATH}"
for _f in "$PHYSICS_WORLD_ROOT/rexx/FixedWingFlight.cls" "$MATHS_ROOT/rexx/MathFastLanes.cls"; do
  [ -f "$_f" ] || echo "slam450_env: missing $_f (needs Physics World dev51 + Maths v0.20)" >&2
done

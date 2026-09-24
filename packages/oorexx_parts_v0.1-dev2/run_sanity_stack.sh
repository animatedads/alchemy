#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RT=${REXXTRONICS_ROOT:-"$HERE/deps/rexxtronics_v0.1-dev15"}
MATHS=${OOREXX_MATHS_ROOT:-"$RT/deps/oorexx_maths_v0.8"}
[ -f "$MATHS/rexx/Maths.cls" ] || { echo "missing Maths v0.8" >&2; exit 2; }
export REXX_PATH="$MATHS/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$MATHS/tests"
rexx test_core.rex
rexx test_math3d.rex

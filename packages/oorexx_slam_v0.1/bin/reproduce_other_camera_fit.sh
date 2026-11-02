#!/bin/sh
# Power SLAM north-shore/blues native ooRexx reproduction on repository tree.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
REXX="${REXX_BIN:-rexx}"
cd "$ROOT"
"$REXX" tests/test_other_cameras.rex
"$REXX" tests/fit_other_cameras.rex

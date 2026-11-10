#!/bin/sh
# All first-party flight/model qualification uses native ooRexx.
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
# Tests write temporary policy/descriptor fixtures only inside an isolated dir.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
cd "$WORK"
"$REXX_BIN" "$ROOT/tests/test_course450.rex"
"$REXX_BIN" "$ROOT/tests/test_broadphase450.rex"
"$REXX_BIN" "$ROOT/tests/test_memory450.rex"
"$REXX_BIN" "$ROOT/tests/test_fixed_camera450.rex"
echo 'SLAM450 V0.2 NATIVE SUITE PASS'

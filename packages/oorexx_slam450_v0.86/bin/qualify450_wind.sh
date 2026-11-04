#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
cd "$WORK"
"${REXX_BIN:-rexx}" "$ROOT/tests/test_wind450.rex"
"${REXX_BIN:-rexx}" "$ROOT/tests/test_explore450.rex"
"${REXX_BIN:-rexx}" "$ROOT/tests/test_fixed_camera450.rex"

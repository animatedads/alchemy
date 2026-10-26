#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX_BIN=${REXX_BIN:-rexx}
REXX_PATH="$ROOT" "$REXX_BIN" "$ROOT/test_vanishing_dinner.rex"
REXX_PATH="$ROOT" "$REXX_BIN" "$ROOT/test_silence_openworld.rex"

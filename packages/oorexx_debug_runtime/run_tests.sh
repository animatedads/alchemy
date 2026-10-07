#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REXX=${REXX:-rexx}
export REXX_PATH="$ROOT/src:$ROOT/dependencies/event_runtime_v0.1-dev1${REXX_PATH:+:$REXX_PATH}"
for t in "$ROOT"/tests/test_core.rex "$ROOT"/tests/test_gdb_mi.rex "$ROOT"/tests/test_jdwp.rex "$ROOT"/tests/test_adb_jdwp.rex; do
  "$REXX" "$t"
done

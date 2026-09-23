#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${FOREIGN_RUNTIME_ROOT:?Set FOREIGN_RUNTIME_ROOT to ooRexx Foreign Runtime v0.22.6 root}"
export REXX_PATH="$ROOT/src:$FOREIGN_RUNTIME_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$FOREIGN_RUNTIME_ROOT/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
rexx "$ROOT/tests/test_core.rex"
rexx "$ROOT/tests/test_udev.rex"
if [ -n "${OBSERVATION_ROOT:-}" ]; then
  export REXX_PATH="$ROOT/src:$FOREIGN_RUNTIME_ROOT/rexx:$OBSERVATION_ROOT/src${REXX_PATH:+:$REXX_PATH}"
  rexx "$ROOT/tests/test_observation_integration.rex"
fi

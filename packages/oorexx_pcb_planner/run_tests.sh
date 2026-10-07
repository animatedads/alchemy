#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${REXXTRONICS_ROOT:?set REXXTRONICS_ROOT to the Rexx-tronics package root}"
REXX_BIN=${REXX_BIN:-rexx}
UNITS_REXX=${UNITS_REXX:-$REXXTRONICS_ROOT/deps/oorexx_units_v0.1-dev4/rexx}
OLD_REXX_PATH=${REXX_PATH:-}
export REXX_PATH="$ROOT/src:$REXXTRONICS_ROOT/src:$UNITS_REXX${OLD_REXX_PATH:+:$OLD_REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_pcb_identity.rex"
"$REXX_BIN" "$ROOT/tests/test_pcb_board_graph.rex"
"$REXX_BIN" "$ROOT/tests/test_pcb_manufacturing_router.rex"
: "${INTENTION_SERVICE_ROOT:?set INTENTION_SERVICE_ROOT to Intention Service v0.1-dev11 root}"
export REXX_PATH="$ROOT/src:$INTENTION_SERVICE_ROOT/src:$REXX_PATH"
"$REXX_BIN" "$ROOT/tests/test_pcb_intentions.rex"

#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${REXX:?Set REXX to your native ooRexx executable}"
mkdir -p "$ROOT/input" "$ROOT/state"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/test_core.rex" "$ROOT"
exec "$REXX" "$ROOT/tests/test_delivery.rex" "$ROOT"

#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${OOREXX_ROOT:=/usr/local}"
export PATH="$OOREXX_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib:$ROOT/native${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/src/providers:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_ROOT/bin/rexx" "$ROOT/tests/test_smoke.rex"
"$OOREXX_ROOT/bin/rexx" "$ROOT/tests/test_contract.rex"

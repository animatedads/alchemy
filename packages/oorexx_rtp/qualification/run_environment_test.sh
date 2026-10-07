#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
: "${OOREXX_ROOT:=/usr/local}"
make -C "$ROOT" clean all OOREXX_ROOT="$OOREXX_ROOT"
export LD_LIBRARY_PATH="$ROOT/build:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_ROOT/bin/rexx" "$ROOT/tests/shared_rtp_probe.rex"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export REXX_PATH="$PWD/src${REXX_PATH:+:$REXX_PATH}"
: "${REXX_BIN:=rexx}"
"$REXX_BIN" tests/test_session_wire.rex
"$REXX_BIN" tests/test_receipt_gate.rex

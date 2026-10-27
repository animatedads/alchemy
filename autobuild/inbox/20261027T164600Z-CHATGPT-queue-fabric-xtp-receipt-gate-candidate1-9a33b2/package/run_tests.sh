#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
: "${REXX_BIN:=rexx}"
export REXX_PATH="$PWD/src${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" tests/test_receipt_gate.rex

#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
QUEUE_ROOT="${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT}"
: "${REXX:=rexx}"
export PATH="$QUEUE_ROOT/src:$ROOT/integration:$ROOT/algorithm:$ROOT:$PATH"
export REXX_PATH="$QUEUE_ROOT/src:$ROOT/integration:$ROOT/algorithm:$ROOT${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
"$REXX" test_queue_authority_execution_v021.rex

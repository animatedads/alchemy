#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:=rexx}"
: "${OP_PLANNER_ROOT:?Set OP_PLANNER_ROOT to Operational Degradation Planner dev5}"
: "${SERVICE_DESCRIPTOR_ROOT:?Set SERVICE_DESCRIPTOR_ROOT to Service Descriptors dev2}"
export REXX_PATH="$ROOT/src:$OP_PLANNER_ROOT/rexx:$SERVICE_DESCRIPTOR_ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT/tests"
exec "$REXX_BIN" test_parallel_fetch_pressure.rex

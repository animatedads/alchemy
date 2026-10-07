#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"

echo "Memory Fabric environment qualification"
echo "package: $HERE"

if ! command -v "$REXX_BIN" >/dev/null 2>&1; then
  echo "FAIL: ooRexx executable '$REXX_BIN' not found"
  exit 20
fi

"$REXX_BIN" -v || true

export REXX_PATH="$HERE/src:$HERE/build${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$HERE/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$HERE/tests"
"$REXX_BIN" test_memory_fabric.rex
"$REXX_BIN" test_memory_snapshot_epoch.rex
"$REXX_BIN" test_memory_block_connector.rex
"$REXX_BIN" test_provider_lifecycle.rex
"$REXX_BIN" test_memory_block_lifecycle.rex
"$REXX_BIN" test_memory_paging.rex
"$REXX_BIN" test_registered_job_economic_hold.rex
"$REXX_BIN" test_memory_capacity_plan.rex
"$REXX_BIN" test_execution_context.rex

echo "PASS: Memory Fabric snapshot epochs + native MU memory-block bag + provider/bag lifecycle + MI attachment fencing + RexxOS paging + service/economic/execution-context qualification"

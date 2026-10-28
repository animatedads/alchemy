#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REXX_BIN=${REXX_BIN:-rexx}
MEMORY_FABRIC_ROOT=${MEMORY_FABRIC_ROOT:-}
REXXOS_GRID_ROOT=${REXXOS_GRID_ROOT:-}
JOB_NODE_ALLOCATOR_ROOT=${JOB_NODE_ALLOCATOR_ROOT:-}

if [ -z "$MEMORY_FABRIC_ROOT" ] || [ -z "$REXXOS_GRID_ROOT" ] || [ -z "$JOB_NODE_ALLOCATOR_ROOT" ]; then
  echo "Set MEMORY_FABRIC_ROOT, REXXOS_GRID_ROOT and JOB_NODE_ALLOCATOR_ROOT" >&2
  exit 64
fi

OLD_REXX_PATH=${REXX_PATH:-}
REXX_PATH="$HERE/src:$HERE/integrations:$MEMORY_FABRIC_ROOT/src:$REXXOS_GRID_ROOT/grid:$JOB_NODE_ALLOCATOR_ROOT/src:$REXXOS_GRID_ROOT/deps"
if [ -n "$OLD_REXX_PATH" ]; then REXX_PATH="$REXX_PATH:$OLD_REXX_PATH"; fi
export REXX_PATH

"$REXX_BIN" -v | head -3
for t in "$HERE"/tests/*.rex; do
  echo "[media] $(basename "$t")"
  "$REXX_BIN" "$t"
done

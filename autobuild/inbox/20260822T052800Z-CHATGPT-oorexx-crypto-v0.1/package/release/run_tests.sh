#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
if [[ -n "${REXX_PATH:-}" ]]; then
  export REXX_PATH="$ROOT/src:$REXX_PATH"
else
  export REXX_PATH="$ROOT/src"
fi
status=0
for test in "$ROOT"/tests/*.rex; do
  echo "=== $(basename "$test") ==="
  if ! "$REXX" "$test"; then
    status=1
    break
  fi
done
exit "$status"

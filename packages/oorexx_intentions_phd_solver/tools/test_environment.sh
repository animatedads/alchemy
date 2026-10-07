#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v rexx >/dev/null 2>&1; then
  echo "FAIL: ooRexx 'rexx' executable not found in PATH" >&2
  exit 127
fi
export REXX_PATH="$ROOT/src:$ROOT/deps/intention_service/src${REXX_PATH:+:$REXX_PATH}"
echo "ooRexx: $(rexx -v 2>&1 | head -1)"
for t in "$ROOT"/tests/test_*.rex; do
  echo "== $(basename "$t") =="
  rexx "$t"
done
echo "PASS scientific solver environment qualification"

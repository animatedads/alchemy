#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export REXX_PATH="$ROOT/src:$ROOT/lib:$ROOT/integration/audio:$ROOT/integration/storage${REXX_PATH:+:$REXX_PATH}"
REXX_BIN="${REXX_BIN:-rexx}"
count=0
for t in "$ROOT"/tests/test_*.rex; do
  echo "== $(basename "$t") =="
  "$REXX_BIN" "$t"
  count=$((count+1))
done
echo "PASS ALL ooRexx ML v0.1-dev11 TESTS ($count files)"

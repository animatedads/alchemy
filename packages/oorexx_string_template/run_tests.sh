#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REXX_BIN=${REXX_BIN:-rexx}
REXXC_BIN=${REXXC_BIN:-rexxc}
export REXX_PATH="$HERE/src${REXX_PATH:+:$REXX_PATH}"

"$REXXC_BIN" "$HERE/src/StringTemplate.cls"

count=0
for test in "$HERE"/tests/*.rex; do
  echo "== $(basename "$test") =="
  "$REXX_BIN" "$test"
  count=$((count + 1))
done

echo "PASS $count/$count StringTemplate fixtures"

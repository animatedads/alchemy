#!/bin/sh
set -e
ROOT="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cd "$ROOT"
REXX="${REXX_BIN:-rexx}"
fail=0
for t in tests/test_*.rex; do
  echo "== $t =="
  if ! "$REXX" "$t"; then
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then
  echo "RESULT: FAILURES"
  exit 1
fi
echo "RESULT: PASS"
exit 0

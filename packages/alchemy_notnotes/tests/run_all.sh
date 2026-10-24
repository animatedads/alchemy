#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${NOTNOTES_REXX:?set NOTNOTES_REXX to the qualified ooRexx rexx executable}"
: "${NOTNOTES_RTO_SRC:?set NOTNOTES_RTO_SRC to sealed Alchemy RTO dev4 src directory}"
: "${NOTNOTES_SECURITY_SRC:?set NOTNOTES_SECURITY_SRC to directory containing RTOSecurityManager.cls}"
: "${NOTNOTES_INTENTION_SRC:?set NOTNOTES_INTENTION_SRC to Intention Service dev7 src directory}"
RUNTIME_BIN="${NOTNOTES_RUNTIME_BIN:-$(dirname "$NOTNOTES_REXX")}" 
export REXX_PATH="${ROOT}/src:${NOTNOTES_INTENTION_SRC}:${NOTNOTES_RTO_SRC}:${NOTNOTES_SECURITY_SRC}:${RUNTIME_BIN}:${REXX_PATH:-}"
if [ -n "${NOTNOTES_LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH="${NOTNOTES_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH:-}"
fi
cd "$ROOT"
fail=0
count=0
for test in "$ROOT"/tests/test_*.rex; do
  count=$((count+1))
  echo "=== $(basename "$test") ==="
  if ! "$NOTNOTES_REXX" "$test"; then
    fail=$((fail+1))
  fi
done
echo "NOTNOTES_TESTS=$count FAILURES=$fail"
[ "$fail" -eq 0 ]

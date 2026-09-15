#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${BRANCH_CASH_SRC:?set BRANCH_CASH_SRC}"
: "${BRANCH_CASH_SERVICE_SRC:?set BRANCH_CASH_SERVICE_SRC}"
: "${TILL_SRC:?set TILL_SRC}"
export REXX_PATH="$HERE/src:$HERE/runtime:$HERE/tests:$BRANCH_CASH_SRC:$BRANCH_CASH_SERVICE_SRC:$TILL_SRC${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
for t in test_*.rex; do echo "== $t =="; "$REXX_BIN" "$t"; done

#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REXX_PATH="$HERE/src:$HERE/runtime:$HERE/tests:${BRANCH_CASH_SRC:?}:${BRANCH_CASH_SERVICE_SRC:?}:${EXTERNAL_CASH_SRC:?}:${EXTERNAL_CASH_SERVICE_SRC:?}${REXX_PATH:+:$REXX_PATH}"
for t in "$HERE"/tests/test_*.rex; do rexx "$t"; done

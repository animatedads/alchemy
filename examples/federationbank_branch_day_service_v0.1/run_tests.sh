#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${BRANCH_DAY_SRC:?set BRANCH_DAY_SRC}"
: "${QUEUE_SRC:?set QUEUE_SRC}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC}"
: "${CRYPTO_SRC:?set CRYPTO_SRC}"
: "${OOREXX_LIB:?set OOREXX_LIB}"
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/runtime:$HERE/tests:$BRANCH_DAY_SRC:$QUEUE_SRC:$ALCHEMY_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
for t in test_*.rex; do echo "== $t =="; "$REXX_BIN" "$t"; done

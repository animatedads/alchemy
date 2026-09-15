#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
export REXX_PATH="$HERE/src:$HERE/runtime:$HERE/tests${REXX_PATH:+:$REXX_PATH}"
cd "$HERE/tests"
for t in test_*.rex; do echo "== $t =="; "$REXX_BIN" "$t"; done

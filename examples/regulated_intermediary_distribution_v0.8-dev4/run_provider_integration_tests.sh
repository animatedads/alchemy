#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${ALL_JAPAN_SRC:?set ALL_JAPAN_SRC to all_japan_insurance_v0.9/src}"
export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/tests:$ALL_JAPAN_SRC${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$HERE/tests/test_all_japan_intermediary_adapter.rex"

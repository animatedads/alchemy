#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
: "${INTENTION_SERVICE_ROOT:?INTENTION_SERVICE_ROOT must name the sibling ooRexx Intention Service package}"
if [[ -f "$INTENTION_SERVICE_ROOT/src/IntentionService.cls" ]]; then
  INTENTION_SRC="$INTENTION_SERVICE_ROOT/src"
elif [[ -f "$INTENTION_SERVICE_ROOT/IntentionService.cls" ]]; then
  INTENTION_SRC="$INTENTION_SERVICE_ROOT"
else
  echo "missing IntentionService.cls under INTENTION_SERVICE_ROOT=$INTENTION_SERVICE_ROOT" >&2
  exit 2
fi
export REXX_PATH="$ROOT/src:$ROOT/tests:$INTENTION_SRC:$INTENTION_SRC/nlp${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"
"$REXX_BIN" tests/test_legal_interrogation.rex
"$REXX_BIN" tests/test_intention_port.rex
"$REXX_BIN" tests/test_lifecycle.rex
"$REXX_BIN" tests/test_dev11_discovery.rex
"$REXX_BIN" tests/test_intention_service_dev11_live.rex
printf '%s\n' 'LEGAL INTERROGATION AUTOBUILD TESTS: PASS'

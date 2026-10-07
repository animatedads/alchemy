#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"
: "${INTENTION_SERVICE_ROOT:?set INTENTION_SERVICE_ROOT to ooRexx Intention Service v0.1-dev11}"
for f in "$INTENTION_SERVICE_ROOT/src/IntentionService.cls" "$INTENTION_SERVICE_ROOT/src/IntentionContext.cls"; do
  [[ -f "$f" ]] || { echo "missing dependency: $f" >&2; exit 2; }
done
REXX_BIN_DIR="$(cd "$(dirname "$(command -v "$REXX")")" && pwd)"
export REXX_PATH="$ROOT:$INTENTION_SERVICE_ROOT/src:$REXX_BIN_DIR${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"
"$REXX" tests/test_intention_service.rex

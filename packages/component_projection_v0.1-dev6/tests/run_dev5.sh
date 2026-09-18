#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"
CP_SRC="$ROOT/src"
ADAPTERS="$ROOT/src/adapters"
export REXX_PATH="$CP_SRC:$ADAPTERS:${REXX_PATH:-}"
"$ROOT/tests/run_all.sh"
"$REXX" "$ROOT/tests/adapters/test_inspector_adapter.rex"
REXX_PATH="$ROOT/tests/stubs:$CP_SRC:$ADAPTERS:${REXX_PATH:-}" "$REXX" "$ROOT/tests/test_nosql.rex"
if [[ -n "${CLOUSEAU_ROOT:-}" && -f "$CLOUSEAU_ROOT/InspectorClouseau.cls" ]]; then
  REXX_PATH="$CLOUSEAU_ROOT:$CP_SRC:$ADAPTERS:${REXX_PATH:-}" "$REXX" "$ROOT/tests/adapters/test_inspector_actual.rex"
fi

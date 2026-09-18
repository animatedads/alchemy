#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"
CP_SRC="$ROOT/src"
ADAPTERS="$ROOT/src/adapters"
cd "$ROOT/tests"
export REXX_PATH="$CP_SRC:$ADAPTERS:${REXX_PATH:-}"
"$REXX" test_core.rex
"$REXX" adapters/test_queuerexx_adapter.rex
"$REXX" adapters/test_inspector_adapter.rex
REXX_PATH="$ROOT/tests/stubs:$CP_SRC:$ADAPTERS:${REXX_PATH:-}" "$REXX" test_nosql.rex
if [[ -n "${CLOUSEAU_ROOT:-}" && -f "$CLOUSEAU_ROOT/InspectorClouseau.cls" ]]; then
  REXX_PATH="$CLOUSEAU_ROOT:$CP_SRC:$ADAPTERS:${REXX_PATH:-}" "$REXX" adapters/test_inspector_actual.rex
fi
if [[ -n "${NOSQL_SRC:-}" && -n "${ALCHEMY_SRC:-}" && -n "${CRYPTO_SRC:-}" ]]; then
  REXX_PATH="$NOSQL_SRC:$ALCHEMY_SRC:$CRYPTO_SRC:$CP_SRC:$ADAPTERS:${PROVENANCE_SRC:-}:${REXX_PATH:-}" "$REXX" test_nosql_actual.rex
fi

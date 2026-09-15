#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
if [[ "$REXX_BIN" != */* ]]; then REXX_BIN="$(command -v "$REXX_BIN")"; fi
: "${ALCHEMY_OBJECTS_ROOT:?ALCHEMY_OBJECTS_ROOT required}"
: "${WLU_ROOT:?WLU_ROOT required}"
: "${INSTITUTIONAL_POLICY_ROOT:?INSTITUTIONAL_POLICY_ROOT required}"
: "${CRYPTO_SRC:?CRYPTO_SRC required}"
export LD_LIBRARY_PATH="$(dirname "$REXX_BIN")/../lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$(dirname "$REXX_BIN"):$ALCHEMY_OBJECTS_ROOT/src:$WLU_ROOT/src:$INSTITUTIONAL_POLICY_ROOT/src:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
"$REXX_BIN" "$ROOT/tests/test_ai_model_router.rex"

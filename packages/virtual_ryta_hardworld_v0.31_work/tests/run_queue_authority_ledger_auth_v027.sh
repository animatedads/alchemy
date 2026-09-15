#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
: "${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT}"
CRYPTO_SRC_ROOT="${OOREXX_CRYPTO_SRC:-${CRYPTO_SRC:-}}"
: "${CRYPTO_SRC_ROOT:?set OOREXX_CRYPTO_SRC or CRYPTO_SRC}"
: "${REXX:=rexx}"
export REXX OOREXX_CRYPTO_SRC="$CRYPTO_SRC_ROOT" CRYPTO_SRC="$CRYPTO_SRC_ROOT"
export PATH="$(dirname "$REXX"):$PATH"
export REXX_PATH="$ROOT:$ROOT/algorithm:$ROOT/integration:$QUEUE_FABRIC_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC_ROOT:$(dirname "$REXX")${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
"$REXX" test_queue_authority_ledger_auth_v027.rex

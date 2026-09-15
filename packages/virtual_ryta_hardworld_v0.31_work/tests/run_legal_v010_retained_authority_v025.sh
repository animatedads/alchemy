#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
RUNTIME_ROOT="${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
QUEUE_ROOT="${QUEUE_FABRIC_ROOT:?set QUEUE_FABRIC_ROOT}"
CRYPTO_SRC_ROOT="${OOREXX_CRYPTO_SRC:-${CRYPTO_SRC:-}}"
: "${CRYPTO_SRC_ROOT:?set OOREXX_CRYPTO_SRC or CRYPTO_SRC}"
: "${REXX:=rexx}"
export PATH="$LEGAL_ROOT/src:$LEGAL_ROOT/tests:$RUNTIME_ROOT/src:$QUEUE_ROOT/src:$CRYPTO_SRC_ROOT:$ROOT/integration:$ROOT/algorithm:$ROOT:$PATH"
export REXX_PATH="$LEGAL_ROOT/src:$LEGAL_ROOT/tests:$RUNTIME_ROOT/src:$QUEUE_ROOT/src:$CRYPTO_SRC_ROOT:$ROOT/integration:$ROOT/algorithm:$ROOT${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
"$REXX" test_legal_v010_retained_authority_v025.rex

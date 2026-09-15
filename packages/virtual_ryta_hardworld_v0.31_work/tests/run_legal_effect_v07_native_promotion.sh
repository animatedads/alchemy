#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LEGAL_ROOT="${LEGAL_EFFECT_ROOT:?set LEGAL_EFFECT_ROOT}"
RUNTIME_ROOT="${RUNTIME_REGISTRY_ROOT:?set RUNTIME_REGISTRY_ROOT}"
CRYPTO_SRC_ROOT="${OOREXX_CRYPTO_SRC:-${CRYPTO_SRC:-}}"
: "${CRYPTO_SRC_ROOT:?set OOREXX_CRYPTO_SRC or CRYPTO_SRC to standalone oorexx_crypto src}"
: "${REXX:=rexx}"
export PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src:$CRYPTO_SRC_ROOT:$ROOT/integration:$ROOT/algorithm:$ROOT:$PATH"
export REXX_PATH="$LEGAL_ROOT/src:$RUNTIME_ROOT/src:$CRYPTO_SRC_ROOT:$ROOT/integration:$ROOT/algorithm:$ROOT${REXX_PATH:+:$REXX_PATH}"
cd "$HERE"
"$REXX" test_legal_effect_v07_native_promotion.rex.in

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:?ALCHEMY_OBJECTS_ROOT is required}"
REXX_BIN="${REXX_BIN:-rexx}"
CRYPTO_SRC="${CRYPTO_SRC:?CRYPTO_SRC is required}"
REXX_BIN_DIR="$(cd "$(dirname "$REXX_BIN")" && pwd)"
OLD_REXX_PATH="${REXX_PATH:-}"
export REXX_PATH="$ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$CRYPTO_SRC:$REXX_BIN_DIR${OLD_REXX_PATH:+:$OLD_REXX_PATH}"
cd "$ROOT"
for t in tests/test_secret_broker.rex tests/test_mapped_environment.rex tests/test_alchemy_adoption.rex; do
  "$REXX_BIN" "$t"
done

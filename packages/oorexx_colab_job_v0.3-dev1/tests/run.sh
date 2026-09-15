#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
ALLOCATOR_SRC="${ALLOCATOR_SRC:?ALLOCATOR_SRC is required}"
SECRET_BROKER_SRC="${SECRET_BROKER_SRC:?SECRET_BROKER_SRC is required}"
ALCHEMY_OBJECTS_SRC="${ALCHEMY_OBJECTS_SRC:?ALCHEMY_OBJECTS_SRC is required}"
CRYPTO_SRC="${CRYPTO_SRC:?CRYPTO_SRC is required}"
REXX_LIB_SRC="${REXX_LIB_SRC:-$(cd "$(dirname "$REXX_BIN")" && pwd)}"
OLD_REXX_PATH="${REXX_PATH:-}"
export REXX_PATH="$ROOT/src:$ALLOCATOR_SRC:$SECRET_BROKER_SRC:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC:$REXX_LIB_SRC${OLD_REXX_PATH:+:$OLD_REXX_PATH}"
cd "$ROOT/tests"
"$REXX_BIN" test_core.rex
"$REXX_BIN" test_allocator.rex
"$REXX_BIN" test_secrets.rex

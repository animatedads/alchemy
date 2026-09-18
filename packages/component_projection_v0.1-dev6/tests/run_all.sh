#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${REXX:=rexx}"
: "${STORAGE_FABRIC_ROOT:=}"
: "${QUEUEREXX_SRC:=}"
: "${QUEUE_FABRIC_SRC:=}"
: "${ALCHEMY_SRC:=}"
: "${CRYPTO_SRC:=}"
: "${POSIX_SRC:=}"
: "${POSIX_PROVIDERS_SRC:=}"

"$REXX" test_core.rex
REXX_PATH="../src:../src/adapters${REXX_PATH:+:$REXX_PATH}" "$REXX" adapters/test_queuerexx_adapter.rex

if [ -n "$STORAGE_FABRIC_ROOT" ]; then
  REXX_PATH="../src:$STORAGE_FABRIC_ROOT${REXX_PATH:+:$REXX_PATH}" "$REXX" test_fuse.rex
fi

if [ -n "$QUEUE_FABRIC_SRC" ] && [ -n "$ALCHEMY_SRC" ] && [ -n "$CRYPTO_SRC" ]; then
  REXX_PATH="../src:../src/adapters:$QUEUE_FABRIC_SRC:$ALCHEMY_SRC:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}" "$REXX" adapters/test_queuefabric_adapter.rex
fi

if [ -n "$QUEUEREXX_SRC" ] && [ -n "$POSIX_SRC" ] && [ -n "$POSIX_PROVIDERS_SRC" ]; then
  REXX_PATH="../src:../src/adapters:$QUEUEREXX_SRC:$POSIX_SRC:$POSIX_PROVIDERS_SRC${REXX_PATH:+:$REXX_PATH}" "$REXX" adapters/test_queuerexx_actual.rex adapters/fixtures/root
fi

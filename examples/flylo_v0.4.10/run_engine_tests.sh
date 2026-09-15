#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

: "${OOREXX_HOME:?set OOREXX_HOME to the ooRexx installation root}"
QUEUE_FABRIC_SRC="${QUEUE_FABRIC_SRC:-$ROOT/vendor/oorexx_queue_fabric_v0.9-dev4/src}"
ALCHEMY_OBJECTS_SRC="${ALCHEMY_OBJECTS_SRC:-$ROOT/vendor/alchemy_objects_v0.8/src}"
LEGAL_EFFECT_SRC="${LEGAL_EFFECT_SRC:-$ROOT/vendor/legal_effect_v0.14/src}"
OOREXX_CRYPTO_SRC="${OOREXX_CRYPTO_SRC:-$ROOT/vendor/oorexx_crypto_v0.5/src}"

export OOREXX_BIN="$OOREXX_HOME/bin"
export OOREXX_LIB="$OOREXX_HOME/lib"
export PATH="$OOREXX_BIN:$PATH"
export LD_LIBRARY_PATH="$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/accounting_core_v0.7/src:$QUEUE_FABRIC_SRC:$ALCHEMY_OBJECTS_SRC:$LEGAL_EFFECT_SRC:$OOREXX_CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
export FLYLO_TEST_DURABLE_ROOT="${FLYLO_TEST_DURABLE_ROOT:-$ROOT/.test-runtime/engine-durable}"

rm -rf "$FLYLO_TEST_DURABLE_ROOT"
mkdir -p "$(dirname "$FLYLO_TEST_DURABLE_ROOT")"
trap 'rm -rf "$ROOT/.test-runtime"' EXIT

cd "$ROOT"
for t in \
  tests/test_engine_route_search.rex \
  tests/test_engine_booking_saga.rex \
  tests/test_engine_queue_boundary.rex \
  tests/test_engine_restart.rex \
  tests/test_sales_process_engine.rex \
  tests/test_accounting_integration.rex
do
  echo "=== $(basename "$t") ==="
  "$OOREXX_BIN/rexx" "$t"
done

echo "=== rexxc source compile ==="
for f in src/*.cls; do
  "$OOREXX_BIN/rexxc" "$f" >/dev/null
  echo "OK $(basename "$f")"
done

echo "=== node --check web/flylo.js ==="
node --check web/flylo.js

echo "FlyLo v0.4.10 engine qualification: PASS"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export FLYLO_TEST_DURABLE_ROOT="$ROOT/.test-runtime/engine-durable"
rm -rf "$ROOT/.test-runtime"
mkdir -p "$ROOT/.test-runtime"
trap 'rm -rf "$ROOT/.test-runtime"' EXIT
: "${OOREXX_HOME:?set OOREXX_HOME to the ooRexx installation root}"
: "${LEGAL_EFFECT_SRC:?set LEGAL_EFFECT_SRC to legal_effect_v0.14/src}"
: "${WIRE_UI_BUILDER_SRC:?set WIRE_UI_BUILDER_SRC to wire_ui_builder_v0.11/src}"
: "${WIRE_UI_SERVER_SRC:?set WIRE_UI_SERVER_SRC to wire_ui_server_v0.17/src}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC to alchemy_objects_v0.8/src}"
: "${OOREXX_CRYPTO_SRC:?set OOREXX_CRYPTO_SRC to oorexx_crypto_v0.5/src}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${AI_ACCESS_SRC:?set AI_ACCESS_SRC to oorexx_ai_access_v0.6/src}"
: "${WIRE_UI_JS_ROOT:?set WIRE_UI_JS_ROOT to alchemy_wire_ui_js_v0.4-dev4 package root}"
: "${WIRE_UI_WEB_GATEWAY_ROOT:?set WIRE_UI_WEB_GATEWAY_ROOT to oorexx_queue_fabric_web_gateway_v0.2 root}"

export OOREXX_BIN="$OOREXX_HOME/bin"
export OOREXX_LIB="$OOREXX_HOME/lib"
export PATH="$OOREXX_BIN:$PATH"
export LD_LIBRARY_PATH="$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/vendor/oorexx_stdlib_5.3.0_r13196:$ROOT/src:$ROOT/vendor/accounting_core_v0.7/src:$WIRE_UI_SERVER_SRC:$WIRE_UI_WEB_GATEWAY_ROOT/src:$WIRE_UI_BUILDER_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$QUEUE_FABRIC_SRC:$LEGAL_EFFECT_SRC:$AI_ACCESS_SRC:$ROOT/vendor/oorexx_ai_provider_grok_v0.4/src:$ROOT/vendor/oorexx_secret_broker_v0.2/src:$ROOT/vendor/structured_utterance_v0.3/src${REXX_PATH:+:$REXX_PATH}"

cd "$ROOT"
for t in tests/test_*.rex; do
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

echo "=== ./flylo server-backed Wire UI v0.17 manage workspace ==="
node tests/test_launcher_server_backed_manage.mjs

echo "=== ./flylo durable restart passenger workspace ==="
node tests/test_launcher_restart_persistence.mjs

echo "=== real Queue Fabric Web Gateway full booking + assistant ==="
node tests/test_full_web_gateway.mjs

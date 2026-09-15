#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_HOME:?set OOREXX_HOME to the ooRexx installation root}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC to alchemy_objects source}"
: "${OOREXX_CRYPTO_SRC:?set OOREXX_CRYPTO_SRC to oorexx_crypto_v0.1/src}"
: "${WIRE_UI_JS_ROOT:?set WIRE_UI_JS_ROOT to alchemy_wire_ui_js_v0.4-dev3 root}"
: "${WIRE_UI_SERVER_SRC:?set WIRE_UI_SERVER_SRC to wire_ui_server_v0.8/src}"
export OOREXX_BIN="$OOREXX_HOME/bin"
export OOREXX_LIB="$OOREXX_HOME/lib"
export PATH="$ROOT/src:$WIRE_UI_SERVER_SRC:$QUEUE_FABRIC_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$OOREXX_BIN:$PATH"
export REXX_PATH="$ROOT/src:$WIRE_UI_SERVER_SRC:$QUEUE_FABRIC_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$OOREXX_BIN${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT/tests"
echo '=== test_backend.rex ==='
"$OOREXX_BIN/rexx" test_backend.rex
echo '=== test_async_listener.rex ==='
"$OOREXX_BIN/rexx" test_async_listener.rex
echo '=== test_access_point_binding.rex ==='
"$OOREXX_BIN/rexx" test_access_point_binding.rex
echo '=== test_websocket_edge.mjs ==='
node --test test_websocket_edge.mjs
echo '=== test_wire_ui_browser_roundtrip.mjs ==='
node test_wire_ui_browser_roundtrip.mjs

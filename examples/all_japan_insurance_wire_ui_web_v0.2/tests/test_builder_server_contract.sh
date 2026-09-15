#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${AJI_OOREXX:?set AJI_OOREXX to ooRexx rexx binary}"
: "${AJI_OOREXX_LIB:?set AJI_OOREXX_LIB to ooRexx library directory}"
: "${WIRE_UI_BUILDER_ROOT:?set WIRE_UI_BUILDER_ROOT to wire_ui_builder_v0.11 root}"
: "${WIRE_UI_SERVER_ROOT:?set WIRE_UI_SERVER_ROOT to wire_ui_server_v0.17 root}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.8 root}"
: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT to oorexx_crypto_v0.5 root}"
export LD_LIBRARY_PATH="$AJI_OOREXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$(dirname "$AJI_OOREXX"):$ROOT/src:$WIRE_UI_BUILDER_ROOT/src:$WIRE_UI_SERVER_ROOT/src:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$AJI_OOREXX" "$ROOT/tests/test_builder_server_contract.rex"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
"$AJI_OOREXX" "$ROOT/tools/build-compiled-release.rex" "$tmp" >/dev/null
cmp -s "$tmp" "$ROOT/runtime/aji-compiled-release.json" || { echo 'FAIL compiled release JSON does not match Builder source' >&2; exit 1; }
echo 'AJI compiled release source lock: PASS'

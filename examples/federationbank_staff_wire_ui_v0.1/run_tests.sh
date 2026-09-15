#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
required=(WIRE_UI_SERVER_SRC WIRE_UI_BUILDER_SRC ALCHEMY_SRC RUNTIME_REFERENCE_SRC ACCESS_PERMISSIONS_SRC SECURITY_EFFECT_SRC CRYPTO_SRC INSTITUTIONAL_POLICY_SRC FEDERATIONBANK_ENGINE_SRC STAFF_AUTHORITY_SRC STAFF_CHANNEL_SRC STAFF_CHANNEL_SERVICE_SRC STAFF_METHOD_PERMISSION_SRC STAFF_METHOD_PERMISSION_AGENT)
for n in "${required[@]}"; do [[ -n "${!n:-}" ]] || { echo "set $n" >&2; exit 2; }; done
export REXX_PATH="$ROOT/src:$ROOT/tests:$ROOT/integration:$ROOT/runtime:$WIRE_UI_SERVER_SRC:$WIRE_UI_BUILDER_SRC:$ALCHEMY_SRC:$RUNTIME_REFERENCE_SRC:$ACCESS_PERMISSIONS_SRC:$SECURITY_EFFECT_SRC:$CRYPTO_SRC:$INSTITUTIONAL_POLICY_SRC:$FEDERATIONBANK_ENGINE_SRC:$STAFF_AUTHORITY_SRC:$STAFF_CHANNEL_SRC:$STAFF_CHANNEL_SERVICE_SRC:$STAFF_METHOD_PERMISSION_SRC${EXTRA_REXX_PATH:+:$EXTRA_REXX_PATH}${REXX_PATH:+:$REXX_PATH}"
export STAFF_METHOD_PERMISSION_AGENT
pass=0
echo "== test_core_suite.rex =="
"$REXX_BIN" "$ROOT/tests/test_core_suite.rex"; pass=$((pass+5))
echo "== test_runtime_gateway_surface.rex =="
"$REXX_BIN" "$ROOT/tests/test_runtime_gateway_surface.rex"; pass=$((pass+1))
"$ROOT/tests/test_web_projection_shell.sh"; pass=$((pass+1))
"$ROOT/tests/test_preview_boundary.sh"; pass=$((pass+1))
"$ROOT/tests/test_starter.sh"; pass=$((pass+1))
echo "FEDERATIONBANK STAFF WIRE UI v0.1: PASS $pass/9"

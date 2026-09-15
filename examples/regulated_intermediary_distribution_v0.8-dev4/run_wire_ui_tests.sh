#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to alchemy_objects_v0.8/src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to oorexx_crypto_v0.5/src}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${RUNTIME_REFERENCE_SRC:?set RUNTIME_REFERENCE_SRC to runtime_reference_v0.2/src}"
: "${WIRE_UI_SERVER_SRC:?set WIRE_UI_SERVER_SRC to wire_ui_server_v0.17/src}"
: "${WIRE_UI_BUILDER_SRC:?set WIRE_UI_BUILDER_SRC to wire_ui_builder_v0.11/src}"
: "${ACCESS_PERMISSIONS_SRC:?set ACCESS_PERMISSIONS_SRC to oorexx_access_permissions_v0.1/src}"
: "${SECURITY_EFFECT_SRC:?set SECURITY_EFFECT_SRC to security_effect_v0.10/src}"
: "${POLICY_SRC:?set POLICY_SRC to institutional_policy_v0.8/src}"
export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/tests:$WIRE_UI_SERVER_SRC:$WIRE_UI_BUILDER_SRC:$ACCESS_PERMISSIONS_SRC:$SECURITY_EFFECT_SRC:$POLICY_SRC:$ALCHEMY_SRC:$CRYPTO_SRC:$QUEUE_FABRIC_SRC:$RUNTIME_REFERENCE_SRC${REXX_PATH:+:$REXX_PATH}"
for t in \
  test_wire_ui_compile.rex \
  test_wire_dashboard_authority.rex \
  test_wire_access_permissions.rex \
  test_wire_permission_proof.rex \
  test_wire_workspace_result_revision.rex \
  test_wire_live_provider_transition.rex \
  test_wire_case_timeline.rex \
  test_wire_signing_ceremony.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_HOME:=/usr/local}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC to alchemy_objects_v0.8/src}"
: "${OOREXX_CRYPTO_SRC:?set OOREXX_CRYPTO_SRC to oorexx_crypto_v0.1/src}"
: "${WIRE_UI_JS_SRC:?set WIRE_UI_JS_SRC to Alchemy Wire UI JS package root}"
: "${WIRE_UI_BUILDER_SRC:?set WIRE_UI_BUILDER_SRC to wire_ui_builder_v0.4/src}"
: "${WIRE_UI_BUILDER_EXAMPLES:?set WIRE_UI_BUILDER_EXAMPLES to wire_ui_builder_v0.4/examples}"
export PATH="$ROOT/src:$ROOT/examples:$WIRE_UI_BUILDER_SRC:$WIRE_UI_BUILDER_EXAMPLES:$QUEUE_FABRIC_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$OOREXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX="${REXX:-$OOREXX_HOME/bin/rexx}"
cd "$ROOT/tests"
for t in \
  test_package_identity.rex \
  test_wire_ui_v01.rex \
  test_queue_integration.rex \
  test_subscription_integration.rex \
  test_journey_planner.rex \
  test_agent_profile.rex \
  test_integration_lock.rex \
  test_compiled_release_binding.rex \
  test_experiment_assignment.rex \
  test_observation_contract.rex \
  test_render_profile_cache.rex \
  test_material_delivery.rex \
  test_v09_reconciliation.rex \
  test_dynamic_journey_runtime.rex \
  test_multi_action_binding.rex \
  test_journey_timing_evidence.rex \
  test_operational_workspace_projection.rex \
  test_intent_cross_object_projection.rex \
  test_large_collection_window.rex \
  test_workspace_command_state.rex \
  test_workspace_result_state.rex \
  test_alchemy_adoption.rex
do
  echo "=== $t ==="
  "$REXX" "$t"
done

echo "=== cross_language/cross_wire_js.mjs ==="
node "$ROOT/tests/cross_language/cross_wire_js.mjs"
echo "=== cross_language/cross_observation_js.mjs ==="
node "$ROOT/tests/cross_language/cross_observation_js.mjs"
echo "=== cross_language/cross_operational_workspace_js.mjs ==="
node "$ROOT/tests/cross_language/cross_operational_workspace_js.mjs"
echo "=== cross_language/cross_collection_window_js.mjs ==="
node "$ROOT/tests/cross_language/cross_collection_window_js.mjs"
echo "=== cross_language/cross_workspace_context_js.mjs ==="
node "$ROOT/tests/cross_language/cross_workspace_context_js.mjs"

if [[ -n "${WIRE_UI_GATEWAY_SRC:-}" && -f "$WIRE_UI_GATEWAY_SRC/src/index.js" ]]; then
  echo "=== gateway/full_gateway_runtime.mjs (legacy gateway integration) ==="
  node "$ROOT/tests/gateway/full_gateway_runtime.mjs"
elif [[ -n "${WIRE_UI_GATEWAY_SRC:-}" && -f "$WIRE_UI_GATEWAY_SRC/node/gateway.mjs" ]]; then
  echo "=== gateway/full_gateway_runtime.mjs SKIP: current Web Gateway package uses node/gateway.mjs; validate with its own v0.2 acceptance ==="
else
  echo "=== gateway/full_gateway_runtime.mjs SKIP: compatible legacy WIRE_UI_GATEWAY_SRC not set ==="
fi

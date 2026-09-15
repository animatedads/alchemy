#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_HOME:=/usr/local}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC to alchemy_objects_v0.8/src}"
: "${OOREXX_CRYPTO_SRC:?set OOREXX_CRYPTO_SRC to oorexx_crypto_v0.3/src}"
SERVER_PATH=""
if [[ -n "${WIRE_UI_SERVER_SRC:-}" ]]; then SERVER_PATH+=":$WIRE_UI_SERVER_SRC"; fi
if [[ -n "${QUEUE_FABRIC_SRC:-}" ]]; then SERVER_PATH+=":$QUEUE_FABRIC_SRC"; fi
if [[ -n "${WUIB_GATEWAY_ROOT:-}" && -d "${WUIB_GATEWAY_ROOT}/src" ]]; then SERVER_PATH+=":${WUIB_GATEWAY_ROOT}/src"; fi
export PATH="$ROOT/src:$ROOT/examples:$ROOT/integration:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC${SERVER_PATH}:$OOREXX_HOME/bin:$PATH"
export REXX_PATH="$ROOT/src:$ROOT/examples:$ROOT/integration:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC${SERVER_PATH}:$OOREXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$OOREXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$ROOT/tests"
core=(
  test_versioning.rex test_compile_release.rex test_element_experiment.rex
  test_multiuser_preview.rex test_ab_preview.rex test_preview_evidence.rex
  test_alchemy_adoption.rex test_workspace_operations.rex test_preview_matrix.rex
  test_render_observation.rex test_builder_action_adapter.rex test_v02_alchemy_adoption.rex
  test_package_identity.rex test_v03_alchemy_adoption.rex test_v04_alchemy_adoption.rex
  test_project_drafts.rex test_project_roundtrip.rex test_source_catalogue_self.rex test_source_catalogue_v031.rex
  test_conditional_resources_flows.rex test_conditional_arbitration_model.rex test_conditional_preview_flow.rex
  test_composition_publish.rex test_composition_move.rex test_composition_resize_relocate.rex test_composition_align.rex test_composition_experiment_preview.rex test_builder_studio_navigation.rex
  test_builder_studio_publish.rex test_project_audit_publish.rex test_project_experiment_publish.rex
)
for t in "${core[@]}"; do echo "=== $t ==="; rexx "$t"; done

echo "=== test_builder_web_shell.sh ==="
"$ROOT/tests/test_builder_web_shell.sh"

echo "=== test_composition_controller.mjs ==="
node "$ROOT/tests/test_composition_controller.mjs"

if [[ -n "${SSC_ROOT:-}" ]]; then
  echo "=== test_semantic_source_control.sh ==="
  "$ROOT/tests/test_semantic_source_control.sh"
fi

if [[ -n "${WIRE_UI_SERVER_SRC:-}" ]]; then
  export PATH="$WIRE_UI_SERVER_SRC:$PATH"
  echo "=== test_builder_application_self_source.rex ==="
  (cd "$ROOT" && rexx tests/test_builder_application_self_source.rex)
  echo "=== test_builder_application_composition.rex ==="
  (cd "$ROOT" && rexx tests/test_builder_application_composition.rex)
  echo "=== test_builder_visual_workspace.rex ==="
  (cd "$ROOT" && rexx tests/test_builder_visual_workspace.rex)
  echo "=== test_source_workspace_v016.rex ==="
  (cd "$ROOT" && rexx tests/test_source_workspace_v016.rex)
  echo "=== test_builder_perspective_editors.rex ==="
  (cd "$ROOT" && rexx tests/test_builder_perspective_editors.rex)
  echo "=== test_flow_conditional_authoring.rex ==="
  (cd "$ROOT" && rexx tests/test_flow_conditional_authoring.rex)
  echo "=== test_conditional_runtime_fail_closed.rex ==="
  (cd "$ROOT" && rexx tests/test_conditional_runtime_fail_closed.rex)
fi

if [[ -n "${WIRE_UI_JS_SRC:-}" ]]; then
  echo "=== test_studio_js.mjs ==="
  WIRE_UI_BUILDER_STUDIO_JSON="$ROOT/studio/wire_ui_builder_studio_v0.11.json" node "$ROOT/tests/test_studio_js.mjs"
fi

if [[ -n "${WUIB_GATEWAY_ROOT:-}" && -n "${WUIB_JS_ROOT:-}" && -n "${WUIB_REXX:-}" && -n "${QUEUE_FABRIC_SRC:-}" && -n "${WIRE_UI_SERVER_SRC:-}" ]]; then
  echo "=== test_live_studio_runtime.mjs ==="
  WUIB_BUILDER_ROOT="$ROOT" node "$ROOT/tests/test_live_studio_runtime.mjs"
fi

if [[ -n "${WUIB_TEST_ROLLUP:-}" && -n "${WUIB_TEST_SERVER_ZIP:-}" && -n "${WUIB_TEST_OOREXX_DEB:-}" ]]; then
  echo "=== test_live_studio_launcher.mjs ==="
  WUIB_BUILDER_ROOT="$ROOT" node "$ROOT/tests/test_live_studio_launcher.mjs"
fi

#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [[ -n "${OOREXX_DEB:-}" ]]; then
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  dpkg-deb -x "$OOREXX_DEB" "$TMP"
  OOREXX_ROOT="$TMP/usr/local"
fi
: "${OOREXX_ROOT:?Set OOREXX_ROOT or OOREXX_DEB}"
REXX="$OOREXX_ROOT/bin/rexx"
REXXC="$OOREXX_ROOT/bin/rexxc"
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

"$REXX" -v | grep -q 'Open Object Rexx Version 5.3.0 r13196'

echo '--- CORE SYNTAX ---'
"$REXXC" "$ROOT/src/GeneralizedComputeIntentions.cls" >/dev/null
echo 'PASS rexxc src/GeneralizedComputeIntentions.cls'
for t in "$ROOT"/tests/test_dynamic_rediscovery.rex "$ROOT"/tests/test_planned_admittance.rex "$ROOT"/tests/test_structured_intention_bridge.rex "$ROOT"/tests/test_dynamic_surface_and_ready_guard.rex "$ROOT"/tests/test_handoff_revalidation_contract.rex; do
  "$REXXC" "$t" >/dev/null
  echo "PASS rexxc tests/$(basename "$t")"
done

echo '--- CORE RUNTIME ---'
cd "$ROOT/tests"
"$REXX" test_dynamic_rediscovery.rex
"$REXX" test_planned_admittance.rex
"$REXX" test_structured_intention_bridge.rex
"$REXX" test_dynamic_surface_and_ready_guard.rex
"$REXX" test_handoff_revalidation_contract.rex


if [[ -n "${INTENTION_SERVICE_ROOT:-}" ]]; then
  INTENTION_SRC="$INTENTION_SERVICE_ROOT/src"
  [[ -f "$INTENTION_SRC/IntentionService.cls" ]] || { echo 'FAIL IntentionService.cls not found'; exit 1; }
  export REXX_PATH="$ROOT/src:$INTENTION_SRC${REXX_PATH:+:$REXX_PATH}"
  echo '--- INTENTION SERVICE SYNTAX ---'
  "$REXXC" "$ROOT/src/GeneralizedComputeIntentionServiceAdapter.cls" >/dev/null
  echo 'PASS rexxc src/GeneralizedComputeIntentionServiceAdapter.cls'
  "$REXXC" "$ROOT/tests/test_intention_service_adapter.rex" >/dev/null
  echo 'PASS rexxc tests/test_intention_service_adapter.rex'
  echo '--- INTENTION SERVICE RUNTIME ---'
  "$REXX" test_intention_service_adapter.rex
else
  echo 'SKIP Intention Service integration (set INTENTION_SERVICE_ROOT)'
fi

if [[ -n "${INSTRUMENTATION_MESH_ROOT:-}" ]]; then
  MESH_SRC="$INSTRUMENTATION_MESH_ROOT/src"
  [[ -f "$MESH_SRC/InstrumentationMesh.cls" ]] || { echo 'FAIL InstrumentationMesh.cls not found'; exit 1; }
  export REXX_PATH="$ROOT/src:$MESH_SRC${REXX_PATH:+:$REXX_PATH}"
  echo '--- INSTRUMENTATION SYNTAX ---'
  "$REXXC" "$ROOT/src/GeneralizedComputeInstrumentation.cls" >/dev/null
  echo 'PASS rexxc src/GeneralizedComputeInstrumentation.cls'
  "$REXXC" "$ROOT/tests/test_instrumentation_mesh_adapter.rex" >/dev/null
  echo 'PASS rexxc tests/test_instrumentation_mesh_adapter.rex'
  "$REXXC" "$ROOT/tests/test_mesh_dev7_freshness_events.rex" >/dev/null
  echo 'PASS rexxc tests/test_mesh_dev7_freshness_events.rex'
  echo '--- INSTRUMENTATION RUNTIME ---'
  "$REXX" test_instrumentation_mesh_adapter.rex
  "$REXX" test_mesh_dev7_freshness_events.rex
else
  echo 'SKIP Instrumentation Mesh integration (set INSTRUMENTATION_MESH_ROOT)'
fi

echo 'PASS ooRexx Generalized Compute Intentions v0.1-dev5 environment qualification'

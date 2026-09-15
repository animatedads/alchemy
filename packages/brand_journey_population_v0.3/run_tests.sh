#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
BRAND_JOURNEY_ROOT="${BRAND_JOURNEY_ROOT:-}"
BRAND_INTERACTION_EFFECT_ROOT="${BRAND_INTERACTION_EFFECT_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
PATHS="$ROOT/tests:$ROOT/src:$ROOT/integration:$ROOT/runtime"
if [[ -n "$ALCHEMY_OBJECTS_ROOT" ]]; then PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"; fi
if [[ -n "$OOREXX_CRYPTO_ROOT" ]]; then PATHS="$PATHS:$OOREXX_CRYPTO_ROOT/src"; fi
if [[ -n "$BRAND_JOURNEY_ROOT" ]]; then PATHS="$PATHS:$BRAND_JOURNEY_ROOT/src"; fi
if [[ -n "$BRAND_INTERACTION_EFFECT_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERACTION_EFFECT_ROOT/src"; fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run(){ echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run large-aggregate-reasoning "$ROOT/tests/test_large_aggregate_reasoning.rex"
run recovery-modifier "$ROOT/tests/test_recovery_modifier.rex"
run material-small-sample "$ROOT/tests/test_material_small_sample.rex"
run outcome-window "$ROOT/tests/test_outcome_window.rex"
run partial-bucket-fails-closed "$ROOT/tests/test_partial_bucket_fails_closed.rex"
run temporal-release-signal "$ROOT/tests/test_temporal_release_signal.rex"
run cohort-provenance-selection "$ROOT/tests/test_cohort_provenance_selection.rex"
run v06-cohort-provenance "$ROOT/tests/test_v06_cohort_provenance.rex"
run missing-comparison-insufficient "$ROOT/tests/test_missing_comparison_insufficient.rex"
run v06-confidence-reasoning "$ROOT/tests/test_v06_confidence_reasoning.rex"
run dual-provenance-ownership "$ROOT/tests/test_dual_provenance_ownership.rex"
run default-upstream-provenance-limitations "$ROOT/tests/test_default_upstream_provenance_limitations.rex"
run journey-bridge-privacy-sales-boundary "$ROOT/tests/test_journey_bridge_privacy_and_sales_boundary.rex"
run alchemy-privacy "$ROOT/tests/test_alchemy_privacy.rex"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "BRAND JOURNEY POPULATION V0.3 ALL REQUESTED TESTS: OK"

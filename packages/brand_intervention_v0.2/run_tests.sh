#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
BRAND_INTERACTION_EFFECT_ROOT="${BRAND_INTERACTION_EFFECT_ROOT:-}"
BRAND_JOURNEY_ROOT="${BRAND_JOURNEY_ROOT:-}"
BRAND_JOURNEY_POPULATION_ROOT="${BRAND_JOURNEY_POPULATION_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
PATHS="$ROOT/tests:$ROOT/src:$ROOT/integration:$ROOT/runtime"
if [[ -n "$ALCHEMY_OBJECTS_ROOT" ]]; then PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"; fi
if [[ -n "$OOREXX_CRYPTO_ROOT" ]]; then PATHS="$PATHS:$OOREXX_CRYPTO_ROOT/src"; fi
if [[ -n "$BRAND_INTERACTION_EFFECT_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERACTION_EFFECT_ROOT/src"; fi
if [[ -n "$BRAND_JOURNEY_ROOT" ]]; then PATHS="$PATHS:$BRAND_JOURNEY_ROOT/src"; fi
if [[ -n "$BRAND_JOURNEY_POPULATION_ROOT" ]]; then PATHS="$PATHS:$BRAND_JOURNEY_POPULATION_ROOT/src"; fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run(){ echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run supported-context-loss-guidance "$ROOT/tests/test_supported_context_loss_guidance.rex"
run material-signal-review-only "$ROOT/tests/test_material_signal_review_only.rex"
run insufficient-baseline-only "$ROOT/tests/test_insufficient_baseline_only.rex"
run sass-not-hysterical-apology "$ROOT/tests/test_sass_not_hysterical_apology.rex"
run stale-evidence-review "$ROOT/tests/test_stale_evidence_review.rex"
run temporal-evidence-to-intervention "$ROOT/tests/test_temporal_evidence_survives_to_intervention.rex"
run journey-bridge-privacy-brand-boundary "$ROOT/tests/test_journey_bridge_privacy_and_brand_boundary.rex"
run outcome-measurement-association-only "$ROOT/tests/test_outcome_measurement_association_only.rex"
run cohort-quality-review "$ROOT/tests/test_cohort_quality_review.rex"
run confidence-weak-observe-only "$ROOT/tests/test_confidence_weak_observe_only.rex"
run alchemy-privacy "$ROOT/tests/test_alchemy_privacy.rex"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"; else echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"; fi
echo "BRAND INTERVENTION V0.2 ALL REQUESTED TESTS: OK"

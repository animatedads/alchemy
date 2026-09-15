#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
BRAND_INTERACTION_EFFECT_ROOT="${BRAND_INTERACTION_EFFECT_ROOT:-}"
BRAND_JOURNEY_ROOT="${BRAND_JOURNEY_ROOT:-}"
BRAND_JOURNEY_POPULATION_ROOT="${BRAND_JOURNEY_POPULATION_ROOT:-}"
BRAND_INTERVENTION_ROOT="${BRAND_INTERVENTION_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
PATHS="$ROOT/tests:$ROOT/src:$ROOT/integration:$ROOT/runtime"
if [[ -n "$ALCHEMY_OBJECTS_ROOT" ]]; then PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"; fi
if [[ -n "$OOREXX_CRYPTO_ROOT" ]]; then PATHS="$PATHS:$OOREXX_CRYPTO_ROOT/src"; fi
if [[ -n "$BRAND_INTERACTION_EFFECT_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERACTION_EFFECT_ROOT/src"; fi
if [[ -n "$BRAND_JOURNEY_ROOT" ]]; then PATHS="$PATHS:$BRAND_JOURNEY_ROOT/src"; fi
if [[ -n "$BRAND_JOURNEY_POPULATION_ROOT" ]]; then PATHS="$PATHS:$BRAND_JOURNEY_POPULATION_ROOT/src"; fi
if [[ -n "$BRAND_INTERVENTION_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERVENTION_ROOT/src:$BRAND_INTERVENTION_ROOT/integration"; fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run(){ echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run primary-benefit "$ROOT/tests/test_primary_benefit_association.rex"
run confidence-overlap "$ROOT/tests/test_confidence_overlap_not_promising.rex"
run confidence-gate-optional "$ROOT/tests/test_confidence_gate_optional.rex"
run mixed-effects "$ROOT/tests/test_multi_outcome_mixed_effects.rex"
run guardrail-review "$ROOT/tests/test_guardrail_insufficient_forces_review.rex"
run randomized-not-self-causal "$ROOT/tests/test_randomized_still_not_self_causal.rex"
run temporal-release "$ROOT/tests/test_temporal_release_effectiveness.rex"
run outcome-bridge "$ROOT/tests/test_outcome_bridge_eligibility.rex"
run evidence-point-privacy "$ROOT/tests/test_evidence_point_privacy.rex"
run alchemy-privacy "$ROOT/tests/test_alchemy_privacy.rex"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"; else echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"; fi
echo "BRAND INTERVENTION EFFECTIVENESS V0.2 ALL REQUESTED TESTS: OK"

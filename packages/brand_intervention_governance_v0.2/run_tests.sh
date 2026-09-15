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
BRAND_INTERVENTION_EFFECTIVENESS_ROOT="${BRAND_INTERVENTION_EFFECTIVENESS_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
INSTITUTIONAL_POLICY_ROOT="${INSTITUTIONAL_POLICY_ROOT:-}"
PATHS="$ROOT/tests:$ROOT/src:$ROOT/integration:$ROOT/runtime"
if [[ -n "$ALCHEMY_OBJECTS_ROOT" ]]; then PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"; fi
if [[ -n "$OOREXX_CRYPTO_ROOT" ]]; then PATHS="$PATHS:$OOREXX_CRYPTO_ROOT/src"; fi
if [[ -n "$BRAND_INTERACTION_EFFECT_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERACTION_EFFECT_ROOT/src"; fi
if [[ -n "$BRAND_JOURNEY_ROOT" ]]; then PATHS="$PATHS:$BRAND_JOURNEY_ROOT/src:$BRAND_JOURNEY_ROOT/integration"; fi
if [[ -n "$BRAND_JOURNEY_POPULATION_ROOT" ]]; then PATHS="$PATHS:$BRAND_JOURNEY_POPULATION_ROOT/src:$BRAND_JOURNEY_POPULATION_ROOT/integration"; fi
if [[ -n "$BRAND_INTERVENTION_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERVENTION_ROOT/src:$BRAND_INTERVENTION_ROOT/integration"; fi
if [[ -n "$BRAND_INTERVENTION_EFFECTIVENESS_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERVENTION_EFFECTIVENESS_ROOT/src:$BRAND_INTERVENTION_EFFECTIVENESS_ROOT/integration"; fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
if [[ -n "$INSTITUTIONAL_POLICY_ROOT" ]]; then PATHS="$PATHS:$INSTITUTIONAL_POLICY_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run(){ echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run rule-set-required "$ROOT/tests/test_rule_set_required.rex"
run institutional-policy-selection "$ROOT/tests/test_institutional_policy_selection.rex"
run institutional-policy-not-effective "$ROOT/tests/test_institutional_policy_not_effective.rex"
run unmanaged-positive-decision "$ROOT/tests/test_unmanaged_positive_decision_blocked.rex"
run promising-controlled-review "$ROOT/tests/test_promising_requires_controlled_review.rex"
run mixed-guardrail "$ROOT/tests/test_mixed_guardrail_forces_withdrawal_review.rex"
run insufficient "$ROOT/tests/test_insufficient_measures_more.rex"
run stale "$ROOT/tests/test_stale_evidence_forces_review.rex"
run temporal-regression "$ROOT/tests/test_temporal_regression_review.rex"
run temporal-expansion "$ROOT/tests/test_temporal_expansion_and_continue.rex"
run guardrails-required "$ROOT/tests/test_guardrails_required.rex"
run randomized-authority "$ROOT/tests/test_randomized_still_external_authority.rex"
run named-authority "$ROOT/tests/test_named_authority_and_override_evidence.rex"
run authority-scope "$ROOT/tests/test_authority_scope.rex"
run decision-ref-privacy "$ROOT/tests/test_decision_ref_privacy.rex"
run alchemy-privacy "$ROOT/tests/test_alchemy_privacy.rex"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"; else echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"; fi
echo "BRAND INTERVENTION GOVERNANCE V0.2 ALL REQUESTED TESTS: OK"

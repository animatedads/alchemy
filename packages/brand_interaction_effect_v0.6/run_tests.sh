#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
INTERACTION_EVENT_ROOT="${INTERACTION_EVENT_ROOT:-}"
STRUCTURED_UTTERANCE_ROOT="${STRUCTURED_UTTERANCE_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
if [[ -z "$ALCHEMY_OBJECTS_ROOT" || -z "$OOREXX_CRYPTO_ROOT" ]]; then
  echo "error: Brand Interaction Effect v0.6 requires ALCHEMY_OBJECTS_ROOT and OOREXX_CRYPTO_ROOT" >&2
  exit 2
fi
PATHS="$ROOT/tests:$ROOT/src:$ROOT/runtime:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src"
if [[ -n "$INTERACTION_EVENT_ROOT" ]]; then PATHS="$PATHS:$INTERACTION_EVENT_ROOT/src:$INTERACTION_EVENT_ROOT/runtime"; fi
if [[ -n "$STRUCTURED_UTTERANCE_ROOT" ]]; then PATHS="$PATHS:$STRUCTURED_UTTERANCE_ROOT/src:$STRUCTURED_UTTERANCE_ROOT/runtime"; fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run() { echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run service-as-sales "$ROOT/tests/test_service_as_sales.rex"
run sass-commercial-exit "$ROOT/tests/test_sass_commercial_exit.rex"
run security-sales-collision "$ROOT/tests/test_security_sales_collision.rex"
run recovery "$ROOT/tests/test_recovery.rex"
run causal-authority "$ROOT/tests/test_causal_authority.rex"
run named-causal-authority "$ROOT/tests/test_named_causal_authority.rex"
run sass-not-cancel-rule "$ROOT/tests/test_sass_not_cancel_rule.rex"
run evidence-reasoning-packet "$ROOT/tests/test_evidence_reasoning_packet.rex"
run evidence-confidence-bounds "$ROOT/tests/test_evidence_confidence_bounds.rex"
run evidence-confidence-guard "$ROOT/tests/test_evidence_confidence_guard.rex"
run evidence-cohort-accumulator "$ROOT/tests/test_evidence_cohort_accumulator.rex"
run evidence-cohort-provenance "$ROOT/tests/test_evidence_cohort_provenance.rex"
run evidence-selection-quality-guard "$ROOT/tests/test_evidence_selection_quality_guard.rex"
run evidence-sampling-not-moralized "$ROOT/tests/test_evidence_sampling_not_moralized.rex"
run evidence-insufficient-materiality "$ROOT/tests/test_evidence_insufficient_materiality.rex"
run temporal-evidence "$ROOT/tests/test_temporal_evidence.rex"
if [[ -n "$INTERACTION_EVENT_ROOT" ]]; then
  run interaction-bridge-privacy "$ROOT/tests/test_interaction_bridge_privacy.rex" "$INTERACTION_EVENT_ROOT"
  run bridge-unknown-privacy "$ROOT/tests/test_bridge_unknown_privacy.rex" "$INTERACTION_EVENT_ROOT"
  run assessment-lineage "$ROOT/tests/test_assessment_lineage.rex" "$INTERACTION_EVENT_ROOT"
  run native-structured-evidence-authority "$ROOT/tests/test_native_structured_evidence_authority.rex"
else
  echo "SKIP interaction bridge tests (set INTERACTION_EVENT_ROOT)"
fi
if [[ -n "$INTERACTION_EVENT_ROOT" && -n "$STRUCTURED_UTTERANCE_ROOT" ]]; then
  run structured-shannon-end-to-end "$ROOT/tests/test_structured_shannon_end_to_end.rex"
  run sensitive-information-commercial-repurposing "$ROOT/tests/test_sensitive_information_commercial_repurposing.rex"
else
  echo "SKIP structured tests (set INTERACTION_EVENT_ROOT and STRUCTURED_UTTERANCE_ROOT)"
fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "BRAND INTERACTION EFFECT V0.6 ALL REQUESTED TESTS: OK"

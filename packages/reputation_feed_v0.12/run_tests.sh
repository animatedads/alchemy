#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.8 package root}"
: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT to oorexx_crypto_v0.1 package root}"
[[ -f "$ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" ]] || { echo "missing $ALCHEMY_OBJECTS_ROOT/src/AlchemyObject.cls" >&2; exit 2; }
[[ -f "$OOREXX_CRYPTO_ROOT/src/crypto.cls" ]] || { echo "missing $OOREXX_CRYPTO_ROOT/src/crypto.cls" >&2; exit 2; }
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
REPUTATION_EFFECT_ROOT="${REPUTATION_EFFECT_ROOT:-}"
QUEUE_FABRIC_ROOT="${QUEUE_FABRIC_ROOT:-}"
INTERACTION_EVENT_ROOT="${INTERACTION_EVENT_ROOT:-}"
STRUCTURED_UTTERANCE_ROOT="${STRUCTURED_UTTERANCE_ROOT:-}"
INSTITUTIONAL_POLICY_ROOT="${INSTITUTIONAL_POLICY_ROOT:-}"
OOREXX_LOGGING_ROOT="${OOREXX_LOGGING_ROOT:-}"
REXX_INPUT="${OOREXX_REXX:-${REXX:-rexx}}"
case "$REXX_INPUT" in *[[:space:]]*) echo "REXX must name one executable" >&2; exit 2;; esac
if [[ -x "$REXX_INPUT" && "${REXX_INPUT#/}" != "$REXX_INPUT" ]]; then REXX_BIN="$REXX_INPUT"
elif command -v "$REXX_INPUT" >/dev/null 2>&1; then REXX_BIN="$(command -v "$REXX_INPUT")"
else echo "ooRexx interpreter not found: $REXX_INPUT" >&2; exit 2; fi
cleanup_test_artifacts(){ rm -rf "$ROOT"/tmp_reputation_feed_queue_* "$ROOT"/tests/tmp_reputation_feed_queue_* "$ROOT"/tmp_rep_queue_demo_* "$ROOT"/examples/tmp_rep_queue_demo_* ./tmp_reputation_feed_queue_* ./tmp_rep_queue_demo_* 2>/dev/null || true; }
trap cleanup_test_artifacts EXIT
cleanup_test_artifacts
export PATH="$(dirname "$REXX_BIN"):$ROOT/tests:$ROOT/src:$ROOT/runtime:$ROOT/integration:${PATH}"
export REXX_PATH="$ROOT/tests:$ROOT/src:$ROOT/runtime:$ROOT/integration:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src${REXX_PATH:+:$REXX_PATH}"
run(){ echo "== $1 =="; shift; "$REXX_BIN" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run alchemy-inheritance "$ROOT/tests/test_reputation_feed_alchemy_inheritance.rex" "$ROOT"
run alchemy-base "$ROOT/tests/test_reputation_feed_alchemy_base.rex"
run event-alchemy-base "$ROOT/tests/test_reputation_feed_event_alchemy_base.rex"
run acquisition-alchemy-base "$ROOT/tests/test_acquisition_alchemy_base.rex"
run acquisition-adapters "$ROOT/tests/test_acquisition_adapter_diversity.rex"
run source-authentication "$ROOT/tests/test_source_authentication.rex"
run source-history-replay "$ROOT/tests/test_source_history_replay.rex"
run source-auth-claim-bridge "$ROOT/tests/test_source_auth_claim_bridge.rex"
run source-history-corroboration "$ROOT/tests/test_source_history_corroboration_bridge.rex"
run alchemy-v08-adoption "$ROOT/tests/test_alchemy_v08_adoption.rex"
run librarian-claim-bridge "$ROOT/tests/test_librarian_claim_bridge.rex"
run librarian-assertion-ancestry "$ROOT/tests/test_librarian_assertion_ancestry_bridge.rex"
run librarian-lineage "$ROOT/tests/test_librarian_paragraph_lineage.rex"
run reach-range-lineage "$ROOT/tests/test_reach_range_lineage_separation.rex"
run transitive-lineage "$ROOT/tests/test_lineage_transitive_group.rex"
run branching-lineage "$ROOT/tests/test_lineage_branching_group.rex"
run provenance-corroboration "$ROOT/tests/test_provenance_aware_corroboration.rex"
run assertion-ancestry-corroboration "$ROOT/tests/test_assertion_ancestry_corroboration.rex"
run interaction-assertion-root-dedup "$ROOT/tests/test_interaction_assertion_root_dedup.rex"
run event-corroboration "$ROOT/tests/test_event_corroboration_lineage_threshold.rex"
run correction-replay "$ROOT/tests/test_event_contested_correction_replay.rex"
run watch-salience "$ROOT/tests/test_watchset_geographic_salience.rex"
if [[ -n "$INTERACTION_EVENT_ROOT" ]]; then
  [[ -f "$INTERACTION_EVENT_ROOT/src/InteractionEvent.cls" ]] || { echo "invalid INTERACTION_EVENT_ROOT: $INTERACTION_EVENT_ROOT" >&2; exit 2; }
  export PATH="$INTERACTION_EVENT_ROOT/src:$ROOT/integration:$PATH"
  export REXX_PATH="$INTERACTION_EVENT_ROOT/src:$ROOT/integration:$REXX_PATH"
  run interaction-event-acquisition "$ROOT/tests/test_interaction_event_acquisition_bridge.rex"
else
  echo "SKIP interaction-event-acquisition (set INTERACTION_EVENT_ROOT)"
fi

if [[ -n "$STRUCTURED_UTTERANCE_ROOT" ]]; then
  [[ -f "$STRUCTURED_UTTERANCE_ROOT/src/StructuredUtterance.cls" ]] || { echo "invalid STRUCTURED_UTTERANCE_ROOT: $STRUCTURED_UTTERANCE_ROOT" >&2; exit 2; }
  export PATH="$STRUCTURED_UTTERANCE_ROOT/src:$ROOT/integration:$PATH"
  export REXX_PATH="$STRUCTURED_UTTERANCE_ROOT/src:$ROOT/integration:$REXX_PATH"
  run structured-utterance-acquisition "$ROOT/tests/test_structured_utterance_acquisition_bridge.rex"
else
  echo "SKIP structured-utterance-acquisition (set STRUCTURED_UTTERANCE_ROOT)"
fi

if [[ -n "$INTERACTION_EVENT_ROOT" && -n "$STRUCTURED_UTTERANCE_ROOT" ]]; then
  run interaction-alchemy-v08-adoption "$ROOT/tests/test_interaction_alchemy_v08_adoption.rex"
fi

if [[ -n "$REPUTATION_EFFECT_ROOT" ]]; then
  [[ -f "$REPUTATION_EFFECT_ROOT/src/ReputationEffect.cls" ]] || { echo "invalid REPUTATION_EFFECT_ROOT: $REPUTATION_EFFECT_ROOT" >&2; exit 2; }
  export PATH="$REPUTATION_EFFECT_ROOT/src:$REPUTATION_EFFECT_ROOT/integration:$ROOT/integration:$PATH"
  export REXX_PATH="$REPUTATION_EFFECT_ROOT/src:$REPUTATION_EFFECT_ROOT/integration:$ROOT/integration:$REXX_PATH"
  run effect-bridge "$ROOT/tests/test_effect_bridge.rex"
  run hypothesis-effect-bridge "$ROOT/tests/test_hypothesis_effect_observation_bridge.rex"
else
  echo "SKIP effect-bridge (set REPUTATION_EFFECT_ROOT)"
fi

if [[ -n "$QUEUE_FABRIC_ROOT" ]]; then
  [[ -f "$QUEUE_FABRIC_ROOT/src/ObjectQueueTopics.cls" ]] || { echo "invalid QUEUE_FABRIC_ROOT: $QUEUE_FABRIC_ROOT" >&2; exit 2; }
  export PATH="$QUEUE_FABRIC_ROOT/src:$ROOT/integration:$PATH"
  export REXX_PATH="$QUEUE_FABRIC_ROOT/src:$ROOT/integration:$REXX_PATH"
  run queue-fabric-bridge "$ROOT/tests/test_queue_fabric_bridge.rex"
  run queue-persistence-codec "$ROOT/tests/test_queue_persistence_codec.rex"
  run queue-fabric-persistence "$ROOT/tests/test_queue_fabric_persistence.rex"
else
  echo "SKIP queue-fabric-bridge (set QUEUE_FABRIC_ROOT)"
fi

if [[ -n "$INSTITUTIONAL_POLICY_ROOT" ]]; then
  [[ -f "$INSTITUTIONAL_POLICY_ROOT/src/InstitutionalPolicy.cls" ]] || { echo "invalid INSTITUTIONAL_POLICY_ROOT: $INSTITUTIONAL_POLICY_ROOT" >&2; exit 2; }
  export PATH="$INSTITUTIONAL_POLICY_ROOT/src:$ROOT/integration:$PATH"
  export REXX_PATH="$INSTITUTIONAL_POLICY_ROOT/src:$ROOT/integration:$REXX_PATH"
  run institutional-policy-governance "$ROOT/tests/test_institutional_policy_governance.rex"
  run institutional-policy-deployment-topology "$ROOT/tests/test_institutional_policy_deployment_topology.rex"
  run institutional-policy-progressive-rollout "$ROOT/tests/test_institutional_policy_progressive_rollout.rex"
  run governed-decision-trace "$ROOT/tests/test_governed_decision_trace.rex"
else
  echo "SKIP institutional-policy-governance (set INSTITUTIONAL_POLICY_ROOT)"
fi

if [[ -n "$OOREXX_LOGGING_ROOT" ]]; then
  [[ -f "$OOREXX_LOGGING_ROOT/src/LoggingCore.cls" ]] || { echo "invalid OOREXX_LOGGING_ROOT: $OOREXX_LOGGING_ROOT" >&2; exit 2; }
  export PATH="$OOREXX_LOGGING_ROOT/src:$ROOT/integration:$PATH"
  export REXX_PATH="$OOREXX_LOGGING_ROOT/src:$ROOT/integration:$REXX_PATH"
  run logging-decision-trace "$ROOT/tests/test_logging_decision_trace_bridge.rex"
else
  echo "SKIP logging-decision-trace (set OOREXX_LOGGING_ROOT)"
fi
if [[ -n "$INSTITUTIONAL_POLICY_ROOT" && -n "$REPUTATION_EFFECT_ROOT" ]]; then
  run governed-effect-bridge "$ROOT/tests/test_governed_effect_bridge.rex"
  run governed-effect-deployment "$ROOT/tests/test_governed_effect_deployment_evidence.rex"
else
  echo "SKIP governed-effect-bridge (set INSTITUTIONAL_POLICY_ROOT and REPUTATION_EFFECT_ROOT)"
fi

if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  [[ -f "$RUNTIME_REGISTRY_ROOT/src/RuntimeRegistry.cls" ]] || { echo "invalid RUNTIME_REGISTRY_ROOT: $RUNTIME_REGISTRY_ROOT" >&2; exit 2; }
  export PATH="$RUNTIME_REGISTRY_ROOT/src:$PATH"
  export REXX_PATH="$RUNTIME_REGISTRY_ROOT/src:$REXX_PATH"
  run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "REPUTATION FEED V0.12 ALL REQUESTED TESTS: OK"

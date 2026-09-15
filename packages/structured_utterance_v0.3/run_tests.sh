#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
INTERACTION_EVENT_ROOT="${INTERACTION_EVENT_ROOT:-}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
if [[ -z "$ALCHEMY_OBJECTS_ROOT" || -z "$OOREXX_CRYPTO_ROOT" ]]; then
  echo "error: Structured Utterance v0.3 requires ALCHEMY_OBJECTS_ROOT and OOREXX_CRYPTO_ROOT" >&2
  exit 2
fi
PATHS="$ROOT/tests:$ROOT/src:$ROOT/runtime:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src"
if [[ -n "$INTERACTION_EVENT_ROOT" ]]; then PATHS="$PATHS:$INTERACTION_EVENT_ROOT/src:$INTERACTION_EVENT_ROOT/runtime"; fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run() { echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run shannon-baggage-markup "$ROOT/tests/test_shannon_baggage_markup.rex"
run lineage-privacy "$ROOT/tests/test_lineage_privacy.rex"
run sealed-context-immutability "$ROOT/tests/test_sealed_context_immutability.rex"
run service-as-sales "$ROOT/tests/test_service_as_sales.rex"
run points "$ROOT/tests/test_points.rex"
run generation-intent-evidence "$ROOT/tests/test_generation_intent_evidence.rex"
run information-use-integrity "$ROOT/tests/test_information_use_integrity.rex"
run cross-act-information-use "$ROOT/tests/test_cross_act_information_use.rex"
run sensitive-commercial-repurposing "$ROOT/tests/test_sensitive_commercial_repurposing.rex"
if [[ -n "$INTERACTION_EVENT_ROOT" ]]; then
  run interaction-bridge "$ROOT/tests/test_interaction_bridge.rex"
  run interaction-bridge-v02 "$ROOT/tests/test_interaction_bridge_v02.rex"
  run interaction-bridge-v03 "$ROOT/tests/test_interaction_bridge_v03.rex"
  run interaction-bridge-identity-contract "$ROOT/tests/test_interaction_bridge_identity_contract.rex"
else
  echo "SKIP interaction bridges (set INTERACTION_EVENT_ROOT)"
fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "STRUCTURED UTTERANCE V0.3 ALL REQUESTED TESTS: OK"

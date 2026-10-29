#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
STRUCTURED_UTTERANCE_ROOT="${STRUCTURED_UTTERANCE_ROOT:-}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
INTERACTION_EVENT_ROOT="${INTERACTION_EVENT_ROOT:-}"
if [[ -z "$STRUCTURED_UTTERANCE_ROOT" || -z "$ALCHEMY_OBJECTS_ROOT" || -z "$OOREXX_CRYPTO_ROOT" ]]; then
  echo "error: set STRUCTURED_UTTERANCE_ROOT, ALCHEMY_OBJECTS_ROOT and OOREXX_CRYPTO_ROOT" >&2
  exit 2
fi
PATHS="$ROOT/tests:$ROOT/src:$ROOT/runtime:$STRUCTURED_UTTERANCE_ROOT/src:$STRUCTURED_UTTERANCE_ROOT/runtime:$ALCHEMY_OBJECTS_ROOT/src:$OOREXX_CRYPTO_ROOT/src"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
if [[ -n "$INTERACTION_EVENT_ROOT" ]]; then PATHS="$PATHS:$INTERACTION_EVENT_ROOT/src:$INTERACTION_EVENT_ROOT/runtime"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run(){ echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run flattened-fail-closed "$ROOT/tests/test_flattened_reply_fails_closed.rex"
run sensitive-cross-act "$ROOT/tests/test_sensitive_cross_act_production.rex"
run customer-reference-lineage "$ROOT/tests/test_customer_reference_lineage.rex"
run controlled-provenance "$ROOT/tests/test_controlled_provenance_refs.rex"
run invalid-structure "$ROOT/tests/test_invalid_structure_rejected.rex"
run brand-context-boundary "$ROOT/tests/test_brand_context_not_sales_authority.rex"
if [[ -n "$INTERACTION_EVENT_ROOT" ]]; then
  run interaction-event-handoff "$ROOT/tests/test_interaction_event_handoff.rex"
else
  echo "SKIP interaction-event-handoff (set INTERACTION_EVENT_ROOT)"
fi
run alchemy-boundary "$ROOT/tests/test_alchemy_boundary.rex"
run structured-response-payload-boundary "$ROOT/tests/test_structured_response_payload_boundary.rex"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "STRUCTURED UTTERANCE PRODUCER V0.2-DEV1 ALL REQUESTED TESTS: OK"

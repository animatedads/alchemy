#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
STRUCTURED_RELATION_ROOT="${STRUCTURED_RELATION_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
HARDWORLD_ROOT="${HARDWORLD_ROOT:-}"
CRYPTO_INPUT="${CRYPTO_SRC:-${OOREXX_CRYPTO_SRC:-}}"
ALCHEMY_INPUT="${ALCHEMY_OBJECTS_ROOT:-${ALCHEMY_OBJECTS_SRC:-}}"

if [[ -z "$CRYPTO_INPUT" ]]; then
  echo "set CRYPTO_SRC to oorexx_crypto_v0.1/src (Legal Effect v0.11 and Alchemy Objects require standalone crypto)" >&2
  exit 2
fi
if [[ -f "$CRYPTO_INPUT" ]]; then
  [[ "$(basename "$CRYPTO_INPUT")" == "crypto.cls" ]] || { echo "CRYPTO_SRC file must be crypto.cls" >&2; exit 2; }
  CRYPTO_SRC="$(cd "$(dirname "$CRYPTO_INPUT")" && pwd)"
elif [[ -d "$CRYPTO_INPUT" ]]; then
  if [[ -f "$CRYPTO_INPUT/crypto.cls" ]]; then CRYPTO_SRC="$(cd "$CRYPTO_INPUT" && pwd)"
  elif [[ -f "$CRYPTO_INPUT/src/crypto.cls" ]]; then CRYPTO_SRC="$(cd "$CRYPTO_INPUT/src" && pwd)"
  else echo "crypto.cls not found below CRYPTO_SRC=$CRYPTO_INPUT" >&2; exit 2; fi
else
  echo "invalid CRYPTO_SRC=$CRYPTO_INPUT" >&2
  exit 2
fi

if [[ -z "$ALCHEMY_INPUT" ]]; then
  echo "set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.4.3 package root or src directory" >&2
  exit 2
fi
if [[ -f "$ALCHEMY_INPUT" ]]; then
  [[ "$(basename "$ALCHEMY_INPUT")" == "AlchemyObject.cls" ]] || { echo "ALCHEMY_OBJECTS_ROOT file must be AlchemyObject.cls" >&2; exit 2; }
  ALCHEMY_OBJECTS_SRC="$(cd "$(dirname "$ALCHEMY_INPUT")" && pwd)"
elif [[ -d "$ALCHEMY_INPUT" ]]; then
  if [[ -f "$ALCHEMY_INPUT/AlchemyObject.cls" ]]; then ALCHEMY_OBJECTS_SRC="$(cd "$ALCHEMY_INPUT" && pwd)"
  elif [[ -f "$ALCHEMY_INPUT/src/AlchemyObject.cls" ]]; then ALCHEMY_OBJECTS_SRC="$(cd "$ALCHEMY_INPUT/src" && pwd)"
  else echo "AlchemyObject.cls not found below ALCHEMY_OBJECTS_ROOT=$ALCHEMY_INPUT" >&2; exit 2; fi
else
  echo "invalid ALCHEMY_OBJECTS_ROOT=$ALCHEMY_INPUT" >&2
  exit 2
fi
export ALCHEMY_OBJECTS_SRC
export CRYPTO_SRC

export PATH="$ROOT/tests:$ROOT/src:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC:${PATH}"
export REXX_PATH="$ROOT/tests:$ROOT/src:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  export PATH="$RUNTIME_REGISTRY_ROOT/src:$PATH"
  export REXX_PATH="$RUNTIME_REGISTRY_ROOT/src${REXX_PATH:+:$REXX_PATH}"
fi
if [[ -n "$STRUCTURED_RELATION_ROOT" ]]; then
  export PATH="$STRUCTURED_RELATION_ROOT/src:$PATH"
  export REXX_PATH="$STRUCTURED_RELATION_ROOT/src${REXX_PATH:+:$REXX_PATH}"
fi

run() {
  echo "== $1 =="
  shift
  "$REXX" "$@"
}

run core "$ROOT/tests/test_legal_effect_core.rex"
run temporal-jurisdiction "$ROOT/tests/test_temporal_jurisdiction.rex"
run modification-effects "$ROOT/tests/test_modification_effects.rex"
run rule-sealing "$ROOT/tests/test_rule_sealing.rex"
run semantic-identity "$ROOT/tests/test_semantic_identity.rex"
run authority-conflicts "$ROOT/tests/test_authority_conflicts.rex"
run decision-trace "$ROOT/tests/test_decision_trace.rex"
run decision-trace-query "$ROOT/tests/test_decision_trace_query.rex"
run counterfactual-evaluation "$ROOT/tests/test_counterfactual_evaluation.rex"
run conflict-of-laws "$ROOT/tests/test_conflict_of_laws.rex"
run compiler-boundary "$ROOT/tests/test_compiler_boundary.rex"
run compiler-semantic-kinds "$ROOT/tests/test_compiler_semantic_kinds.rex"
run source-verification "$ROOT/tests/test_source_verification.rex"
run compilation-snapshot-atomicity "$ROOT/tests/test_compilation_snapshot_atomicity.rex"
run source-authority-attestation "$ROOT/tests/test_source_authority_attestation.rex"
run source-authority-ed25519 "$ROOT/tests/test_source_authority_ed25519.rex"
run alchemy-object-integration "$ROOT/tests/test_alchemy_object_integration.rex"

if [[ -n "$STRUCTURED_RELATION_ROOT" ]]; then
  PATH="$STRUCTURED_RELATION_ROOT/src:$PATH" run structured-relation "$ROOT/tests/test_structured_relation_bridge.rex"
  PATH="$STRUCTURED_RELATION_ROOT/src:$PATH" run structured-source-verification "$ROOT/tests/test_structured_source_verification.rex" "$STRUCTURED_RELATION_ROOT"
else
  echo "SKIP structured-relation gates (set STRUCTURED_RELATION_ROOT)"
fi

if [[ -n "$HARDWORLD_ROOT" ]]; then
  PATH="$HARDWORLD_ROOT:$PATH" run hardworld "$ROOT/tests/test_hardworld_bridge.rex"
else
  echo "SKIP HardWorld bridge (set HARDWORLD_ROOT)"
fi

if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  PATH="$RUNTIME_REGISTRY_ROOT/src:$PATH" run runtime-registry "$ROOT/tests/test_runtime_registry_bridge.rex" "$ROOT"
  if [[ -f "$RUNTIME_REGISTRY_ROOT/src/RuntimeBundleBuilder.cls" ]]; then
    PATH="$RUNTIME_REGISTRY_ROOT/src:$PATH" run runtime-registry-bundle "$ROOT/tests/test_runtime_registry_v08_bundle.rex" "$ROOT"
  else
    echo "SKIP Runtime Registry bundle bridge (RuntimeBundleBuilder.cls not present)"
  fi
else
  echo "SKIP Runtime Registry bridge (set RUNTIME_REGISTRY_ROOT)"
fi

if [[ -n "$RUNTIME_REGISTRY_ROOT" && -n "$STRUCTURED_RELATION_ROOT" ]]; then
  PATH="$RUNTIME_REGISTRY_ROOT/src:$STRUCTURED_RELATION_ROOT/src:$PATH" run runtime-evidence-chain "$ROOT/tests/test_runtime_evidence_chain.rex" "$ROOT" "$RUNTIME_REGISTRY_ROOT" "$STRUCTURED_RELATION_ROOT"
else
  echo "SKIP runtime evidence chain (set RUNTIME_REGISTRY_ROOT and STRUCTURED_RELATION_ROOT)"
fi

if [[ -n "$HARDWORLD_ROOT" && -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  echo "== hardworld-promotion-compat =="
  (
    cd "$HARDWORLD_ROOT/integration"
    export PATH="$ROOT/src:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC:$RUNTIME_REGISTRY_ROOT/src:$HARDWORLD_ROOT/integration:$HARDWORLD_ROOT/algorithm:$HARDWORLD_ROOT:$PATH"
    export REXX_PATH="$ROOT/src:$ALCHEMY_OBJECTS_SRC:$CRYPTO_SRC:$RUNTIME_REGISTRY_ROOT/src:$HARDWORLD_ROOT/integration:$HARDWORLD_ROOT/algorithm:$HARDWORLD_ROOT${REXX_PATH:+:$REXX_PATH}"
    "$REXX" "$ROOT/tests/test_hardworld_v018_promotion_compat.rex"
  )
else
  echo "SKIP HardWorld promotion compatibility (set HARDWORLD_ROOT and RUNTIME_REGISTRY_ROOT)"
fi

run food-delivery-demo "$ROOT/examples/food_delivery_demo.rex"
run framework-snapshot-demo "$ROOT/examples/framework_snapshot_demo.rex"
run authority-conflict-demo "$ROOT/examples/authority_conflict_demo.rex"
run decision-trace-demo "$ROOT/examples/decision_trace_demo.rex"
run decision-trace-query-demo "$ROOT/examples/decision_trace_query_demo.rex"
run counterfactual-demo "$ROOT/examples/counterfactual_demo.rex"
run compiler-boundary-demo "$ROOT/examples/compiler_boundary_demo.rex"
echo "LEGAL EFFECT V0.14 ALL REQUESTED TESTS: OK"

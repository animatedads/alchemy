#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
PATHS="$ROOT/tests:$ROOT/src:$ROOT/runtime"
if [[ -n "$ALCHEMY_OBJECTS_ROOT" ]]; then PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"; fi
if [[ -n "$OOREXX_CRYPTO_ROOT" ]]; then PATHS="$PATHS:$OOREXX_CRYPTO_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run() { echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run rich-conversation "$ROOT/tests/test_rich_conversation.rex"
run privacy-projection "$ROOT/tests/test_privacy_projection.rex"
run assessment-disagreement "$ROOT/tests/test_assessment_disagreement.rex"
run llm-assessment-privacy "$ROOT/tests/test_llm_assessment_privacy.rex"
run sass-commercial-chain "$ROOT/tests/test_sass_commercial_chain.rex"
run inactivity-observation "$ROOT/tests/test_inactivity_observation.rex"
run sealing-and-tokens "$ROOT/tests/test_sealing_and_tokens.rex"
run metadata-alias-immutability "$ROOT/tests/test_metadata_alias_immutability.rex"
run alchemy-base "$ROOT/tests/test_alchemy_base.rex"
run native-structured-evidence "$ROOT/tests/test_native_structured_evidence.rex"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  export PATH="$RUNTIME_REGISTRY_ROOT/src:$PATH"
  export REXX_PATH="$RUNTIME_REGISTRY_ROOT/src:$REXX_PATH"
  run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "INTERACTION EVENT V0.3 ALL REQUESTED TESTS: OK"

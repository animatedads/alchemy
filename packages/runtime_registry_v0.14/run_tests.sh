#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${REXX:=rexx}"
CRYPTO_SRC="${CRYPTO_SRC:-${OOREXX_CRYPTO_SRC:-}}"
if [[ -z "$CRYPTO_SRC" || ! -f "$CRYPTO_SRC/crypto.cls" ]]; then
  echo "set CRYPTO_SRC to the standalone oorexx_crypto src directory" >&2
  exit 2
fi
export REXX_PATH="$ROOT/src:$ROOT:$CRYPTO_SRC${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"

"$REXX" tests/test_runtime_registry.rex "$ROOT"
"$REXX" tests/test_runtime_registry_concurrency.rex "$ROOT"
"$REXX" tests/test_runtime_registry_dependencies.rex "$ROOT"
"$REXX" tests/test_runtime_execution_evidence.rex "$ROOT"
"$REXX" tests/test_runtime_bundle_builder.rex "$ROOT"
"$REXX" tests/test_ability_schema.rex "$ROOT"
"$REXX" tests/test_ability_profile_loader.rex "$ROOT"
"$REXX" tests/test_ability_registry.rex "$ROOT"
"$REXX" tests/test_ability_registry_concurrency.rex "$ROOT"
"$REXX" tests/test_ability_result_store.rex "$ROOT"
"$REXX" tests/test_ability_http_server.rex "$ROOT"
"$REXX" tests/test_ability_pinned_route.rex "$ROOT"
"$REXX" examples/live_reload_demo.rex "$ROOT"
"$REXX" tests/test_runtime_crypto_known_answer.rex "$ROOT"
"$REXX" tests/test_runtime_crypto_verifier.rex "$ROOT"

if [[ -n "${STRUCTURED_RELATION_ROOT:-}" ]]; then
  "$REXX" tests/test_structured_relation_bundle.rex "$ROOT" "$STRUCTURED_RELATION_ROOT"
else
  echo "STRUCTURED RELATION BUNDLE INTEGRATION: SKIP (set STRUCTURED_RELATION_ROOT)"
fi

if [[ -n "${HARDWORLD_ROOT:-}" ]]; then
  "$REXX" tests/test_hardworld_bundle.rex "$ROOT" "$HARDWORLD_ROOT"
else
  echo "HARDWORLD BUNDLE INTEGRATION: SKIP (set HARDWORLD_ROOT)"
fi

if [[ -n "${STRUCTURED_RELATION_ROOT:-}" && -n "${HARDWORLD_ROOT:-}" ]]; then
  "$REXX" tests/test_hardworld_rich_dependency.rex "$ROOT" "$STRUCTURED_RELATION_ROOT" "$HARDWORLD_ROOT"
  "$REXX" tests/test_ability_registry_real_stack.rex "$ROOT" "$STRUCTURED_RELATION_ROOT" "$HARDWORLD_ROOT"
  "$REXX" tests/test_ability_http_real_stack.rex "$ROOT" "$STRUCTURED_RELATION_ROOT" "$HARDWORLD_ROOT"
else
  echo "HARDWORLD/STRUCTURED ABILITY INTEGRATION: SKIP (set STRUCTURED_RELATION_ROOT and HARDWORLD_ROOT)"
fi
if [[ -n "${QUEUE_FABRIC_ROOT:-}" ]]; then
  "$REXX" tests/test_ability_http_queue_fabric.rex "$ROOT" "$QUEUE_FABRIC_ROOT"
else
  echo "ABILITY HTTP QUEUE FABRIC INTEGRATION: SKIP (set QUEUE_FABRIC_ROOT)"
fi

if [[ -n "${NOSQLSERVER_ROOT:-}" ]]; then
  "$REXX" tests/test_ability_http_nosqlserver.rex "$ROOT" "$NOSQLSERVER_ROOT"
else
  echo "ABILITY HTTP NOSQLSERVER INTEGRATION: SKIP (set NOSQLSERVER_ROOT)"
fi

if [[ -n "${WLU_ROOT:-}" ]]; then
  REXX_PATH="$WLU_ROOT/src:$REXX_PATH" "$REXX" tests/test_ability_wlu_http.rex "$ROOT" "$WLU_ROOT"
else
  echo "ABILITY HTTP WLU INTEGRATION: SKIP (set WLU_ROOT)"
fi

if [[ -n "${TERMINAL_MACHINE_ROOT:-}" ]]; then
  "$REXX" tests/test_ability_http_terminal_machine.rex "$ROOT" "$TERMINAL_MACHINE_ROOT"
else
  echo "ABILITY HTTP TERMINAL MACHINE INTEGRATION: SKIP (set TERMINAL_MACHINE_ROOT)"
fi
if [[ -n "${LEGAL_EFFECT_ROOT:-}" ]]; then
  PATH="$LEGAL_EFFECT_ROOT/src:$ROOT/src:$PATH" \
  RUNTIME_REGISTRY_ROOT="$ROOT" \
  "$REXX" "$LEGAL_EFFECT_ROOT/tests/test_runtime_registry_bridge.rex" "$LEGAL_EFFECT_ROOT"
  if [[ -n "${STRUCTURED_RELATION_ROOT:-}" ]]; then
    PATH="$LEGAL_EFFECT_ROOT/src:$ROOT/src:$STRUCTURED_RELATION_ROOT/src:$PATH" \
    RUNTIME_REGISTRY_ROOT="$ROOT" \
    "$REXX" "$LEGAL_EFFECT_ROOT/tests/test_runtime_evidence_chain.rex" "$LEGAL_EFFECT_ROOT" "$ROOT" "$STRUCTURED_RELATION_ROOT"
  else
    echo "LEGAL EFFECT RUNTIME EVIDENCE CHAIN: SKIP (set STRUCTURED_RELATION_ROOT)"
  fi
else
  echo "LEGAL EFFECT RUNTIME INTEGRATION: SKIP (set LEGAL_EFFECT_ROOT)"
fi

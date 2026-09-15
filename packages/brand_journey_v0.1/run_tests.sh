#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
ALCHEMY_OBJECTS_ROOT="${ALCHEMY_OBJECTS_ROOT:-}"
OOREXX_CRYPTO_ROOT="${OOREXX_CRYPTO_ROOT:-}"
BRAND_INTERACTION_EFFECT_ROOT="${BRAND_INTERACTION_EFFECT_ROOT:-}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
PATHS="$ROOT/tests:$ROOT/src:$ROOT/integration:$ROOT/runtime"
if [[ -n "$ALCHEMY_OBJECTS_ROOT" ]]; then PATHS="$PATHS:$ALCHEMY_OBJECTS_ROOT/src"; fi
if [[ -n "$OOREXX_CRYPTO_ROOT" ]]; then PATHS="$PATHS:$OOREXX_CRYPTO_ROOT/src"; fi
if [[ -n "$BRAND_INTERACTION_EFFECT_ROOT" ]]; then PATHS="$PATHS:$BRAND_INTERACTION_EFFECT_ROOT/src"; fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then PATHS="$PATHS:$RUNTIME_REGISTRY_ROOT/src"; fi
export PATH="$PATHS:${PATH}"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
run(){ echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run service-as-sales-journey "$ROOT/tests/test_service_as_sales_journey.rex"
run context-loss-repeat-burden "$ROOT/tests/test_context_loss_repeat_burden.rex"
run unresolved-sales-boundary "$ROOT/tests/test_unresolved_sales_boundary.rex"
run alchemy-privacy "$ROOT/tests/test_alchemy_privacy.rex"
if [[ -n "$BRAND_INTERACTION_EFFECT_ROOT" ]]; then
  run brand-interaction-bridge "$ROOT/tests/test_brand_interaction_bridge.rex"
  run effect-bridge "$ROOT/tests/test_effect_bridge.rex"
else
  echo "SKIP brand-interaction bridges (set BRAND_INTERACTION_EFFECT_ROOT)"
fi
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  run runtime-registry "$ROOT/tests/test_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "BRAND JOURNEY V0.1 ALL REQUESTED TESTS: OK"

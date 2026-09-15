#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
RUNTIME_REGISTRY_ROOT="${RUNTIME_REGISTRY_ROOT:-}"
export PATH="$ROOT/tests:$ROOT/src:$ROOT/runtime:${PATH}"
export REXX_PATH="$ROOT/tests:$ROOT/src:$ROOT/runtime${REXX_PATH:+:$REXX_PATH}"
run() { echo "== $1 =="; shift; "$REXX" "$@"; }
run compile "$ROOT/tests/compile_smoke.rex"
run geographic-airline "$ROOT/tests/test_reputation_geographic_airline.rex"
run manufacturer-distance "$ROOT/tests/test_reputation_manufacturer_distance.rex"
run mile-high-collision "$ROOT/tests/test_reputation_mile_high_collision.rex"
run competitor-brand-norm "$ROOT/tests/test_reputation_competitor_brand_norm.rex"
run human-harm-boundary "$ROOT/tests/test_reputation_human_harm_boundary.rex"
run freshness-unknown "$ROOT/tests/test_reputation_freshness_unknown.rex"
run temporal-replay "$ROOT/tests/test_reputation_temporal_replay.rex"
run geography-propagation "$ROOT/tests/test_reputation_geography_propagation.rex"
run brand-mismatch "$ROOT/tests/test_reputation_brand_mismatch.rex"
run sealing "$ROOT/tests/test_reputation_sealing.rex"
run observation-geography "$ROOT/tests/test_reputation_observation_geography.rex"
run communication-pair "$ROOT/tests/test_reputation_communication_pair.rex"
run communication-recovery "$ROOT/tests/test_reputation_communication_recovery.rex"
run communication-sealing "$ROOT/tests/test_reputation_communication_sealing.rex"
if [[ -n "$RUNTIME_REGISTRY_ROOT" ]]; then
  export PATH="$RUNTIME_REGISTRY_ROOT/src:$PATH"
  export REXX_PATH="$RUNTIME_REGISTRY_ROOT/src:$REXX_PATH"
  run runtime-registry "$ROOT/tests/test_reputation_runtime_registry.rex" "$ROOT"
else
  echo "SKIP runtime-registry (set RUNTIME_REGISTRY_ROOT)"
fi
echo "REPUTATION EFFECT V0.2 ALL REQUESTED TESTS: OK"

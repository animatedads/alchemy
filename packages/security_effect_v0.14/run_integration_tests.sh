#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ALCHEMY_ROOT:?Set ALCHEMY_ROOT}"
: "${CRYPTO_ROOT:?Set CRYPTO_ROOT}"
: "${POLICY_ROOT:?Set POLICY_ROOT to institutional_policy_v0.8 root}"
: "${INTERACTION_ROOT:?Set INTERACTION_ROOT to interaction_event_v0.3 root}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$ROOT/runtime:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$POLICY_ROOT/src:$INTERACTION_ROOT/src${REXX_PATH:+:$REXX_PATH}"
rexx "$ROOT/tests/test_interaction_event_integration.rex"
rexx "$ROOT/tests/test_external_mapping_policy.rex"

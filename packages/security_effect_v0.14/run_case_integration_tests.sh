#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ALCHEMY_ROOT:?Set ALCHEMY_ROOT to alchemy_objects_v0.8 root}"
: "${CRYPTO_ROOT:?Set CRYPTO_ROOT to oorexx_crypto_v0.1 root}"
: "${POLICY_ROOT:?Set POLICY_ROOT to institutional_policy_v0.8 root}"
: "${CASE_ROOT:?Set CASE_ROOT to relationship_case_v0.2 root}"
: "${CASE_SERVICE_ROOT:?Set CASE_SERVICE_ROOT to relationship_case_service_v0.1 root}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$ROOT/runtime:$ROOT/integration:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$POLICY_ROOT/src:$CASE_ROOT/src:$CASE_ROOT/examples:$CASE_SERVICE_ROOT/src${REXX_PATH:+:$REXX_PATH}"
rexx "$ROOT/tests/test_relationship_case_referral_integration.rex"
rexx "$ROOT/tests/test_relationship_case_referral_idempotency.rex"

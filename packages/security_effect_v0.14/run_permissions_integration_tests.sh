#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ALCHEMY_ROOT:?Set ALCHEMY_ROOT to alchemy_objects_v0.8 root}"
: "${CRYPTO_ROOT:?Set CRYPTO_ROOT to oorexx_crypto_v0.5 root}"
: "${POLICY_ROOT:?Set POLICY_ROOT to institutional_policy_v0.8 root}"
: "${ACCESS_PERMISSIONS_ROOT:?Set ACCESS_PERMISSIONS_ROOT to oorexx_access_permissions_v0.1 root}"
: "${RELATIONSHIP_CASE_ROOT:?Set RELATIONSHIP_CASE_ROOT to relationship_case_v0.2 root}"
: "${RELATIONSHIP_CASE_SERVICE_ROOT:?Set RELATIONSHIP_CASE_SERVICE_ROOT to relationship_case_service_v0.1 root}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$ROOT/integration:$ROOT/runtime:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$POLICY_ROOT/src:$ACCESS_PERMISSIONS_ROOT/src:$RELATIONSHIP_CASE_ROOT/src:$RELATIONSHIP_CASE_ROOT/examples:$RELATIONSHIP_CASE_SERVICE_ROOT/src:$RELATIONSHIP_CASE_SERVICE_ROOT/tests${REXX_PATH:+:$REXX_PATH}"
for t in test_access_permissions_integration.rex test_access_permissions_review_boundary.rex test_access_permissions_invocation_freshness.rex test_access_permissions_commit_boundary.rex; do
  echo "== $t =="
  rexx "$ROOT/tests/$t"
done

echo "== test_alchemy_invocation_freshness_integration.rex =="
rexx "$ROOT/tests/test_alchemy_invocation_freshness_integration.rex" "$ROOT/tests/invocation_freshness_agent.rex"

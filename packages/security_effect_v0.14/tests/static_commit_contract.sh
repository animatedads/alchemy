#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src/SecurityEffect.cls"
BRIDGE="$ROOT/integration/SecurityContinuationAccessPermissionsBridge.cls"
CORE="$ROOT/tests/test_commit_revalidation.rex"

grep -Fq '::constant API_VERSION "security.effect/0.14"' "$SRC"
grep -Fq '::constant POLICY_SCHEMA "security.policy/0.5"' "$SRC"
grep -Fq '::constant CONTINUATION_POLICY_SCHEMA "security.continuation.policy/0.1"' "$SRC"
grep -Fq '::constant CONTINUATION_BINDING_SCHEMA "security.continuation.binding/0.1"' "$SRC"
grep -Fq '::class SecurityContinuationEvidence public' "$SRC"
grep -Fq 'ORIGIN_EXECUTION_EVIDENCE_IDENTITY' "$SRC"
grep -Fq 'SECURITY_ORIGIN_EXECUTION_EVIDENCE_REQUIRED' "$SRC"
grep -Fq 'SECURITY_COMMIT_STATE_MISMATCH' "$SRC"
grep -Fq 'SECURITY_COMMIT_CONTEXT_MISMATCH' "$SRC"
grep -Fq 'SECURITY_COMMIT_NOT_ALLOWED' "$SRC"
grep -Fq 'SECURITY_COMMIT_EVIDENCE_EXPIRED' "$SRC"
grep -Fq 'SECURITY_CONTINUATION_ALREADY_COMMITTED' "$SRC"
grep -Fq 'SECURITY_COMMIT_CONSUMPTION_FAILED_CLOSED' "$SRC"
if grep -Fq 'consumed~remove(' "$SRC"; then
  echo 'FAIL replay barrier rollback found' >&2
  exit 1
fi
grep -Fq 'PermissionRequest~new' "$BRIDGE"
grep -Fq 'commitIfAllowed' "$BRIDGE"
grep -Fq "SECURITY_ORIGIN_EXECUTION_EVIDENCE_REQUIRED" "$CORE"
grep -Fq "test_commit_revalidation.rex" "$ROOT/run_tests.sh"
grep -Fq "test_access_permissions_commit_boundary.rex" "$ROOT/run_permissions_integration_tests.sh"
bash -n "$ROOT/run_tests.sh" "$ROOT/run_integration_tests.sh" "$ROOT/run_case_integration_tests.sh" "$ROOT/run_permissions_integration_tests.sh"
echo 'STATIC COMMIT CONTRACT: PASS'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ALCHEMY_ROOT:?Set ALCHEMY_ROOT to alchemy_objects_v0.8 root}"
: "${CRYPTO_ROOT:?Set CRYPTO_ROOT to oorexx_crypto_v0.5 root}"
: "${POLICY_ROOT:?Set POLICY_ROOT to institutional_policy_v0.8 root}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$ROOT/runtime:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$POLICY_ROOT/src${REXX_PATH:+:$REXX_PATH}"
for t in compile_smoke.rex test_alchemy_adoption.rex test_evidence_uncertainty.rex test_kazakhstan_gold.rex test_barbie_cross_session.rex test_probe_analyzer.rex test_exploit_scope.rex test_runtime_facade.rex test_policy_determinism.rex test_policy_catalog.rex test_policy_replay.rex test_capability_envelope.rex test_runtime_policy_catalog.rex test_time_semantics.rex test_shared_institutional_policy.rex test_policy_authority_integration.rex test_policy_multiparty_authority_integration.rex test_policy_authority_succession_integration.rex test_policy_emergency_authority_integration.rex test_policy_deployment_lifecycle_integration.rex test_policy_deployment_topology_integration.rex test_policy_progressive_rollout_integration.rex test_policy_rollout_gate_integration.rex test_policy_post_promotion_rollback_integration.rex test_policy_emergency_ratification_integration.rex test_policy_schema_stability.rex test_canonical_newlines.rex test_method_permission_binding.rex test_invocation_freshness.rex test_commit_revalidation.rex; do
  echo "== $t =="
  rexx "$ROOT/tests/$t"
done

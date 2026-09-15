#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${ALCHEMY_ROOT:?Set ALCHEMY_ROOT to alchemy_objects_v0.8 root}"
: "${CRYPTO_ROOT:?Set CRYPTO_ROOT to oorexx_crypto_v0.1 root}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src${LEGAL_ROOT:+:$LEGAL_ROOT/src:$LEGAL_ROOT/tests/fixtures}${REXX_PATH:+:$REXX_PATH}"
for t in compile_smoke.rex test_alchemy_adoption.rex test_release_catalog.rex test_replay_guard.rex test_policy_authority.rex test_authority_optional_evidence.rex test_authority_multiparty.rex test_authority_succession.rex test_authority_delegation_revocation.rex test_emergency_publication.rex test_policy_deployment_lifecycle.rex test_policy_deployment_topology.rex test_progressive_policy_rollout.rex test_rollout_evidence_gate.rex test_post_promotion_rollback_gate.rex test_emergency_ratification_lifecycle.rex test_lifecycle_authority_succession.rex; do
  echo "== $t =="
  rexx "$ROOT/tests/$t"
done
if [[ -n "${LEGAL_ROOT:-}" ]]; then
  echo "== test_legal_release_bridge.rex =="
  rexx "$ROOT/tests/test_legal_release_bridge.rex"
fi

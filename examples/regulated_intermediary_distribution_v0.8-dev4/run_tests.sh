#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/tests${REXX_PATH:+:$REXX_PATH}"
for t in \
  test_mortgage_permission_gate.rex \
  test_mortgage_evidence_gate.rex \
  test_investment_execution_only.rex \
  test_insurance_provider_boundary.rex \
  test_provider_status_exact_identity.rex \
  test_provider_status_late_event.rex \
  test_representative_suspension.rex \
  test_authority_revocation.rex \
  test_product_approval_identity.rex \
  test_vmm_not_relabelled_internal.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done

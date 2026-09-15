#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${RID_ROOT:?set RID_ROOT}"
: "${RID_SERVICE_ROOT:?set RID_SERVICE_ROOT}"
: "${AJI_ROOT:?set AJI_ROOT}"
export REXX_PATH="$HERE/src:$HERE/tests:$RID_SERVICE_ROOT/src:$RID_SERVICE_ROOT/tests:$RID_ROOT/src:$RID_ROOT/examples:$AJI_ROOT/src${REXX_PATH:+:$REXX_PATH}"
for t in test_submit_boundary.rex test_exact_provider_identity.rex test_sales_target_not_evidence.rex test_full_provider_lifecycle.rex; do
 echo "== $t =="
 "$REXX_BIN" "$HERE/tests/$t"
done

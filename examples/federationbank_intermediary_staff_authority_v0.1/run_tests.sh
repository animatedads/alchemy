#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${STAFF_SRC:?set STAFF_SRC}"
: "${STAFF_EXAMPLES:?set STAFF_EXAMPLES}"
: "${RID_SRC:?set RID_SRC}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC}"
: "${POLICY_SRC:?set POLICY_SRC}"
: "${FB_SRC:?set FB_SRC}"
: "${LEGAL_SRC:?set LEGAL_SRC}"
: "${SECURITY_SRC:?set SECURITY_SRC}"
: "${CIVIC_SRC:?set CIVIC_SRC}"
: "${DB_SRC:?set DB_SRC}"
: "${QUEUE_SRC:?set QUEUE_SRC}"
: "${JMS_SRC:?set JMS_SRC}"
: "${CRYPTO_SRC:?set CRYPTO_SRC}"
: "${OOREXX_LIB:?set OOREXX_LIB}"
export REXX_PATH="$HERE/src:$HERE/runtime:$HERE/tests:$STAFF_SRC:$STAFF_EXAMPLES:$RID_SRC:$FB_SRC:$ALCHEMY_SRC:$POLICY_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$QUEUE_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
for t in \
 test_effective_representative_binding.rex \
 test_institutional_scope_required.rex \
 test_exact_product_binding.rex \
 test_exact_action_dimensions.rex \
 test_rid_pair_independent_authority.rex \
 test_runtime_module.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done

#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${REL_ADAPTER_SRC:?set REL_ADAPTER_SRC}"
: "${REL_ADAPTER_EXAMPLES:?set REL_ADAPTER_EXAMPLES}"
: "${CASE_SRC:?set CASE_SRC}"
# run_tests.sh requirements are also required by this script.
: "${ALCHEMY_SRC:?}"; : "${POLICY_SRC:?}"; : "${FB_SRC:?}"; : "${LEGAL_SRC:?}"; : "${SECURITY_SRC:?}"; : "${CIVIC_SRC:?}"; : "${DB_SRC:?}"; : "${QUEUE_SRC:?}"; : "${JMS_SRC:?}"; : "${CRYPTO_SRC:?}"; : "${OOREXX_LIB:?}"
export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/runtime:$HERE/tests:$REL_ADAPTER_SRC:$REL_ADAPTER_EXAMPLES:$CASE_SRC:$FB_SRC:$ALCHEMY_SRC:$POLICY_SRC:$LEGAL_SRC:$SECURITY_SRC:$CIVIC_SRC:$DB_SRC:$QUEUE_SRC:$JMS_SRC:$CRYPTO_SRC:$OOREXX_LIB${REXX_PATH:+:$REXX_PATH}"
echo "== test_relationship_staff_core_chain.rex =="
"$REXX_BIN" "$HERE/tests/test_relationship_staff_core_chain.rex"

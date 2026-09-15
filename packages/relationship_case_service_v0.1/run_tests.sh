#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${CASE_SRC:?set CASE_SRC to relationship_case_v0.2/src}"
: "${CASE_INTEGRATION:?set CASE_INTEGRATION to relationship_case_v0.2/integration}"
: "${CASE_EXAMPLES:?set CASE_EXAMPLES to relationship_case_v0.2/examples}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to alchemy_objects_v0.8/src}"
: "${POLICY_SRC:?set POLICY_SRC to institutional_policy_v0.8/src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to oorexx_crypto_v0.1/src}"
: "${QUEUE_SRC:?set QUEUE_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/runtime:$HERE/tests:$CASE_SRC:$CASE_INTEGRATION:$CASE_EXAMPLES:$ALCHEMY_SRC:$POLICY_SRC:$CRYPTO_SRC:$QUEUE_SRC${REXX_PATH:+:$REXX_PATH}"
for t in \
  test_service_commands.rex \
  test_idempotency.rex \
  test_policy_barrier_service.rex \
  test_crm_boundary.rex \
  test_queue_adapter.rex \
  test_runtime_module.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done
state_root="$(mktemp -d)"
queue_root="$(mktemp -d)"
trap 'rm -rf "$state_root" "$queue_root"' EXIT
echo "== test_persistence_restart.rex =="
"$REXX_BIN" "$HERE/tests/test_persistence_restart.rex" "$state_root"
echo "== test_queue_persistent_recovery.rex =="
"$REXX_BIN" "$HERE/tests/test_queue_persistent_recovery.rex" "$queue_root"

#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to alchemy_objects_v0.8/src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to oorexx_crypto_v0.5/src}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${RUNTIME_REFERENCE_SRC:?set RUNTIME_REFERENCE_SRC to runtime_reference_v0.2/src}"
export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/tests:$ALCHEMY_SRC:$CRYPTO_SRC:$QUEUE_FABRIC_SRC:$RUNTIME_REFERENCE_SRC${REXX_PATH:+:$REXX_PATH}"
for t in \
  test_worklist_authoritative_status.rex \
  test_worklist_decline_supersedes.rex \
  test_work_sla_expiry.rex \
  test_signature_work_gate.rex \
  test_work_recovery.rex \
  test_unsigned_provider_completion_exception.rex \
  test_work_source_redelivery_idempotent.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done

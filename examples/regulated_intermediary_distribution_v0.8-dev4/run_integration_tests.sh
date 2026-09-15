#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${POLICY_SRC:?set POLICY_SRC to institutional_policy_v0.8/src}"
: "${RELATIONSHIP_CASE_SRC:?set RELATIONSHIP_CASE_SRC to relationship_case_v0.2/src}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to alchemy_objects_v0.8/src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to oorexx_crypto_v0.5/src}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${RUNTIME_REFERENCE_SRC:?set RUNTIME_REFERENCE_SRC to runtime_reference_v0.2/src}"
: "${CRYPTO_REFERENCE_SERVICE:?set CRYPTO_REFERENCE_SERVICE to oorexx_crypto_v0.5/tests/python_crypto_reference_service.py}"
: "${OOREXX_LIB_SRC:=}"

PORT_FILE="$(mktemp)"
python3 "$CRYPTO_REFERENCE_SERVICE" --port-file "$PORT_FILE" >/tmp/rid_crypto_reference.$$.log 2>&1 &
CRYPTO_PID=$!
cleanup() {
  kill "$CRYPTO_PID" 2>/dev/null || true
  rm -f "$PORT_FILE" /tmp/rid_crypto_reference.$$.log
}
trap cleanup EXIT
for _ in $(seq 1 100); do
  [[ -s "$PORT_FILE" ]] && break
  sleep 0.05
done
[[ -s "$PORT_FILE" ]] || { echo "crypto reference service failed to start" >&2; exit 1; }
export CRYPTO_REFERENCE_TEST_PORT="$(cat "$PORT_FILE")"

export REXX_PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/tests:$POLICY_SRC:$RELATIONSHIP_CASE_SRC:$ALCHEMY_SRC:$CRYPTO_SRC:$QUEUE_FABRIC_SRC:$RUNTIME_REFERENCE_SRC${OOREXX_LIB_SRC:+:$OOREXX_LIB_SRC}${REXX_PATH:+:$REXX_PATH}"
for t in \
  test_institutional_policy_bridge.rex \
  test_relationship_case_bridge.rex \
  test_digital_signature_ed25519.rex \
  test_queue_status_projection.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done

#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${REXX:=rexx}"
: "${ALCHEMY_OBJECTS_DIR:?set ALCHEMY_OBJECTS_DIR}"
: "${INSTITUTIONAL_POLICY_DIR:?set INSTITUTIONAL_POLICY_DIR}"
: "${OOREXX_CRYPTO_DIR:?set OOREXX_CRYPTO_DIR}"
CASE_PART=""
QUEUE_PART=""
if [[ -n "${QUEUE_FABRIC_DIR:-}" ]]; then QUEUE_PART=":$QUEUE_FABRIC_DIR/src"; fi
if [[ -n "${RELATIONSHIP_CASE_DIR:-}" ]]; then CASE_PART=":$RELATIONSHIP_CASE_DIR/src:$RELATIONSHIP_CASE_DIR/integration"; fi
export PATH="$HERE/src:$HERE/examples:$HERE/integration:$HERE/runtime:$HERE/tests:$ALCHEMY_OBJECTS_DIR/src:$INSTITUTIONAL_POLICY_DIR/src:$OOREXX_CRYPTO_DIR/src$CASE_PART$QUEUE_PART:$PATH"
pass=0
for t in "$HERE"/tests/test_*.rex; do
  if [[ "$(basename "$t")" == "test_case_bridge.rex" && -z "${RELATIONSHIP_CASE_DIR:-}" ]]; then continue; fi
  if [[ "$(basename "$t")" == "test_queue_persistence.rex" && -z "${QUEUE_FABRIC_DIR:-}" ]]; then continue; fi
  "$REXX" "$t"
  pass=$((pass+1))
done
echo "Relationship CRM v0.1 tests passed: $pass"

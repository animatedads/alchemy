#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
: "${REXX:=rexx}"
: "${RELATIONSHIP_CRM_DIR:?set RELATIONSHIP_CRM_DIR}"
: "${ALCHEMY_OBJECTS_DIR:?set ALCHEMY_OBJECTS_DIR}"
: "${INSTITUTIONAL_POLICY_DIR:?set INSTITUTIONAL_POLICY_DIR}"
: "${OOREXX_CRYPTO_DIR:?set OOREXX_CRYPTO_DIR}"
: "${QUEUE_FABRIC_DIR:?set QUEUE_FABRIC_DIR}"
export PATH="$HERE/src:$HERE/integration:$HERE/runtime:$HERE/tests:$RELATIONSHIP_CRM_DIR/src:$RELATIONSHIP_CRM_DIR/examples:$RELATIONSHIP_CRM_DIR/integration:$ALCHEMY_OBJECTS_DIR/src:$INSTITUTIONAL_POLICY_DIR/src:$OOREXX_CRYPTO_DIR/src:$QUEUE_FABRIC_DIR/src:$PATH"
pass=0
TMPBASE=$(mktemp -d)
trap 'rm -rf "$TMPBASE"' EXIT
for t in "$HERE"/tests/test_*.rex; do
  export CRM_TEST_ROOT="$TMPBASE/$(basename "$t" .rex)"
  mkdir -p "$CRM_TEST_ROOT"
  "$REXX" "$t"
  pass=$((pass+1))
done
echo "Relationship CRM Service v0.1 tests passed: $pass"

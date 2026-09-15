#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
: "${REXX_BIN:=rexx}"
: "${ALCHEMY_SRC:?set ALCHEMY_SRC to alchemy_objects_v0.8/src}"
: "${POLICY_SRC:?set POLICY_SRC to institutional_policy_v0.8/src}"
: "${INTERACTION_SRC:?set INTERACTION_SRC to interaction_event_v0.3/src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to oorexx_crypto_v0.1/src}"
: "${REPUTATION_SRC:?set REPUTATION_SRC to reputation_feed_v0.12/src}"
: "${QUEUE_SRC:?set QUEUE_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
export REXX_PATH="$HERE/src:$HERE/integration:$HERE/examples:$HERE/tests:$HERE/runtime:$ALCHEMY_SRC:$POLICY_SRC:$INTERACTION_SRC:$CRYPTO_SRC:$REPUTATION_SRC:$QUEUE_SRC${REXX_PATH:+:$REXX_PATH}"
for t in \
  test_policy_driven_case.rex \
  test_alan_external_pressure.rex \
  test_complaint_case.rex \
  test_multiple_cases_same_subject.rex \
  test_interaction_bridge.rex \
  test_reputation_bridge.rex \
  test_queue_persistence.rex; do
  echo "== $t =="
  "$REXX_BIN" "$HERE/tests/$t"
done

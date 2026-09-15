#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REXX="${REXX:-rexx}"
: "${ALCHEMY_OBJECTS_ROOT:?set ALCHEMY_OBJECTS_ROOT to alchemy_objects_v0.8/src}"
: "${AI_ACCESS_ROOT:?set AI_ACCESS_ROOT to oorexx_ai_access_v0.6/src}"
: "${SECRET_BROKER_ROOT:?set SECRET_BROKER_ROOT to oorexx_secret_broker_v0.2/src}"
: "${CRYPTO_SRC:?set CRYPTO_SRC to oorexx_crypto_v0.1/src}"
OOREXX_STD_ROOT="${OOREXX_STD_ROOT:-$(dirname "$REXX")}"
export REXX_PATH="$ROOT/tests:$ROOT/src:$ALCHEMY_OBJECTS_ROOT:$AI_ACCESS_ROOT:$SECRET_BROKER_ROOT:$CRYPTO_SRC:$OOREXX_STD_ROOT"
status=0
for test in \
  "$ROOT/tests/test_capability_selector.rex" \
  "$ROOT/tests/test_transport_loads.rex" \
  "$ROOT/tests/test_secret_broker_transport.rex" \
  "$ROOT/tests/test_alchemy_v08_adoption.rex"; do
  echo "=== $(basename "$test") ==="
  if ! "$REXX" "$test" "$ROOT"; then status=1; break; fi
done
if [[ $status -eq 0 && "${ANTHROPIC_API_KEY:-}" != "" ]]; then
  for test in "$ROOT/tests/test_real_wire.rex" "$ROOT/tests/test_real_batch_wire.rex"; do
    echo "=== $(basename "$test") (live network) ==="
    if ! "$REXX" "$test" "$ROOT"; then status=1; break; fi
  done
else
  echo "ANTHROPIC_API_KEY not set -- skipping live-network wire tests"
fi
exit "$status"

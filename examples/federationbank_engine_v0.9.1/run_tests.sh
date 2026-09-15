#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${INSTITUTIONAL_POLICY_SRC:?set INSTITUTIONAL_POLICY_SRC to institutional_policy_v0.8/src}"
: "${LEGAL_EFFECT_SRC:?set LEGAL_EFFECT_SRC to legal_effect_v0.14/src}"
: "${SECURITY_EFFECT_SRC:?set SECURITY_EFFECT_SRC to security_effect_v0.10/src}"
: "${SECURITY_EFFECT_RUNTIME:?set SECURITY_EFFECT_RUNTIME to security_effect_v0.10/runtime}"
: "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to oorexx_queue_fabric_v0.9-dev4/src}"
: "${ALCHEMY_OBJECTS_SRC:?set ALCHEMY_OBJECTS_SRC to alchemy_objects_v0.8/src}"
: "${OOREXX_CRYPTO_SRC:?set OOREXX_CRYPTO_SRC to oorexx_crypto_v0.1/src}"
: "${DB_SKELETON_SRC:?set DB_SKELETON_SRC to oorexx_db_skeleton_v0_45}"
: "${CIVICPORT_SRC:?set CIVICPORT_SRC to civicport_v0.12/src}"
: "${JMS_BRIDGE_SRC:?set JMS_BRIDGE_SRC to oorexx_jms_queue_bridge_v0.1-dev7-fb1/src}"
export REXX_PATH="$ROOT/src:$SECURITY_EFFECT_SRC:$SECURITY_EFFECT_RUNTIME:$LEGAL_EFFECT_SRC:$INSTITUTIONAL_POLICY_SRC:$QUEUE_FABRIC_SRC:$ALCHEMY_OBJECTS_SRC:$OOREXX_CRYPTO_SRC:$DB_SKELETON_SRC:$CIVICPORT_SRC:$JMS_BRIDGE_SRC${REXX_PATH:+:$REXX_PATH}"
export TERM="${TERM:-xterm}"
for f in "$ROOT"/src/*.cls; do
  rexxc "$f" >/dev/null
  echo "COMPILE $(basename "$f")"
done
for t in "$ROOT"/tests/test_*.rex; do
  echo "=== $(basename "$t") ==="
  qroot="$(mktemp -d)"
  FB_TEST_QUEUE_ROOT="$qroot" rexx "$t"
  rm -rf "$qroot"
done

echo "=== smoke_runtime.rex ==="
qroot="$(mktemp -d)"
FB_TEST_QUEUE_ROOT="$qroot" rexx "$ROOT/tests/smoke_runtime.rex"
rm -rf "$qroot"

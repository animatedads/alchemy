#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../src/CivicNotam.cls"

# NOTAM semantics are downstream of preserved SWIM evidence only. They must not
# own JMS/Queue transport, credentials, SQL, or HardWorld promotion.
if grep -nE 'JMSQueueBridgeBSF|javax\.jms|com\.solacesystems|SecretBroker|ObjectQueueManager|JMSBridgeMessage|CivicRelation|NoSQLServer|CivicHardWorld|HardWorld|CivicPromotion' "$SRC" | grep -vE '^[0-9]+:[[:space:]]*(/\\*|\\*)'; then
  echo "FAIL v0.13 NOTAM evidence layer leaked transport/credential/SQL/HardWorld dependency" >&2
  exit 1
fi

# FAA date-time groups stay lexical evidence in this slice. No DateTime
# conversion or arithmetic normalization is allowed here.
if grep -nE '\.DateTime|[+][[:space:]]*0' "$SRC"; then
  echo "FAIL v0.13 NOTAM lexical time tokens gained conversion/normalization" >&2
  exit 1
fi

echo "PASS test_notam_boundary_v013"

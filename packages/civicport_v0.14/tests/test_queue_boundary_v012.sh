#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../src"
# CivicPort may know the Java-neutral persisted JMS envelope, but never the live
# BSF/JNDI/JMS provider implementation.
if grep -RInE 'JMSQueueBridgeBSF|BSF\.CLS|javax\.jms|com\.solacesystems|InitialContext|createConnection' \
  "$SRC/CivicQueueEvidence.cls" "$SRC/CivicQueueIngress.cls" "$SRC/CivicSwim.cls"; then
  echo "FAIL v0.12 Java/JMS provider boundary leaked into CivicPort" >&2
  exit 1
fi
# Semantic SWIM projection must not own queue acknowledgement either.
if grep -nE 'ObjectQueueManager|JMSBridgeMessage|~(claim|ack|nack|release)[[:space:]]*\(' "$SRC/CivicSwim.cls"; then
  echo "FAIL v0.12 SWIM semantics leaked queue transport operations" >&2
  exit 1
fi
echo "PASS test_queue_boundary_v012"

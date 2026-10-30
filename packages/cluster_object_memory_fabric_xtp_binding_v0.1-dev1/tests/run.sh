#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
python3 "$ROOT/tests/test_contract_static.py"
if command -v rexx >/dev/null 2>&1; then
  : "${CLUSTER_OBJECT_SRC:?set CLUSTER_OBJECT_SRC to directory containing ClusterObjectMemoryFabricTransport.cls}"
  : "${QUEUE_FABRIC_SRC:?set QUEUE_FABRIC_SRC to directory containing ObjectQueueChannels.cls/ObjectQueueFabric.cls}"
  : "${QUEUE_XTP_SRC:?set QUEUE_XTP_SRC to directory containing QueueXtpSessionWire.cls/QueueXtpReceiptGate.cls}"
  export REXX_PATH="$ROOT/src:$CLUSTER_OBJECT_SRC:$QUEUE_FABRIC_SRC:$QUEUE_XTP_SRC${REXX_PATH:+:$REXX_PATH}"
  rexx "$ROOT/tests/test_router_model.rex"
else
  echo 'NOT_RUN ooRexx semantic test: rexx not available'
fi

#!/bin/bash
# ============================================================
# run_demo.sh — run the full RTO transport demo
#
# Sender runs from sender/, has Ticker.cls
# Receiver runs from receiver/, has NO Ticker.cls
# Transport file: /tmp/rto_transport_queue.json
# ============================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "Cleaning transport queue..."
rm -f /tmp/rto_transport_queue.json

echo ""
echo "Running sender..."
cd "$SCRIPT_DIR/sender"
rexx sender.rex

echo ""
echo "Running receiver..."
cd "$SCRIPT_DIR/receiver"
rexx receiver.rex

echo ""
echo "Transport queue after demo:"
ls -la /tmp/rto_transport_queue.json 2>/dev/null && \
  python3 -m json.tool /tmp/rto_transport_queue.json | head -5 || \
  echo "  (queue empty — consumed by receiver)"

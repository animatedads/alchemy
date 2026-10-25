#!/usr/bin/env bash
# precision1 gate: large-file byte precision, canonical checkpoints, streaming transfer.
# Needs REXX_BIN (ooRexx 5.3.0) and /usr/bin/truncate.  Creates a sparse 2,005,735,208-byte
# file under /tmp (negligible disk use) and removes it.
set -euo pipefail
cd "$(dirname "$0")/.."
REXX_BIN="${REXX_BIN:-rexx}"
command -v "$REXX_BIN" >/dev/null || { echo "SKIP precision gate (REXX_BIN unavailable)"; exit 0; }
export REXX_PATH="$PWD/src${REXX_PATH:+:$REXX_PATH}"
for t in tests/test_large_file_precision.rex tests/test_streaming_checkpoint.rex tests/test_streaming_transfer.rex; do
  "$REXX_BIN" "$t"
done
echo "PASS ALL STORAGE FABRIC precision1 GATE TESTS"

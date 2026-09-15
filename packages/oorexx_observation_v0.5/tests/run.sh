#!/bin/sh
set -eu
REXX=${REXX:-rexx}
cd "$(dirname "$0")/.."
for t in tests/test_core.rex tests/test_stream.rex tests/test_gateway.rex tests/test_gateway_v04.rex tests/test_service.rex; do "$REXX" "$t"; done

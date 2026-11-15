#!/bin/sh
# test_fetch_transport.sh - the provider over fetch against a local stand-in.
# Needs node; under native ooRexx (no ADDRESS FETCH) the test says SKIP.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
if ! command -v node >/dev/null 2>&1; then echo "OPENAI COMPAT V0.6 FETCH TRANSPORT: SKIP (no node for the stand-in server)"; exit 0; fi
PORT="${FETCH_TEST_PORT:-8972}"
node "$ROOT/tests/fixtures/fetch_mock_server.mjs" "$PORT" &
SERVER=$!
sleep 1
"$REXX_BIN" "$ROOT/tests/test_fetch_transport.rex" "$ROOT" "http://127.0.0.1:$PORT"
status=$?
kill "$SERVER" 2>/dev/null
exit $status

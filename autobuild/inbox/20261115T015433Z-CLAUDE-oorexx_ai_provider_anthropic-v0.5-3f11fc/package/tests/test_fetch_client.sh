#!/bin/sh
# test_fetch_client.sh - the fetch client against a local stand-in for the API.
# Needs node; under native ooRexx (no ADDRESS FETCH) the test says SKIP.
# Architecture: Tom Dyer. Code: Claude (Opus 5.5).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX="${REXX:-rexx}"
if ! command -v node >/dev/null 2>&1; then echo "ANTHROPIC V0.5 FETCH CLIENT: SKIP (no node for the stand-in server)"; exit 0; fi
PORT="${FETCH_TEST_PORT:-8971}"
node "$ROOT/tests/fixtures/fetch_mock_server.mjs" "$PORT" &
SERVER=$!
sleep 1
"$REXX" "$ROOT/tests/test_fetch_client.rex" "$ROOT" "http://127.0.0.1:$PORT"
status=$?
kill "$SERVER" 2>/dev/null
exit $status

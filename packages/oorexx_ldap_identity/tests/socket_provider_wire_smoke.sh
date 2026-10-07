#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${SOCKET_PROVIDER_ROOT:?set SOCKET_PROVIDER_ROOT to ooRexx Socket Provider package root}"
REXX="${REXX:-rexx}"
PORT="${LDAP_SOCKET_PROVIDER_TEST_PORT:-$((24000 + RANDOM % 10000))}"
TMP="$(mktemp -d)"; trap 'kill ${SERVER_PID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
READY="$TMP/ready"
export REXX_PATH="$ROOT:$SOCKET_PROVIDER_ROOT/src${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$ROOT/tests/socket_provider_fixture_server.rex" "$PORT" "$READY" >"$TMP/server.out" 2>"$TMP/server.err" & SERVER_PID=$!
for _ in $(seq 1 100); do [[ -f "$READY" ]] && break; kill -0 "$SERVER_PID" 2>/dev/null || { cat "$TMP/server.err" >&2; exit 1; }; sleep .05; done
[[ -f "$READY" ]] || { cat "$TMP/server.err" >&2; exit 1; }
"$REXX" "$ROOT/tests/test_socket_provider_client.rex" "$PORT"
wait "$SERVER_PID"
cat "$TMP/server.out"
grep -q 'LDAP SOCKET PROVIDER SERVER: OK' "$TMP/server.out"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-$(command -v rexx)}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/grok-curl.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
PORTFILE="$TMP/port"
STATUSFILE="$TMP/status"
SECRET='FAKE-GROK-SECRET-7E4B'
"$REXX_BIN" "$ROOT/tests/grok_fixture_server.rex" "$PORTFILE" "$STATUSFILE" "$SECRET" >"$TMP/server.out" 2>"$TMP/server.err" &
server_pid=$!
for _ in $(seq 1 100); do
  [[ -s "$PORTFILE" ]] && break
  if ! kill -0 "$server_pid" 2>/dev/null; then
    cat "$TMP/server.out" >&2 || true
    cat "$TMP/server.err" >&2 || true
    exit 81
  fi
  sleep 0.05
done
[[ -s "$PORTFILE" ]] || { echo "fixture server did not publish port" >&2; exit 82; }
port="$(tr -d '\r\n' <"$PORTFILE")"
"$REXX_BIN" "$ROOT/tests/test_real_curl.rex" "$ROOT" "$port" "$SECRET"
wait "$server_pid"
[[ "$(tr -d '\r\n' <"$STATUSFILE")" == "OK" ]] || { cat "$STATUSFILE" >&2; exit 83; }

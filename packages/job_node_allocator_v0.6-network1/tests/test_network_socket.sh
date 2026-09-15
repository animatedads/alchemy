#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "$ROOT/tests/tmp_net_socket.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
REXX="${REXX:-rexx}"
KEY="$(printf '33%.0s' {1..64})"
CLIENT_PORT="$TMP/client.port"
SERVER_PORT="$TMP/server.port"
: "${QF_CRYPTO_FOREIGN_BRIDGE:?QF_CRYPTO_FOREIGN_BRIDGE required}"
"$REXX" "$ROOT/tests/socket_allocator_client.rex" "$TMP/a" "$CLIENT_PORT" "$SERVER_PORT" "$KEY" >"$TMP/client.out" 2>"$TMP/client.err" &
CPID=$!
for _ in $(seq 1 200); do
  [[ -s "$CLIENT_PORT" ]] && break
  kill -0 "$CPID" 2>/dev/null || { cat "$TMP/client.err" >&2; exit 1; }
  sleep 0.025
done
[[ -s "$CLIENT_PORT" ]] || { echo 'client listener not ready' >&2; exit 1; }
PORTA="$(tr -d '\r\n' < "$CLIENT_PORT")"
"$REXX" "$ROOT/tests/socket_allocator_server.rex" "$TMP/b" "$SERVER_PORT" "$PORTA" "$KEY" 5 >"$TMP/server.out" 2>"$TMP/server.err" &
SPID=$!
set +e
wait "$CPID"; CRC=$?
wait "$SPID"; SRC=$?
set -e
if [[ $CRC -ne 0 || $SRC -ne 0 ]]; then
  echo '--- client out'; cat "$TMP/client.out" || true
  echo '--- client err'; cat "$TMP/client.err" || true
  echo '--- server out'; cat "$TMP/server.out" || true
  echo '--- server err'; cat "$TMP/server.err" || true
  exit 1
fi
cat "$TMP/client.out"
cat "$TMP/server.out"
grep -q 'CLIENT_OK network allocator encrypted socket round-trip' "$TMP/client.out"
grep -q 'SERVER_OK requests=5' "$TMP/server.out"
echo 'PASS network allocator two-process encrypted Queue Fabric socket qualification'

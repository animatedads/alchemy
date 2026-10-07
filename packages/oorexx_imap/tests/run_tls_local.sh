#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:=rexx}"
: "${API_CLIENT_SRC:?set API_CLIENT_SRC}"
: "${FOREIGN_SRC:?set FOREIGN_SRC}"
: "${FOREIGN_LIB:?set FOREIGN_LIB}"
: "${API_CLIENT_BRIDGE:?set API_CLIENT_BRIDGE}"
: "${TLS_CERT:?set TLS_CERT}"
: "${TLS_KEY:?set TLS_KEY}"
BASE_PORT="${IMAP_TEST_PORT:-29993}"
wait_listen() {
  local p="$1"
  for _ in $(seq 1 50); do
    if ss -ltn 2>/dev/null | grep -q ":$p "; then return 0; fi
    sleep 0.1
  done
  return 1
}
run_case() {
  local server="$1" test="$2" port="$3"
  python3 "$ROOT/tests/tls/$server" --port "$port" --cert "$TLS_CERT" --key "$TLS_KEY" &
  local pid=$!
  trap 'kill "$pid" 2>/dev/null || true' RETURN
  wait_listen "$port"
  LD_LIBRARY_PATH="${OO_REXX_LIB:-}:${FOREIGN_LIB}:${LD_LIBRARY_PATH:-}" \
  REXX_PATH="$ROOT/src:$ROOT/tests:$API_CLIENT_SRC:$FOREIGN_SRC${OO_REXX_CLASS_PATH:+:$OO_REXX_CLASS_PATH}" \
  "$REXX_BIN" "$ROOT/tests/$test" "$port" "$API_CLIENT_BRIDGE" "$TLS_CERT"
  wait "$pid"
  trap - RETURN
}
run_case imap_server.py test_tls_transport.rex "$BASE_PORT"
run_case imap_starttls_server.py test_starttls_transport.rex "$((BASE_PORT+1))"
run_case imap_move_server.py test_move_transport.rex "$((BASE_PORT+2))"
run_case imap_move_fallback_server.py test_move_fallback_transport.rex "$((BASE_PORT+3))"

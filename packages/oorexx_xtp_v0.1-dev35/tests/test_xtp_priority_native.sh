#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?REXX_BIN must point to ooRexx rexx}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PORT="${XTP_TEST_PORT:-$((53000 + RANDOM % 500))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add PRIPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" >/dev/null
if [[ -n "${SOCKET_PROVIDER_DIR:-}" ]]; then
  export REXX_PATH="$ROOT/rexx:$SOCKET_PROVIDER_DIR${REXX_PATH:+:$REXX_PATH}"
else
  export REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
fi
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
"$ROOT/bin/xtp-listen" PRIPEER --max 1 >"$TMP/listener.out" 2>"$TMP/listener.err" & pid=$!
sleep .2
"$REXX_BIN" "$ROOT/tests/test_xtp_priority_native.rex" PRIPEER rexx-priority
wait "$pid"
grep -q 'XTP_ACCEPT .*bytes=13' "$TMP/listener.out"
echo 'PASS ooRexx priority hook -> native libxtp'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?set REXX_BIN to the ooRexx rexx executable}"
TMP="$(mktemp -d)"
pid=''
cleanup() { if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || :; fi; rm -rf "$TMP"; }
trap cleanup EXIT
PORT="${XTP_TEST_PORT:-$((47000 + RANDOM % 10000))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export XTP_HEALTH_FILE="$TMP/health.tsv"
export LD_LIBRARY_PATH="$ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$ROOT/bin/xtp-admin" route add service-node --layer 4 --carrier udp --to "127.0.0.1:$PORT" >/dev/null
"$REXX_BIN" "$ROOT/tests/test_named_service_rexx.rex" listener service-node >"$TMP/listener.out" 2>"$TMP/listener.err" & pid=$!
ready=0
for _ in {1..100}; do
  if grep -q '^NATIVE_LISTENER_READY' "$TMP/listener.out" 2>/dev/null; then ready=1; break; fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 0.03
done
if [[ $ready -ne 1 ]]; then
  echo 'FAIL native ooRexx listener did not start' >&2
  cat "$TMP/listener.out" "$TMP/listener.err" >&2
  exit 1
fi
"$REXX_BIN" "$ROOT/tests/test_named_service_rexx.rex" sender service-node >"$TMP/sender.out" 2>"$TMP/sender.err" || { cat "$TMP/sender.out" "$TMP/sender.err" >&2; exit 1; }
wait "$pid" || { cat "$TMP/listener.out" "$TMP/listener.err" >&2; exit 1; }
pid=''
grep -q '^PASS native ooRexx named-service listener' "$TMP/listener.out"
grep -q '^PASS native ooRexx named-service sender' "$TMP/sender.out"
cat "$TMP/listener.out" "$TMP/sender.out"
echo 'PASS r13196 native named service FIRST external routine integration'

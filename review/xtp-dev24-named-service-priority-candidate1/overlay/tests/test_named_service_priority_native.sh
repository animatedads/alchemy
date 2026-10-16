#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${REXX_BIN:?REXX_BIN must point to ooRexx rexx}"
TMP="$(mktemp -d)"
LPID=''
trap 'if [[ -n "$LPID" ]]; then kill "$LPID" 2>/dev/null || true; fi; rm -rf "$TMP"' EXIT
PORT="${XTP_TEST_PORT:-$((53000 + RANDOM % 1000))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export XTP_HEALTH_FILE="$TMP/health.tsv"
"$ROOT/bin/xtp-admin" route add NSPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" >/dev/null
export REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
"$ROOT/bin/xtp-listen" NSPEER --allow-services ssh.management --timeout-ms 3000 >"$TMP/listen.out" 2>"$TMP/listen.err" &
LPID=$!
for _ in $(seq 1 100); do
    grep -q XTP_LISTEN_READY "$TMP/listen.out" 2>/dev/null && break
    if ! kill -0 "$LPID" 2>/dev/null; then cat "$TMP/listen.err" >&2; exit 1; fi
    sleep .02
done
grep -q XTP_LISTEN_READY "$TMP/listen.out"
"$REXX_BIN" "$ROOT/tests/test_named_service_priority_native.rex" NSPEER named-priority
wait "$LPID"; LPID=''
grep -q 'service=ssh.management priority=static sort=7 data=named-priority' "$TMP/listen.out" || { cat "$TMP/listen.out" >&2; exit 1; }
echo 'PASS named-service FIRST carries XTP SORT priority through native ooRexx'

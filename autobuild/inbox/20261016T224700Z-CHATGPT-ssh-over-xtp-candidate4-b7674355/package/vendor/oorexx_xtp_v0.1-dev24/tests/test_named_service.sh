#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'kill ${LPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
export XTP_ROUTE_FILE="$TMP/routes.tsv"
export XTP_HEALTH_FILE="$TMP/health.tsv"
"$ROOT/bin/xtp-admin" route add service-node --layer 4 --carrier udp --to 127.0.0.1:44901 >/dev/null
"$ROOT/bin/xtp-listen" service-node --allow-services ssh.management --timeout-ms 3000 >"$TMP/listen.out" 2>"$TMP/listen.err" &
LPID=$!
for _ in $(seq 1 50); do grep -q XTP_LISTEN_READY "$TMP/listen.out" 2>/dev/null && break; sleep .02; done
"$ROOT/bin/xtp-connect" service-node --service ssh.management --message service-ok --timeout-ms 200 --retries 5 >"$TMP/send.out"
wait "$LPID"
grep -q 'service=ssh.management' "$TMP/listen.out"
grep -q 'data=service-ok' "$TMP/listen.out"
grep -q 'service=ssh.management' "$TMP/send.out"
echo 'PASS named XTP service FIRST admission and delivery'

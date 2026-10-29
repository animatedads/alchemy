#!/usr/bin/env bash
# dev31 ooRexx interactive-context test.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP ooRexx XtpSession (REXX_BIN unavailable)'; exit 0; fi
TMP="$(mktemp -d)"; trap 'kill ${SPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
PORT="${XTP_TEST_PORT:-$((53500 + RANDOM % 400))}"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add SESSPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" >/dev/null
export REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
"$REXX_BIN" "$ROOT/tests/test_xtp_session_rexx_server.rex" SESSPEER >"$TMP/server" 2>"$TMP/server.err" & SPID=$!
for _ in $(seq 1 200); do grep -q READY "$TMP/server" 2>/dev/null && break; sleep .01; done
rc=0
"$REXX_BIN" "$ROOT/tests/test_xtp_session_rexx_client.rex" SESSPEER || rc=$?
wait "$SPID" || rc=$?; SPID=
cat "$TMP/server" | grep -v READY
if [[ $rc -ne 0 ]]; then echo "FAIL ooRexx XtpSession (rc=$rc)"; cat "$TMP/server.err" >&2; exit 1; fi
echo 'PASS ooRexx XtpSession: refusal, binary messages, half-close, close, and read on one thread while writing on another'

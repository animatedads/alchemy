#!/usr/bin/env bash
# dev35: an XTP session as a SocketProvider byte stream (send, recv, bounded pump),
# protected by the service's profile.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP XTP session socket (REXX_BIN unavailable)'; exit 0; fi
if [[ -z "${SOCKET_PROVIDER_DIR:-}" ]]; then echo 'SKIP XTP session socket (SOCKET_PROVIDER_DIR not set)'; exit 0; fi
TMP="$(mktemp -d)"; trap 'kill ${SPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
PORT="$((56000 + RANDOM % 400))"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add SPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" >/dev/null
# this package's rexx directory first: SOCKET_PROVIDER_DIR carries an older XtpSocketProvider.cls
export REXX_PATH="$ROOT/rexx:$SOCKET_PROVIDER_DIR${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
umask 077
printf 'svc.stream 00000000000c0de5 encrypt aes256gcm %s\n' "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$TMP/stream.keys"
"$REXX_BIN" "$ROOT/tests/test_xtp_session_socket_server.rex" SPEER "$TMP/stream.keys" >"$TMP/server" 2>"$TMP/server.err" & SPID=$!
for _ in $(seq 1 400); do grep -q READY "$TMP/server" 2>/dev/null && break; sleep .05; done
rc=0
"$REXX_BIN" "$ROOT/tests/test_xtp_session_socket_client.rex" SPEER "$TMP/stream.keys" || rc=$?
wait "$SPID" || rc=$?; SPID=
grep -v READY "$TMP/server" || true
if [[ $rc -ne 0 ]]; then echo "FAIL XTP session socket (rc=$rc)"; cat "$TMP/server.err" >&2; exit 1; fi
echo 'PASS XTP session as a SocketProvider stream: send, recv, bounded pump, end of stream, encrypted by the service profile'

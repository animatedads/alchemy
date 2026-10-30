#!/usr/bin/env bash
# dev33: a protected one-way message between two ooRexx processes, keys from a key file.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP ooRexx protected messages (REXX_BIN unavailable)'; exit 0; fi
TMP="$(mktemp -d)"; trap 'kill ${SPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
PORT="$((55500 + RANDOM % 400))"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add MSGPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" >/dev/null
"$ROOT/bin/xtp-admin" route add MPPEER --layer 4 --carrier udp --to "127.0.0.1:$((PORT+1))" >/dev/null
"$ROOT/bin/xtp-admin" route add MPPEER --layer 4 --carrier udp --to "127.0.0.1:$((PORT+2))" >/dev/null
export REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
umask 077
printf 'svc.msg 00000000000c0de1 encrypt aes256gcm %s\n' "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$TMP/msg.keys"
"$REXX_BIN" "$ROOT/tests/test_xtp_message_keys_server.rex" MSGPEER "$TMP/msg.keys" MPPEER >"$TMP/server" 2>"$TMP/server.err" & SPID=$!
for _ in $(seq 1 400); do grep -q READY "$TMP/server" 2>/dev/null && break; sleep .05; done
rc=0
"$REXX_BIN" "$ROOT/tests/test_xtp_message_keys_client.rex" MSGPEER "$TMP/msg.keys" MPPEER || rc=$?
wait "$SPID" || rc=$?; SPID=
grep -v READY "$TMP/server" || true
[[ $(grep -c '^PASS server' "$TMP/server") == 2 ]] || rc=1
if [[ $rc -ne 0 ]]; then echo "FAIL ooRexx protected messages (rc=$rc)"; cat "$TMP/server.err" >&2; exit 1; fi
echo 'PASS ooRexx protected messages and multipath: the service profile applies on its own; with no keys left the message is refused'

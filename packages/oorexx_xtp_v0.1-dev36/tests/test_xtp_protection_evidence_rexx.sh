#!/usr/bin/env bash
# dev36: protection evidence for a named-service route (REQ-00001733): before
# the open from libxtp's route and key tables, after it bound to the session.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP XTP protection evidence (REXX_BIN unavailable)'; exit 0; fi
if [[ -z "${SOCKET_PROVIDER_DIR:-}" ]]; then echo 'SKIP XTP protection evidence (SOCKET_PROVIDER_DIR not set)'; exit 0; fi
TMP="$(mktemp -d)"; trap 'kill ${SPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
PORT="$((56400 + RANDOM % 400))"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add EPEER --layer 4 --carrier udp --to "127.0.0.1:$PORT" >/dev/null
# this package's rexx directory first: SOCKET_PROVIDER_DIR carries an older XtpSocketProvider.cls
export REXX_PATH="$ROOT/rexx:$SOCKET_PROVIDER_DIR${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
umask 077
rnd() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
S1="$(rnd)"; S2="$(rnd)"; S3="$(rnd)"; S4="$(rnd)"
{ printf 'svc.evid 00000000000e71d1 encrypt aes256gcm %s\n' "$S1"
  printf 'svc.evid2 00000000000e71d2 encrypt aes256gcm %s\n' "$S2"
  printf 'svc.auth 00000000000e71d3 authenticate chacha20poly1305 %s\n' "$S3"
  printf 'svc.evid4 00000000000e71d4 encrypt aes256gcm %s\n' "$S4"; } > "$TMP/evid.keys"
"$REXX_BIN" "$ROOT/tests/test_xtp_protection_evidence_server.rex" EPEER "$TMP/evid.keys" >"$TMP/server" 2>"$TMP/server.err" & SPID=$!
for _ in $(seq 1 400); do grep -q READY "$TMP/server" 2>/dev/null && break; sleep .05; done
rc=0
"$REXX_BIN" "$ROOT/tests/test_xtp_protection_evidence_client.rex" EPEER "$TMP/evid.keys" >"$TMP/client" 2>&1 || rc=$?
wait "$SPID" || rc=$?; SPID=
cat "$TMP/client"; grep -v READY "$TMP/server" || true
# no secret, in any form, in anything either side printed
for x in "$S1" "$S2" "$S3" "$S4"; do if grep -qi "$x" "$TMP/client" "$TMP/server"; then echo 'FAIL a key secret appears in the evidence output'; rc=1; fi; done
if grep -Eqi '[0-9a-f]{64}' "$TMP/client" "$TMP/server"; then echo 'FAIL a 64-hex-digit value appears in the evidence output'; rc=1; fi
if [[ $rc -ne 0 ]]; then echo "FAIL XTP protection evidence (rc=$rc)"; cat "$TMP/server.err" >&2; exit 1; fi
echo 'PASS XTP protection evidence: route evidence as open_session would choose; session evidence on both ends; retiring, not yet valid, expired, revoked and replaced keys shown at once; after close; exact values; fixed key sources; no secrets'

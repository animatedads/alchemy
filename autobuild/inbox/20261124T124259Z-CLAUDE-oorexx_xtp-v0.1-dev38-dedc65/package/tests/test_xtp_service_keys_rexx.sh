#!/usr/bin/env bash
# dev32: XTP service keys from LDAP, with key-file fallback, from ooRexx.
# Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
# Needs: REXX_BIN, LDAP_IDENTITY_ROOT, SOCKET_PROVIDER_DIR (Socket Provider src),
#        CRYPTO_ROOT (oorexx_crypto src), SECRET_BROKER_ROOT (src), ALCHEMY_OBJECTS_ROOT (src).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${REXX_BIN:-}" || ! -x "${REXX_BIN}" ]]; then echo 'SKIP ooRexx XTP service keys (REXX_BIN unavailable)'; exit 0; fi
for v in LDAP_IDENTITY_ROOT SOCKET_PROVIDER_DIR CRYPTO_ROOT SECRET_BROKER_ROOT ALCHEMY_OBJECTS_ROOT; do
  if [[ -z "${!v:-}" ]]; then echo "SKIP ooRexx XTP service keys ($v not set)"; exit 0; fi
done
TMP="$(mktemp -d)"; trap 'kill ${LPID:-} ${SPID:-} 2>/dev/null || true; rm -rf "$TMP"' EXIT
LPORT="$((54000 + RANDOM % 400))"; DEAD="$((54500 + RANDOM % 400))"; XPORT="$((55000 + RANDOM % 400))"
SECRET="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
export XTP_ROUTE_FILE="$TMP/routes.tsv"
"$ROOT/bin/xtp-admin" route add KEYPEER --layer 4 --carrier udp --to "127.0.0.1:$XPORT" >/dev/null
export REXX_PATH="$ROOT/rexx:$LDAP_IDENTITY_ROOT:$SOCKET_PROVIDER_DIR:$CRYPTO_ROOT:$SECRET_BROKER_ROOT:$ALCHEMY_OBJECTS_ROOT${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$ROOT/lib:${LD_LIBRARY_PATH:-}"
# the key files: the right secret for the active key, and a wrong one
umask 077
printf 'svc.ldap 00000000000a11c1 encrypt aes256gcm %s\n' "$SECRET" > "$TMP/good.keys"
printf 'svc.ldap 00000000000a11c1 encrypt aes256gcm %s\n' "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$TMP/wrong.keys"
"$REXX_BIN" "$ROOT/tests/xtp_keys_ldap_fixture.rex" "$LPORT" "$TMP/ldap.ready" 4 "$SECRET" >"$TMP/ldap.out" 2>&1 & LPID=$!
for _ in $(seq 1 1200); do [[ -f "$TMP/ldap.ready" ]] && break; kill -0 "$LPID" 2>/dev/null || { cat "$TMP/ldap.out" >&2; exit 1; }; sleep .05; done
[[ -f "$TMP/ldap.ready" ]] || { echo "FAIL LDAP fixture did not start within 60 s"; exit 1; }
"$REXX_BIN" "$ROOT/tests/test_xtp_service_keys_server.rex" KEYPEER "$LPORT" "$SECRET" >"$TMP/server" 2>"$TMP/server.err" & SPID=$!
for _ in $(seq 1 1200); do grep -q READY "$TMP/server" 2>/dev/null && break; kill -0 "$SPID" 2>/dev/null || break; sleep .05; done
rc=0
"$REXX_BIN" "$ROOT/tests/test_xtp_service_keys_client.rex" KEYPEER "$LPORT" "$DEAD" "$SECRET" "$TMP/good.keys" "$TMP/wrong.keys" || rc=$?
wait "$SPID" || rc=$?; SPID=
kill "$LPID" 2>/dev/null || true; wait "$LPID" 2>/dev/null || true; LPID=
grep -v READY "$TMP/server" || true
grep 'FIXTURE' "$TMP/ldap.out" || true
if [[ $rc -ne 0 ]]; then echo "FAIL ooRexx XTP service keys (rc=$rc)"; cat "$TMP/server.err" >&2; tail -20 "$TMP/ldap.out" >&2; exit 1; fi
echo 'PASS ooRexx XTP service keys: LDAP first, key file fallback (LDAP down, no keys, bad entry, raising source), wrong secret refused, profile kept with no keys, encrypted sessions over native libxtp'

#!/usr/bin/env bash
set -euo pipefail
REXX="${REXX:-rexx}"; ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
: "${FOREIGN_RUNTIME_ROOT:?}"; : "${RUNTIME_REFERENCE_ROOT:?}"
PORT="$(python3 - <<'PY'
import socket
s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()
PY
)"
TMP="$(mktemp -d)"; LOG="$TMP/server.log"; READY="$TMP/ready"
openssl req -x509 -newkey rsa:2048 -sha256 -days 1 -nodes -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1
FIXTURE=tests/ldaps_fixture_server.rex
if [[ -f "${OOREXX_CRYPTO_ROOT:-}/src/CryptoForeignRuntimeProvider.cls" ]]; then FIXTURE=tests/ldaps_fixture_server_fast.rex; fi
"$REXX" "$FIXTURE" "$PORT" "$READY" "$TMP/cert.pem" "$TMP/key.pem" "$ROOT/bridge" >"$LOG" 2>&1 & PID=$!
cleanup(){ kill "$PID" 2>/dev/null||true;wait "$PID" 2>/dev/null||true;rm -rf "$TMP";};trap cleanup EXIT
for _ in $(seq 1 300);do [[ -s "$READY" ]]&&break;kill -0 "$PID" 2>/dev/null||{ cat "$LOG" >&2;exit 1;};sleep .05;done
[[ -s "$READY" ]]||{ cat "$LOG" >&2;exit 1;}
timeout -k 3 30 "$REXX" tests/test_ldaps_oorexx_client.rex "$PORT" "$TMP/cert.pem" "$ROOT/bridge"||{ cat "$LOG" >&2;exit 1;}
timeout -k 3 30 python3 tests/python_ldap_ldaps.py "$PORT" "$TMP/cert.pem"||{ cat "$LOG" >&2;exit 1;}
for _ in $(seq 1 200);do ! kill -0 "$PID" 2>/dev/null&&break;sleep .05;done
if kill -0 "$PID" 2>/dev/null;then cat "$LOG" >&2;echo 'LDAPS fixture did not terminate' >&2;exit 1;fi
wait "$PID"
grep -q 'LDAP LDAPS FIXTURE DONE connections=2' "$LOG"||{ cat "$LOG" >&2;exit 1;}
echo 'LDAP LDAPS SERVER: OK'
trap - EXIT;rm -rf "$TMP"

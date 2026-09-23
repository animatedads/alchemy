#!/usr/bin/env bash
set -euo pipefail
REXX="${REXX:-rexx}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
: "${FOREIGN_RUNTIME_ROOT:?set FOREIGN_RUNTIME_ROOT for OpenSSL/Foreign Runtime TLS qualification}"
: "${RUNTIME_REFERENCE_ROOT:?set RUNTIME_REFERENCE_ROOT for Foreign Runtime qualification}"
PORT="$(python3 - <<'PYPORT'
import socket
s=socket.socket(); s.bind(('127.0.0.1',0)); print(s.getsockname()[1]); s.close()
PYPORT
)"
TMP="$(mktemp -d)"
LOG="$TMP/server.log"; READYFILE="$TMP/ready"
openssl req -x509 -newkey rsa:2048 -sha256 -days 1 -nodes \
  -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1
FIXTURE="tests/tls_fixture_server.rex"
if [[ -f "${OOREXX_CRYPTO_ROOT:-}/src/CryptoForeignRuntimeProvider.cls" && \
      -f "$RUNTIME_REFERENCE_ROOT/src/RuntimeImplementationReference.cls" && \
      -f "$FOREIGN_RUNTIME_ROOT/rexx/foreign.cls" ]]; then
  FIXTURE="tests/tls_fixture_server_fast.rex"
fi
"$REXX" "$FIXTURE" "$PORT" "$READYFILE" "$TMP/cert.pem" "$TMP/key.pem" "$ROOT/bridge" >"$LOG" 2>&1 &
PID=$!
cleanup() { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT
for _ in $(seq 1 200); do
  [[ -s "$READYFILE" ]] && break
  if ! kill -0 "$PID" 2>/dev/null; then cat "$LOG" >&2; exit 1; fi
  sleep 0.05
done
[[ -s "$READYFILE" ]] || { cat "$LOG" >&2; echo 'TLS wire server did not become ready' >&2; exit 1; }
timeout -k 3 30 "$REXX" tests/test_starttls_oorexx_client.rex "$PORT" "$TMP/cert.pem" "$ROOT/bridge" || { cat "$LOG" >&2; exit 1; }
timeout -k 3 30 python3 tests/python_ldap_starttls_sasl.py "$PORT" "$TMP/cert.pem" || { cat "$LOG" >&2; exit 1; }
for _ in $(seq 1 100); do ! kill -0 "$PID" 2>/dev/null && break; sleep 0.05; done
if kill -0 "$PID" 2>/dev/null; then cat "$LOG" >&2; echo 'TLS fixture did not terminate' >&2; exit 1; fi
wait "$PID"
grep -q 'LDAP TLS FIXTURE DONE connections=2' "$LOG" || { cat "$LOG" >&2; exit 1; }
echo 'LDAP STARTTLS SERVER: OK'
trap - EXIT
rm -rf "$TMP"

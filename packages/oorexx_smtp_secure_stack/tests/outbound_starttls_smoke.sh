#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REXX_BIN="${REXX_BIN:-rexx}"
WORK="${TMPDIR:-/tmp}/oorexx-smtp-outbound-tls-$$"
mkdir -p "$WORK"
cleanup(){ [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT
cat > "$WORK/openssl.cnf" <<'CNF'
[req]
distinguished_name=dn
x509_extensions=v3
prompt=no
[dn]
CN=localhost
[v3]
subjectAltName=DNS:localhost
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
basicConstraints=CA:TRUE
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -config "$WORK/openssl.cnf" -keyout "$WORK/key.pem" -out "$WORK/cert.pem" >/dev/null 2>&1
python3 "$ROOT/tests/outbound_starttls_fixture.py" "$WORK/ready" "$WORK/cert.pem" "$WORK/key.pem" "$WORK/capture.eml" >"$WORK/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 100); do [[ -s "$WORK/ready" ]] && break; sleep .05; done
export SMTP_TEST_TMP="$WORK/store"
export SMTP_TEST_CA="$WORK/cert.pem"
export SMTP_TEST_BRIDGE="$ROOT/bridge"
cd "$ROOT"
"$REXX_BIN" tests/test_outbound_live_starttls.rex
wait "$pid"
grep -q 'hello from dev5' "$WORK/capture.eml"
echo "outbound_starttls_smoke: PASS"

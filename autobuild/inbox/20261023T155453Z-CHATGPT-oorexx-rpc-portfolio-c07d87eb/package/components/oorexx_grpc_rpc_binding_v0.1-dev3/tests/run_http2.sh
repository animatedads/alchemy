#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${OOREXX_RUNTIME_ROOT:?required}"
: "${RPC_CORE_ROOT:?required}"
: "${SERIALIZATION_ROOT:?required}"
command -v python3 >/dev/null 2>&1 || { echo 'SKIP live HTTP/2: Python test fixture unavailable'; exit 0; }
python3 -c 'import h2' 2>/dev/null || { echo 'SKIP live HTTP/2: hyper-h2 test fixture unavailable'; exit 0; }
TEST_TMP=$(mktemp -d)
SERVER_PID=''
cleanup(){ [ -z "$SERVER_PID" ] || kill "$SERVER_PID" 2>/dev/null || :; rm -rf "$TEST_TMP"; }
trap cleanup EXIT HUP INT TERM
python3 "$HERE/tests/fixtures/h2_grpc_test_server.py" "$TEST_TMP/port" >"$TEST_TMP/server.log" 2>&1 & SERVER_PID=$!
i=0
while [ ! -s "$TEST_TMP/port" ] && [ "$i" -lt 60 ]; do sleep .1; i=$((i+1)); done
if [ ! -s "$TEST_TMP/port" ]; then cat "$TEST_TMP/server.log"; exit 1; fi
port=$(cat "$TEST_TMP/port")
export LD_LIBRARY_PATH="$HERE/native:$OOREXX_RUNTIME_ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE/src:$RPC_CORE_ROOT/src:$SERIALIZATION_ROOT/src:$OOREXX_RUNTIME_ROOT/usr/local/bin${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx" "$HERE/tests/test_http2.rex" "$port"
if [ -n "${CONNECT_SELECTOR_ROOT:-}" ]; then
 export REXX_PATH="$CONNECT_SELECTOR_ROOT/src:$REXX_PATH"
 "$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx" "$HERE/tests/test_http2_connect.rex" "$port"
fi

# Optional independent TLS test: an unknown self-signed certificate must fail,
# while explicitly trusted CA verification plus ALPN h2 must succeed.
if command -v openssl >/dev/null 2>&1; then
  kill "$SERVER_PID" 2>/dev/null || :
  wait "$SERVER_PID" 2>/dev/null || :
  SERVER_PID=''
  openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
    -keyout "$TEST_TMP/key.pem" -out "$TEST_TMP/cert.pem" \
    -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
    >"$TEST_TMP/openssl.log" 2>&1
  rm -f "$TEST_TMP/port"
  python3 "$HERE/tests/fixtures/h2_grpc_test_server.py" "$TEST_TMP/port" --tls \
    "$TEST_TMP/cert.pem" "$TEST_TMP/key.pem" >"$TEST_TMP/tlsserver.log" 2>&1 & SERVER_PID=$!
  i=0
  while [ ! -s "$TEST_TMP/port" ] && [ "$i" -lt 60 ]; do sleep .1; i=$((i+1)); done
  if [ ! -s "$TEST_TMP/port" ]; then cat "$TEST_TMP/tlsserver.log"; exit 1; fi
  "$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx" "$HERE/tests/test_http2_tls.rex" \
    "$(cat "$TEST_TMP/port")" "$TEST_TMP/cert.pem"
else
  echo 'SKIP TLS fixture: openssl binary unavailable'
fi

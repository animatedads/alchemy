#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OOREXX_ROOT=${OOREXX_ROOT:-/usr/local}
REXX=${REXX:-$OOREXX_ROOT/bin/rexx}
OOREXX_INCLUDE=${OOREXX_INCLUDE:-$OOREXX_ROOT/include}
PORT=${QUIC_TEST_PORT:-28443}
WORK=${QUIC_TEST_WORK:-"$ROOT/.qualification"}
rm -rf "$WORK"
mkdir -p "$WORK"

printf '%s\n' "[1/6] build native OpenSSL QUIC binding"
make -C "$ROOT" clean all OOREXX_INCLUDE="$OOREXX_INCLUDE"

printf '%s\n' "[2/6] native library dependency check"
ldd "$ROOT/lib/liboorexx_quic_native.so" | grep -E 'libssl|libcrypto' >/dev/null

printf '%s\n' "[3/6] generate local qualification identity"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -subj '/CN=localhost' \
  -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1' \
  -keyout "$WORK/server.key" -out "$WORK/server.crt" >/dev/null 2>&1

export LD_LIBRARY_PATH="$ROOT/lib:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/vendor/socket_provider${REXX_PATH:+:$REXX_PATH}"

printf '%s\n' "[4/6] ooRexx contract test"
"$REXX" "$ROOT/tests/test_contract.rex"
printf '%s\n' "[5/6] SocketProvider dev14 negotiation contract"
"$REXX" "$ROOT/tests/test_negotiation_dev2.rex"

printf '%s\n' "[6/6] live QUIC/TLS 1.3 loopback + readiness/tryAccept"
"$REXX" "$ROOT/tests/quic_echo_server.rex" "$PORT" "$WORK/server.crt" "$WORK/server.key" >"$WORK/server.log" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT INT TERM
sleep 1
"$REXX" "$ROOT/tests/quic_echo_client.rex" "$PORT" "$WORK/server.crt" | tee "$WORK/client.log"
wait "$SERVER_PID"
trap - EXIT INT TERM
cat "$WORK/server.log"
printf '%s\n' "PASS: real QUIC socket provider round-trip"

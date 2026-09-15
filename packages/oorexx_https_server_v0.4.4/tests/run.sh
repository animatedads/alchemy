#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OOREXX="${OOREXX:-}"
if [[ -z "$OOREXX" ]]; then
  if command -v rexx >/dev/null 2>&1; then
    REXX_BIN="$(command -v rexx)"
    OOREXX="$(cd "$(dirname "$REXX_BIN")/.." && pwd)"
  else
    echo "FAIL ooRexx not found; set OOREXX" >&2
    exit 2
  fi
fi
REXX="$OOREXX/bin/rexx"
[[ -x "$REXX" ]] || { echo "FAIL missing $REXX" >&2; exit 2; }
LIBDIR="$OOREXX/lib"; [[ -d "$OOREXX/lib64" ]] && LIBDIR="$OOREXX/lib64"
export LD_LIBRARY_PATH="$ROOT/vendor/foreign_runtime_v0.17.1/build:$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/rexx:$ROOT/vendor/foreign_runtime_v0.17.1/rexx:$OOREXX/bin${REXX_PATH:+:$REXX_PATH}"

TMP="$(mktemp -d)"
PIDS=()
cleanup() {
  # ooRexx activities blocked in RxSock accept/read may not leave promptly on
  # SIGTERM on every debug-runtime/platform combination.  Never let the test
  # harness hang after it has already produced its verdict.
  for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done
  for _ in $(seq 1 20); do
    alive=0
    for p in "${PIDS[@]:-}"; do
      if kill -0 "$p" 2>/dev/null; then alive=1; break; fi
    done
    [[ $alive -eq 0 ]] && break
    sleep 0.05
  done
  for p in "${PIDS[@]:-}"; do
    if kill -0 "$p" 2>/dev/null; then kill -KILL "$p" 2>/dev/null || true; fi
  done
  for p in "${PIDS[@]:-}"; do wait "$p" 2>/dev/null || true; done
  rm -rf "$TMP"
}
trap cleanup EXIT

fail(){ echo "FAIL $*" >&2; exit 1; }
pass(){ echo "PASS $*"; }

wait_ready(){
  local pid="$1" log="$2"
  for _ in $(seq 1 80); do
    grep -q 'OOREXX_HTTPS_READY' "$log" && return 0
    kill -0 "$pid" 2>/dev/null || { cat "$log" >&2; return 1; }
    sleep 0.1
  done
  cat "$log" >&2
  return 1
}

start_server(){
  local port="$1" cert="$2" key="$3" log="$4"; shift 4
  OOREXX="$OOREXX" "$ROOT/start.sh" --cert "$cert" --key "$key" --bind 127.0.0.1 --port "$port" --quiet "$@" >"$log" 2>&1 &
  LAST_PID=$!
  PIDS+=("$LAST_PID")
  wait_ready "$LAST_PID" "$log" || fail "server did not become ready"
}

"$REXX" "$ROOT/tests/test_http_util.rex"
"$REXX" "$ROOT/tests/test_connection_queue.rex"
"$REXX" "$ROOT/tests/test_tls_gate.rex"
PROBE_OUT="$("$REXX" "$ROOT/tests/probe_tls_context.rex")"
echo "$PROBE_OUT"
grep -q 'FOREIGN_RUNTIME 0.17.1' <<<"$PROBE_OUT" || fail "Foreign Runtime v0.17.1 not active"
grep -q 'THREADING thread-safe' <<<"$PROBE_OUT" || fail "OpenSSL provider thread-safe contract not active"
pass "ooRexx API, TLS context, and provider-threading probes"

# v0.2 regression lock: v0.11 dynamic arity should be used where libffi is present.
grep -q '"ctx_ctrl"' "$ROOT/bridge/openssl_tls.bridge.json" || fail "missing four-argument SSL_CTX_ctrl binding"

# v0.4.4 transport regression lock: OpenSSL must never receive the accepted
# socket descriptor. TLS records cross memory BIOs; RxSock alone owns network I/O.
if grep -q '"ssl_set_fd"\|"ssl_accept"' "$ROOT/bridge/openssl_tls.bridge.json"; then
  fail "legacy SSL_set_fd/SSL_accept convenience path reappeared"
fi
if grep -q '"bio_new_socket"' "$ROOT/bridge/openssl_bio.bridge.json"; then
  fail "OpenSSL socket BIO path reappeared"
fi
grep -q '"bio_s_mem"' "$ROOT/bridge/openssl_bio.bridge.json" || fail "missing BIO_s_mem binding"
grep -q '"bio_new"' "$ROOT/bridge/openssl_bio.bridge.json" || fail "missing BIO_new binding"
grep -q '"bio_read"' "$ROOT/bridge/openssl_bio.bridge.json" || fail "missing BIO_read binding"
grep -q '"bio_write"' "$ROOT/bridge/openssl_bio.bridge.json" || fail "missing BIO_write binding"
grep -q '"ssl_set0_rbio"' "$ROOT/bridge/openssl_tls.bridge.json" || fail "missing explicit read BIO binding"
grep -q '"ssl_set0_wbio"' "$ROOT/bridge/openssl_tls.bridge.json" || fail "missing explicit write BIO binding"
grep -q '"ssl_do_handshake"' "$ROOT/bridge/openssl_tls.bridge.json" || fail "missing explicit handshake binding"
grep -q 'RxSock is the sole network' "$ROOT/rexx/https_server.cls" || fail "memory-BIO ownership invariant missing"
pass "memory-BIO TLS pump keeps network I/O in RxSock"

# SSL_do_handshake WANT_READ/WANT_WRITE remain retryable state-machine results.
# v0.4.4 feeds WANT_READ from RxSock into the memory BIO and drains encrypted
# output back to RxSock rather than allowing OpenSSL to touch the descriptor.
grep -q 'handshakeRetries=handshakeRetries+1' "$ROOT/rexx/https_server.cls" || fail "handshake retry observability missing"
grep -q 'receiveEncrypted' "$ROOT/rexx/https_server.cls" || fail "memory-BIO input pump missing"
grep -q 'drainOutput' "$ROOT/rexx/https_server.cls" || fail "memory-BIO output pump missing"
pass "retryable OpenSSL handshake states locked"

# v0.4.4 returns to one serialized Foreign Runtime/OpenSSL lane because native
# calls are now pure in-memory TLS operations. Socket waits are nonblocking and
# occur outside the lane in RxSock select().
grep -q "nativeTlsConcurrency=1" "$ROOT/rexx/https_server.cls" || fail "default native TLS lane is not serialized"
grep -q "requires nativeTlsConcurrency=1" "$ROOT/rexx/https_server.cls" || fail "memory-BIO one-lane safety constraint missing"
grep -q "socket~ioctl('FIONBIO',1)" "$ROOT/rexx/https_server.cls" || fail "accepted sockets are not made nonblocking"
grep -q 'socket~select(reads,writes,excepts,timeoutSeconds)' "$ROOT/rexx/https_server.cls" || fail "TLS readiness does not use RxSock select"
grep -q 'sslStep' "$ROOT/rexx/https_server.cls" || fail "SSL operation/error classification is not kept inside native gate"
pass "serialized memory-BIO native TLS boundary locked"

# v0.4.4 admission regression: accepted sockets must enter a bounded FIFO and
# be processed by a fixed worker set.  No per-peer conn~start fan-out is allowed.
grep -q 'connectionWorkers=16' "$ROOT/rexx/https_server.cls" || fail "default fixed connection worker count missing"
grep -q 'maxPendingConnections=64' "$ROOT/rexx/https_server.cls" || fail "bounded accepted-connection queue missing"
grep -q 'class HttpsConnectionQueue' "$ROOT/rexx/https_server.cls" || fail "accepted-connection FIFO class missing"
grep -q 'conn~run' "$ROOT/rexx/https_server.cls" || fail "worker does not run connection synchronously"
if grep -q "conn~start('run')" "$ROOT/rexx/https_server.cls"; then
  fail "untrusted per-accepted-socket activity fan-out reappeared"
fi
grep -q 'if protocol<>.*then do' "$ROOT/rexx/https_server.cls" || fail "failed handshake still performs TLS shutdown"
grep -q 'logHandshakeAbort' "$ROOT/rexx/https_server.cls" || fail "routine handshake abort classification missing"
pass "bounded pre-TLS connection admission and fast-abort cleanup locked"

# Basic certificate.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/server.key" -out "$TMP/server.pem" -days 1 -subj '/CN=localhost' >/dev/null 2>&1
PORT=$((22000 + RANDOM % 10000))
start_server "$PORT" "$TMP/server.pem" "$TMP/server.key" "$TMP/server.log"
PID1=$LAST_PID
grep -q 'foreign=0.17.1' "$TMP/server.log" || fail "ready line missing Foreign Runtime v0.17.1"
grep -q 'dispatcher=' "$TMP/server.log" || fail "ready line missing dispatcher"
grep -q 'threading=thread-safe' "$TMP/server.log" || fail "ready line missing explicit provider threading"
grep -q 'native=bounded-1-nonblocking' "$TMP/server.log" || fail "ready line missing bounded native-concurrency policy"
grep -q 'nativeLanes=1' "$TMP/server.log" || fail "ready line missing native lane count"
grep -q 'io=memory-bio-rxsock' "$TMP/server.log" || fail "ready line missing memory-BIO I/O model"
grep -q 'workers=16' "$TMP/server.log" || fail "ready line missing fixed connection worker count"
grep -q 'queue=64' "$TMP/server.log" || fail "ready line missing accepted-connection queue capacity"
grep -q 'policy=' "$TMP/server.log" || fail "ready line missing TLS policy"
grep -q 'generation=1' "$TMP/server.log" || fail "ready line missing initial TLS generation"
pass "runtime dispatcher, provider/native threading policies, TLS policy, and generation observability"

expected='{"status":"ok","server":"oorexx-https/0.4.4"}'
actual="$(curl -skS --http1.1 "https://127.0.0.1:$PORT/healthz")"
[[ "$actual" == "$expected" ]] || fail "health response mismatch: $actual"
pass "TLS HTTP/1.1 health route"

# Binary-exact request/response body, including embedded NUL.
printf 'A\000B\001C\377Z' >"$TMP/binary.in"
curl -skS --http1.1 -H 'Content-Type: application/octet-stream' --data-binary @"$TMP/binary.in" "https://127.0.0.1:$PORT/echo" >"$TMP/binary.out"
cmp "$TMP/binary.in" "$TMP/binary.out" >/dev/null || fail "binary echo mismatch"
pass "binary-exact TLS body path"

# Exercise memory-BIO pumping across many TLS records, including explicit
# 100-continue handling. This catches partial BIO drain/feed defects that a
# tiny request cannot expose.
dd if=/dev/urandom of="$TMP/large-binary.in" bs=131072 count=1 status=none
curl -skS --http1.1 -H 'Content-Type: application/octet-stream' -H 'Expect: 100-continue' \
  -D "$TMP/large.headers" --data-binary @"$TMP/large-binary.in" \
  "https://127.0.0.1:$PORT/echo" >"$TMP/large-binary.out"
cmp "$TMP/large-binary.in" "$TMP/large-binary.out" >/dev/null || fail "large memory-BIO echo mismatch"
grep -q '^HTTP/1.1 100 Continue' "$TMP/large.headers" || fail "100-continue interim response missing"
grep -q '^HTTP/1.1 200 OK' "$TMP/large.headers" || fail "large memory-BIO final response missing"
pass "multi-record memory-BIO body and 100-continue path"

# HEAD is bodyless but keeps the GET representation length.
curl -skSI --http1.1 "https://127.0.0.1:$PORT/" >"$TMP/head.out"
grep -q '^HTTP/1.1 200 OK' "$TMP/head.out" || fail "HEAD status"
grep -qi '^Content-Length: 20' "$TMP/head.out" || fail "HEAD content length"
pass "HEAD semantics"

# Method discovery / 405.
curl -skS --http1.1 -D "$TMP/method.headers" -o "$TMP/method.body" -X POST "https://127.0.0.1:$PORT/" || true
grep -q '^HTTP/1.1 405 Method Not Allowed' "$TMP/method.headers" || fail "405 status"
grep -qi '^Allow: .*GET' "$TMP/method.headers" || fail "405 Allow header"
pass "exact routing and 405"

# HTTP request smuggling hardening: duplicate CL and any Transfer-Encoding fail closed.
printf 'POST /echo HTTP/1.1\r\nHost: localhost\r\nContent-Length: 1\r\nContent-Length: 1\r\nConnection: close\r\n\r\nx' \
  | openssl s_client -quiet -connect "127.0.0.1:$PORT" 2>/dev/null >"$TMP/dupcl.out" || true
grep -q '^HTTP/1.1 400 Bad Request' "$TMP/dupcl.out" || fail "duplicate Content-Length not rejected"
printf 'POST /echo HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n0\r\n\r\n' \
  | openssl s_client -quiet -connect "127.0.0.1:$PORT" 2>/dev/null >"$TMP/te.out" || true
grep -q '^HTTP/1.1 501 Not Implemented' "$TMP/te.out" || fail "Transfer-Encoding not rejected"
pass "anti-smuggling framing rules"

# HTTP/1.1 Host requirement.
printf 'GET / HTTP/1.1\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect "127.0.0.1:$PORT" 2>/dev/null >"$TMP/nohost.out" || true
grep -q '^HTTP/1.1 400 Bad Request' "$TMP/nohost.out" || fail "missing Host not rejected"
pass "Host requirement"

# Two pipelined requests on one TLS connection exercise carry-over and keep-alive.
printf 'GET /healthz HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\nGET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect "127.0.0.1:$PORT" 2>/dev/null >"$TMP/pipeline.out" || true
[[ "$(grep -ao 'HTTP/1.1 200 OK' "$TMP/pipeline.out" | wc -l)" -eq 2 ]] || fail "keep-alive/pipeline did not return two responses"
pass "keep-alive and pipelined carry-over"

# TLS 1.2 and 1.3 both work.
printf 'GET /healthz HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -tls1_2 -connect "127.0.0.1:$PORT" 2>/dev/null >"$TMP/tls12.out" || true
grep -q '^HTTP/1.1 200 OK' "$TMP/tls12.out" || fail "TLS 1.2 request failed"
printf 'GET /healthz HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -tls1_3 -connect "127.0.0.1:$PORT" 2>/dev/null >"$TMP/tls13.out" || true
grep -q '^HTTP/1.1 200 OK' "$TMP/tls13.out" || fail "TLS 1.3 request failed"
pass "TLS 1.2 and TLS 1.3"

# Everything above is positive protocol traffic; it must not have generated
# a server-side error before the deliberate bad handshake below.
if grep -q '^ERROR ' "$TMP/server.log"; then
  cat "$TMP/server.log" >&2
  fail "positive TLS/HTTP traffic logged an error"
fi
pass "positive traffic leaves server error log clean"

# Force a TLS 1.1-capable client security level; the server must reject it.
set +e
timeout 5 openssl s_client -connect "127.0.0.1:$PORT" -tls1_1 -cipher 'DEFAULT:@SECLEVEL=0' </dev/null >"$TMP/tls11.out" 2>"$TMP/tls11.err"
TLS11_RC=$?
set -e
[[ $TLS11_RC -ne 0 ]] || fail "TLS 1.1 unexpectedly completed"
if ! grep -Eq 'alert protocol version|no protocols available|unsupported protocol' "$TMP/tls11.err"; then
  fail "TLS 1.1 failed for an unexpected reason"
fi
pass "TLS 1.0/1.1 floor"

# Concurrent ooRexx activities + Foreign Runtime invocation.
mkdir "$TMP/concurrent"
CPIDS=()
for n in $(seq 1 16); do
  (curl -skS --http1.1 "https://127.0.0.1:$PORT/healthz" >"$TMP/concurrent/$n") &
  CPIDS+=("$!")
done
for p in "${CPIDS[@]}"; do wait "$p"; done
for n in $(seq 1 16); do
  [[ "$(cat "$TMP/concurrent/$n")" == "$expected" ]] || fail "concurrent response $n"
done
pass "16 concurrent HTTPS clients"

# v0.4.4 host-portability stress: exercise repeated successful TLS handshakes
# while peers also reset/abort during handshake.  The sealed v0.3 candidate
# was independently observed to segfault on one OpenSSL 3.5.3 host during the
# 16-client phase after connection resets; this separate server deliberately
# amplifies that lifecycle pressure without contaminating the main log-count
# assertions below.
STRESS_PORT=$((45000 + RANDOM % 10000))
start_server "$STRESS_PORT" "$TMP/server.pem" "$TMP/server.key" "$TMP/stress.log"
STRESS_PID=$LAST_PID
for wave in $(seq 1 8); do
  GOOD_PIDS=()
  RESET_PIDS=()
  for n in $(seq 1 16); do
    (
      body="$(curl -skS --connect-timeout 2 --max-time 5 --http1.1 "https://127.0.0.1:$STRESS_PORT/healthz")"
      [[ "$body" == "$expected" ]]
    ) &
    GOOD_PIDS+=("$!")
  done
  for n in $(seq 1 16); do
    (
      exec 9<>"/dev/tcp/127.0.0.1/$STRESS_PORT" || exit 0
      printf '\026\003\001\000' >&9 || true
      exec 9>&- || true
      exec 9<&- || true
    ) 2>/dev/null &
    RESET_PIDS+=("$!")
  done
  for p in "${GOOD_PIDS[@]}"; do wait "$p" || fail "stress good client failed in wave $wave"; done
  for p in "${RESET_PIDS[@]}"; do wait "$p" || true; done
  kill -0 "$STRESS_PID" 2>/dev/null || { cat "$TMP/stress.log" >&2; fail "stress server died in wave $wave"; }
done
[[ "$(curl -skS --connect-timeout 2 --max-time 5 "https://127.0.0.1:$STRESS_PORT/healthz")" == "$expected" ]] || { cat "$TMP/stress.log" >&2; fail "stress server did not survive reset storm"; }
if grep -q 'TLS peer closed during handshake' "$TMP/stress.log"; then
  fail "routine reset/abort peers polluted the server error log"
fi
pass "8-wave concurrent TLS plus reset/abort stress with bounded admission"

# A handler exception is contained as 500 and the listener remains usable.
FAULT_PORT=$((43000 + RANDOM % 8000))
( cd "$ROOT/tests" && "$REXX" fault_server.rex "$TMP/server.pem" "$TMP/server.key" "$FAULT_PORT" ) >"$TMP/fault.log" 2>&1 &
FAULT_PID=$!
PIDS+=("$FAULT_PID")
wait_ready "$FAULT_PID" "$TMP/fault.log" || fail "fault-test server did not become ready"
curl -skS -D "$TMP/fault.headers" -o "$TMP/fault.body" "https://127.0.0.1:$FAULT_PORT/boom" || true
grep -q '^HTTP/1.1 500 Internal Server Error' "$TMP/fault.headers" || { cat "$TMP/fault.log" >&2; fail "handler exception was not converted to 500"; }
[[ "$(curl -skS "https://127.0.0.1:$FAULT_PORT/ok")" == 'ok' ]] || fail "listener did not survive handler failure"
pass "handler exception containment"

# v0.4 request interception boundary: before hooks run in registration order,
# after hooks unwind in reverse order, a before hook can short-circuit routing,
# route/interceptor failures remain contained, and transport-native objects are
# not passed into the interceptor contract.
INTERCEPT_PORT=$((44000 + RANDOM % 900))
( cd "$ROOT/tests" && "$REXX" interceptor_server.rex "$TMP/server.pem" "$TMP/server.key" "$INTERCEPT_PORT" ) >"$TMP/interceptor.log" 2>&1 &
INTERCEPT_PID=$!
PIDS+=("$INTERCEPT_PID")
wait_ready "$INTERCEPT_PID" "$TMP/interceptor.log" || fail "interceptor-test server did not become ready"

curl -skS -D "$TMP/context.headers" -o "$TMP/context.body" "https://127.0.0.1:$INTERCEPT_PORT/context"
grep -q 'before=AB' "$TMP/context.body" || fail "interceptor before order/context propagation mismatch"
grep -q 'tls=TLSv1\.[23]' "$TMP/context.body" || fail "exchange context missing TLS protocol projection"
grep -q 'generation=1' "$TMP/context.body" || fail "exchange context missing TLS generation projection"
grep -qi '^X-After-Order: BA' "$TMP/context.headers" || fail "interceptor reverse after order mismatch"
grep -qi '^X-Request-Id: [0-9]' "$TMP/context.headers" || fail "interceptor request id header missing"
pass "request context and ordered before/after interceptor pipeline"

curl -skS -D "$TMP/deny.headers" -o "$TMP/deny.body" "https://127.0.0.1:$INTERCEPT_PORT/deny" || true
grep -q '^HTTP/1.1 403 Forbidden' "$TMP/deny.headers" || fail "interceptor short-circuit status mismatch"
[[ "$(cat "$TMP/deny.body")" == 'denied' ]] || fail "interceptor short-circuit body mismatch"
grep -qi '^X-After-Order: A' "$TMP/deny.headers" || fail "short-circuit did not unwind entered interceptor"
! grep -q 'ROUTE-MUST-NOT-RUN' "$TMP/deny.body" || fail "short-circuited route executed"
pass "interceptor short-circuit bypasses route and unwinds entered hooks"

curl -skS -D "$TMP/route-fail.headers" -o /dev/null "https://127.0.0.1:$INTERCEPT_PORT/route-fail" || true
grep -q '^HTTP/1.1 500 Internal Server Error' "$TMP/route-fail.headers" || fail "route failure not contained under interceptor pipeline"
grep -qi '^X-After-Order: BA' "$TMP/route-fail.headers" || fail "after hooks did not observe contained route failure"

curl -skS -D "$TMP/before-fail.headers" -o /dev/null "https://127.0.0.1:$INTERCEPT_PORT/before-fail" || true
grep -q '^HTTP/1.1 500 Internal Server Error' "$TMP/before-fail.headers" || fail "before-interceptor failure not contained"
grep -qi '^X-After-Order: A' "$TMP/before-fail.headers" || fail "completed outer interceptor did not unwind after inner before failure"

curl -skS -D "$TMP/after-fail.headers" -o /dev/null "https://127.0.0.1:$INTERCEPT_PORT/after-fail" || true
grep -q '^HTTP/1.1 500 Internal Server Error' "$TMP/after-fail.headers" || fail "after-interceptor failure not contained"
grep -qi '^X-After-Order: BA' "$TMP/after-fail.headers" || fail "outer after interceptor did not run after inner after failure"
[[ "$(curl -skS "https://127.0.0.1:$INTERCEPT_PORT/ok")" == 'ok' ]] || fail "listener did not survive interceptor failures"
pass "route and interceptor failure containment with outer unwind"

[[ "$(curl -skS "https://127.0.0.1:$INTERCEPT_PORT/late-register")" == 'immutable' ]] || fail "interceptor registration was mutable after listener start"
pass "interceptor registration immutable after start"

mkdir -p "$TMP/request-ids"
IPIDS=()
for n in $(seq 1 12); do
  (curl -skS "https://127.0.0.1:$INTERCEPT_PORT/context" >"$TMP/request-ids/$n") &
  IPIDS+=("$!")
done
for p in "${IPIDS[@]}"; do wait "$p"; done
sed -n 's/^request=\([0-9][0-9]*\).*/\1/p' "$TMP"/request-ids/* | sort -n >"$TMP/request-ids.list"
[[ "$(wc -l < "$TMP/request-ids.list")" -eq 12 ]] || fail "request context ids missing under concurrency"
[[ "$(sort -u "$TMP/request-ids.list" | wc -l)" -eq 12 ]] || fail "request context ids not unique under concurrency"
pass "concurrent request-context identity"

grep -q '^ERROR route exception for GET /route-fail:' "$TMP/interceptor.log" || fail "missing contained route failure diagnostic"
grep -q '^ERROR interceptor before exception for GET /before-fail:' "$TMP/interceptor.log" || fail "missing before-interceptor failure diagnostic"
grep -q '^ERROR interceptor after exception for GET /after-fail:' "$TMP/interceptor.log" || fail "missing after-interceptor failure diagnostic"
pass "interceptor failure diagnostics"

# mTLS: build a local CA, server cert, and client cert.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/ca.key" -out "$TMP/ca.pem" -days 1 -subj '/CN=ooRexx HTTPS Test CA' >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout "$TMP/mtls-server.key" -out "$TMP/mtls-server.csr" -subj '/CN=localhost' >/dev/null 2>&1
openssl x509 -req -in "$TMP/mtls-server.csr" -CA "$TMP/ca.pem" -CAkey "$TMP/ca.key" -CAcreateserial -out "$TMP/mtls-server.pem" -days 1 >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes -keyout "$TMP/client.key" -out "$TMP/client.csr" -subj '/CN=test-client' >/dev/null 2>&1
openssl x509 -req -in "$TMP/client.csr" -CA "$TMP/ca.pem" -CAkey "$TMP/ca.key" -CAcreateserial -out "$TMP/client.pem" -days 1 >/dev/null 2>&1
PORT2=$((32000 + RANDOM % 10000))
start_server "$PORT2" "$TMP/mtls-server.pem" "$TMP/mtls-server.key" "$TMP/mtls.log" --client-ca "$TMP/ca.pem" --require-client-cert
PID2=$LAST_PID
set +e
curl -skS --max-time 5 "https://127.0.0.1:$PORT2/healthz" >"$TMP/no-client.out" 2>"$TMP/no-client.err"
NOCLIENT_RC=$?
set -e
[[ $NOCLIENT_RC -ne 0 ]] || fail "mTLS server accepted an unauthenticated client"
actual="$(curl -skS --cert "$TMP/client.pem" --key "$TMP/client.key" "https://127.0.0.1:$PORT2/healthz")"
[[ "$actual" == "$expected" ]] || fail "mTLS client response mismatch"
pass "required client certificate verification"

# The main server has exactly one intentional handshake failure: TLS 1.1.
MAIN_ERROR_COUNT="$(grep -c '^ERROR ' "$TMP/server.log" || true)"
[[ "$MAIN_ERROR_COUNT" -eq 1 ]] || { cat "$TMP/server.log" >&2; fail "unexpected main-server error count: $MAIN_ERROR_COUNT"; }
grep -q '^ERROR TLS handshake failed from ' "$TMP/server.log" || { cat "$TMP/server.log" >&2; fail "missing TLS rejection diagnostic"; }
grep -q 'SSL_do_handshake rc=.*error=SSL_ERROR_.*state=' "$TMP/server.log" || { cat "$TMP/server.log" >&2; fail "TLS diagnostic lacks OpenSSL classification/state"; }
pass "TLS rejection diagnostic shape"

# The mTLS server likewise has exactly one intentional failure: no client cert.
MTLS_ERROR_COUNT="$(grep -c '^ERROR ' "$TMP/mtls.log" || true)"
[[ "$MTLS_ERROR_COUNT" -eq 1 ]] || { cat "$TMP/mtls.log" >&2; fail "unexpected mTLS-server error count: $MTLS_ERROR_COUNT"; }
grep -q '^ERROR TLS handshake failed from ' "$TMP/mtls.log" || { cat "$TMP/mtls.log" >&2; fail "missing mTLS rejection diagnostic"; }
pass "mTLS rejection diagnostic shape"

# v0.3 lifecycle retained in v0.3.1: atomic TLS generation replacement keeps the old context
# pinned for an already-established connection, while new connections observe
# the new certificate. A failed replacement must leave the current generation
# untouched.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/life1.key" -out "$TMP/life1.pem" -days 1 -subj '/CN=generation-one' >/dev/null 2>&1
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$TMP/life2.key" -out "$TMP/life2.pem" -days 1 -subj '/CN=generation-two' >/dev/null 2>&1
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$TMP/bad.key" >/dev/null 2>&1
FP1="$(openssl x509 -in "$TMP/life1.pem" -noout -fingerprint -sha256 | cut -d= -f2)"
FP2="$(openssl x509 -in "$TMP/life2.pem" -noout -fingerprint -sha256 | cut -d= -f2)"
LIFE_PORT=$((41000 + RANDOM % 1500))
( cd "$ROOT/tests" && "$REXX" lifecycle_server.rex "$TMP/life1.pem" "$TMP/life1.key" "$TMP/life2.pem" "$TMP/life2.key" "$TMP/bad.key" "$LIFE_PORT" ) >"$TMP/lifecycle.log" 2>&1 &
LIFE_PID=$!
PIDS+=("$LIFE_PID")
wait_ready "$LIFE_PID" "$TMP/lifecycle.log" || fail "lifecycle server did not become ready"
grep -q 'threading=thread-safe' "$TMP/lifecycle.log" || fail "lifecycle server missing thread-safe provider metadata"
grep -q 'generation=1' "$TMP/lifecycle.log" || fail "lifecycle server did not start on generation 1"

peer_fp(){
  local port="$1"
  printf '' | openssl s_client -connect "127.0.0.1:$port" -servername localhost 2>/dev/null \
    | openssl x509 -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2
}
[[ "$(peer_fp "$LIFE_PORT")" == "$FP1" ]] || fail "initial TLS certificate fingerprint mismatch"

printf 'GET /reload HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\n\r\nGET /generation HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect "127.0.0.1:$LIFE_PORT" 2>/dev/null >"$TMP/reload-pipeline.out" || true
grep -q 'reload current=2 requestTls=1' "$TMP/reload-pipeline.out" || { cat "$TMP/reload-pipeline.out" >&2; fail "TLS reload did not publish generation 2 from generation-1 request"; }
grep -q 'tls=1 current=2' "$TMP/reload-pipeline.out" || fail "existing TLS connection was not pinned to generation 1"
grep -q 'OOREXX_HTTPS_TLS_RELOADED generation=2 previousPins=1' "$TMP/lifecycle.log" || { cat "$TMP/lifecycle.log" >&2; fail "retired TLS generation pin count not observed"; }
[[ "$(peer_fp "$LIFE_PORT")" == "$FP2" ]] || fail "new TLS connection did not observe generation-2 certificate"
[[ "$(curl -skS "https://127.0.0.1:$LIFE_PORT/generation")" == 'tls=2 current=2' ]] || fail "new request did not use generation 2"
pass "atomic hot TLS context/certificate replacement with generation pinning"

curl -skS -D "$TMP/reload-bad.headers" -o "$TMP/reload-bad.body" "https://127.0.0.1:$LIFE_PORT/reload-bad" || true
grep -q '^HTTP/1.1 409 Conflict' "$TMP/reload-bad.headers" || fail "invalid TLS replacement was not rejected"
grep -q 'rejected current=2' "$TMP/reload-bad.body" || fail "failed TLS replacement changed the published generation"
[[ "$(peer_fp "$LIFE_PORT")" == "$FP2" ]] || fail "failed TLS replacement changed the active certificate"
pass "failed TLS replacement is atomic and non-destructive"

# Graceful drain: let one request remain active, trigger listener shutdown from
# a second accepted request, prove new connections are refused, and prove the
# in-flight request still completes before the process reports drained.
curl -skS "https://127.0.0.1:$LIFE_PORT/slow" >"$TMP/slow.out" &
SLOW_PID=$!
for _ in $(seq 1 50); do
  grep -q 'TEST_SLOW_ENTER' "$TMP/lifecycle.log" && break
  kill -0 "$SLOW_PID" 2>/dev/null || break
  sleep 0.05
done
grep -q 'TEST_SLOW_ENTER' "$TMP/lifecycle.log" || fail "slow request did not enter handler"
[[ "$(curl -skS "https://127.0.0.1:$LIFE_PORT/drain")" == 'draining tls=2' ]] || fail "drain request failed"
set +e
curl -skS --connect-timeout 1 --max-time 2 "https://127.0.0.1:$LIFE_PORT/generation" >"$TMP/post-drain.out" 2>"$TMP/post-drain.err"
POST_DRAIN_RC=$?
set -e
[[ $POST_DRAIN_RC -ne 0 ]] || fail "listener accepted a new connection after drain began"
wait "$SLOW_PID"
[[ "$(cat "$TMP/slow.out")" == 'slow-ok tls=2' ]] || fail "in-flight request did not complete during drain"
for _ in $(seq 1 100); do
  kill -0 "$LIFE_PID" 2>/dev/null || break
  sleep 0.05
done
if kill -0 "$LIFE_PID" 2>/dev/null; then
  cat "$TMP/lifecycle.log" >&2
  fail "lifecycle server did not finish graceful drain"
fi
wait "$LIFE_PID" || { cat "$TMP/lifecycle.log" >&2; fail "lifecycle server exited unsuccessfully"; }
grep -q 'OOREXX_HTTPS_DRAIN_COMPLETE ok=1 active=0 state=stopped generation=2' "$TMP/lifecycle.log" || { cat "$TMP/lifecycle.log" >&2; fail "graceful drain completion state missing"; }
pass "graceful listener drain preserves accepted requests and refuses new work"

pass "ALL HTTPS SERVER v0.4.4 TESTS"

#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$ROOT/src/DebugSocketTransport.cls" ] || fail "DebugSocketTransport.cls missing"
[ ! -e "$ROOT/src/SocketDebug.cls" ] || fail "legacy SocketDebug.cls still present"
[ -x "$ROOT/qualification/run_environment_test.sh" ] || fail "environment qualification script missing/not executable"
grep -q '::class DebugSocketTransport public' "$ROOT/src/DebugSocketTransport.cls" || fail "DebugSocketTransport class missing"
grep -q '::constant API "debug.socket.transport/0.1"' "$ROOT/src/DebugSocketTransport.cls" || fail "component API identity missing"
grep -q '::constant RELEASE "0.1-dev7"' "$ROOT/src/DebugSocketTransport.cls" || fail "release identity missing"
grep -q "closePolicyArg='OWNED'" "$ROOT/src/DebugSocketTransport.cls" || fail "explicit ownership policy missing"
grep -q '::method fromSelectedSocket class' "$ROOT/src/DebugSocketTransport.cls" || fail "selected-Socket handoff missing"
grep -q '::method fromAcceptedSocket class' "$ROOT/src/DebugSocketTransport.cls" || fail "accepted-Socket handoff missing"
grep -q '::method shutdownRead' "$ROOT/src/DebugSocketTransport.cls" || fail "read half-close missing"
grep -q '::method shutdownWrite' "$ROOT/src/DebugSocketTransport.cls" || fail "write half-close missing"
grep -q "cp<>'OWNED' & cp<>'BORROWED'" "$ROOT/src/DebugSocketTransport.cls" || fail "ownership validation missing"
grep -q '::requires "DebugSocketTransport.cls"' "$ROOT/tests/test_socket_transport.rex" || fail "test points at wrong class file"
if grep -n -E 'RxSock|host[[:space:]]*:[[:space:]]*port|QuicDebugTransport|XtpDebugTransport|TcpDebugTransport' "$ROOT/src/DebugSocketTransport.cls"; then
  fail "transport seam contains forbidden protocol-specific or flattened socket coupling"
fi
if grep -R -n 'SocketDebug\.cls' "$ROOT/src" "$ROOT/tests" "$ROOT/README.md" "$ROOT/ARCHITECTURE.md" 2>/dev/null; then
  fail "stale SocketDebug.cls reference"
fi
# Ensure no source code starts acquiring/constructing a transport family itself.
if grep -n -E '~new\([^)]*(TCP|QUIC|XTP)|SocketSelector~new|SocketProvider~new|SocketListener~new' "$ROOT/src/DebugSocketTransport.cls"; then
  fail "debug transport is acquiring/selecting its own Socket"
fi
echo "PACKAGE STATIC VALIDATION: OK"
# dev7 estate stream-adapter contract
if ! grep -q 'fromSocketStreamAdapter class' "$ROOT/src/DebugSocketTransport.cls"; then
  echo 'FAIL: missing SocketStreamAdapter handoff' >&2; exit 1
fi
if ! grep -q '::method streamObject' "$ROOT/src/DebugSocketTransport.cls"; then
  echo 'FAIL: missing stream identity accessor' >&2; exit 1
fi
if ! grep -q 'adapter WRITE not delegated' "$ROOT/tests/test_socket_transport.rex"; then
  echo 'FAIL: missing adapter-bypass regression' >&2; exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

: "${OOREXX_ROOT:?OOREXX_ROOT must point at the ooRexx installation root}"
: "${SOCKET_PROVIDER_SRC:?SOCKET_PROVIDER_SRC must contain SocketProvider.cls and SocketIntentions.cls}"
: "${RXSOCK6_ROOT:?RXSOCK6_ROOT must contain socket6.cls and the native rxsock6 library}"

REXX="${REXX:-$OOREXX_ROOT/bin/rexx}"

fail() {
    printf 'FAIL RXSOCK6_DEPLOYMENT_PREFLIGHT %s\n' "$*" >&2
    exit 1
}

test -x "$REXX" || fail "ooRexx executable not found: $REXX"
test -f "$RXSOCK6_ROOT/socket6.cls" || fail "socket6.cls not found under RXSOCK6_ROOT"
test -f "$SOCKET_PROVIDER_SRC/SocketProvider.cls" || fail "SocketProvider.cls not found under SOCKET_PROVIDER_SRC"

native=""
for candidate in     "$RXSOCK6_ROOT/librxsock6.so"     "$RXSOCK6_ROOT/librxsock6.so.0"     "$RXSOCK6_ROOT/rxsock6.so"
do
    if test -f "$candidate"; then
        native="$candidate"
        break
    fi
done
test -n "$native" || fail "native rxsock6 shared library not found"

test -f /proc/net/if_inet6 || fail "host kernel does not expose IPv6"

export LD_LIBRARY_PATH="$RXSOCK6_ROOT:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/tests:$SOCKET_PROVIDER_SRC:$RXSOCK6_ROOT:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"

printf 'RXSOCK6_PREFLIGHT_RUNTIME='
"$REXX" -v | head -1
printf 'RXSOCK6_PREFLIGHT_NATIVE=%s\n' "$native"

# Historical checked-in provider seam: TCP6 contract, negotiation and real loopback.
"$ROOT/tests/environment_test.sh"

# Native class-layer closure needed by the current qualified estate's UDP6 path.
(
    cd "$ROOT/tests"
    "$REXX" test_socket6_udp6_live.rex
)

printf 'RXSOCK6_PREFLIGHT_TCP6_PROVIDER=PASS\n'
printf 'RXSOCK6_PREFLIGHT_UDP6_NATIVE=PASS\n'
printf 'RXSOCK6_PREFLIGHT_PROVIDER_DEV3_SOURCE=NOT_ASSERTED\n'
printf 'PASS RXSOCK6_DEPLOYMENT_PREFLIGHT\n'

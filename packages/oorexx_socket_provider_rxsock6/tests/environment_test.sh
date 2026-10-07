#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${OOREXX_ROOT:?OOREXX_ROOT must point at ooRexx installation root}"
: "${SOCKET_PROVIDER_SRC:?SOCKET_PROVIDER_SRC must contain SocketProvider.cls and SocketIntentions.cls}"
: "${RXSOCK6_ROOT:?RXSOCK6_ROOT must contain socket6.cls and librxsock6.so}"

REXX="${REXX:-$OOREXX_ROOT/bin/rexx}"

export LD_LIBRARY_PATH="$RXSOCK6_ROOT:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$SOCKET_PROVIDER_SRC:$RXSOCK6_ROOT:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"

printf '== Socket Provider / RxSock6 environment qualification ==\n'
"$REXX" -v | head -1
printf 'ipv6: '
test -f /proc/net/if_inet6 && echo available || { echo unavailable; exit 77; }

cd "$ROOT/tests"
"$REXX" test_rxsock6_provider_contract.rex
"$REXX" test_rxsock6_negotiation.rex
"$REXX" test_rxsock6_provider_live.rex

printf 'PASS Socket Provider / RxSock6 environment qualification\n'

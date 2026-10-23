#!/bin/sh
set -eu
: "${OOREXX_RUNTIME_ROOT:?Must set OOREXX_RUNTIME_ROOT}"
: "${JSONRPC_SOCKET_PROVIDER_ROOT:?Must set JSONRPC_SOCKET_PROVIDER_ROOT}"
PKG=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -x "$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx" ]; then
  REXX="$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx"
  RUNTIME_LIB="$OOREXX_RUNTIME_ROOT/usr/local/lib"
  RUNTIME_CLASSES="$OOREXX_RUNTIME_ROOT/usr/local/bin"
else
  REXX="$OOREXX_RUNTIME_ROOT/bin/rexx"
  RUNTIME_LIB="$OOREXX_RUNTIME_ROOT/lib"
  RUNTIME_CLASSES="$OOREXX_RUNTIME_ROOT/bin"
fi
export LD_LIBRARY_PATH="$RUNTIME_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$PKG/src:$JSONRPC_SOCKET_PROVIDER_ROOT/src:$RUNTIME_CLASSES${REXX_PATH:+:$REXX_PATH}"
port=$((42000 + ($$ % 20000)))
"$REXX" "$PKG/examples/tcp_server.rex" "$port" 3 &
server=$!
trap 'kill "$server" 2>/dev/null || :; wait "$server" 2>/dev/null || :' EXIT HUP INT TERM
sleep .3
"$REXX" "$PKG/examples/tcp_client.rex" "$port"
wait "$server"
trap - EXIT HUP INT TERM

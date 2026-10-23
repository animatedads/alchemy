#!/bin/sh
# Selected exact runtime and optional dependencies, never auto-select duplicates.
set -eu
PKG=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -n "${OOREXX_RUNTIME_ROOT:-}" ]; then
  ROOT=${OOREXX_RUNTIME_ROOT%/}
  if [ -x "$ROOT/usr/local/bin/rexx" ]; then
    BIN="$ROOT/usr/local/bin"
    LIB="$ROOT/usr/local/lib"
  else
    BIN="$ROOT/bin"
    LIB="$ROOT/lib"
  fi
  REXX="$BIN/rexx"
  export LD_LIBRARY_PATH="$LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
else
  REXX=${OO_REXX_BIN:-rexx}
  BIN=''
fi
export REXX_PATH="$PKG/src${BIN:+:$BIN}${REXX_PATH:+:$REXX_PATH}"
"$REXX" "$PKG/tests/test_core_only.rex"
"$REXX" "$PKG/tests/test_rpc.rex"
if [ -n "${CONNECT_SELECTOR_ROOT:-}" ]; then
  [ -f "$CONNECT_SELECTOR_ROOT/src/ConnectSelector.cls" ] || {
    echo 'FAIL exact ConnectSelector path not found' >&2; exit 2;
  }
  export REXX_PATH="$PKG/src:$CONNECT_SELECTOR_ROOT/src${BIN:+:$BIN}${REXX_PATH:+:$REXX_PATH}"
  "$REXX" "$PKG/tests/test_connect_selector.rex"
  "$REXX" "$PKG/examples/connect_selector.rex"
else
  echo 'SKIP optional ConnectSelector integration (CONNECT_SELECTOR_ROOT not set)'
fi
"$REXX" "$PKG/tests/test_socket_mock.rex"
OUTPUT=$(printf '%s\n' '{"jsonrpc":"2.0","method":"system.ping","id":1}' '{"jsonrpc":"2.0","method":"math.sum","params":[1,2,3],"id":"two"}' '{"jsonrpc":"2.0","method":"system.ping"}' | "$REXX" "$PKG/examples/stdio_server.rex")
COUNT=$(printf '%s\n' "$OUTPUT" | wc -l | tr -d ' ')
[ "$COUNT" -eq 2 ] || { echo 'FAIL stdio response count'; exit 1; }
printf '%s\n' "$OUTPUT" | grep -F '"result":"pong"' >/dev/null || { echo 'FAIL stdio ping'; exit 1; }
printf '%s\n' "$OUTPUT" | grep -F '"result":6' >/dev/null || { echo 'FAIL stdio sum'; exit 1; }
echo 'PASS stdio request/reply/notification checks'
if [ -n "${JSONRPC_SOCKET_PROVIDER_ROOT:-}" ]; then
  export REXX_PATH="$PKG/src:$JSONRPC_SOCKET_PROVIDER_ROOT/src${BIN:+:$BIN}${REXX_PATH:+:$REXX_PATH}"
  "$REXX" "$PKG/tests/test_socket_live.rex"
  if [ -n "${OOREXX_RUNTIME_ROOT:-}" ]; then
    sh "$PKG/tests/test_socket_process.sh"
  else
    echo 'SKIP cross-process script (OOREXX_RUNTIME_ROOT not set)'
  fi
else
  echo 'SKIP optional live TCP checks (JSONRPC_SOCKET_PROVIDER_ROOT not set)'
fi
if [ -n "${JSONRPC_INSTRUMENTATION_ROOT:-}" ]; then
  export REXX_PATH="$PKG/src:$JSONRPC_INSTRUMENTATION_ROOT/src${BIN:+:$BIN}${REXX_PATH:+:$REXX_PATH}"
  "$REXX" "$PKG/tests/test_instrumentation.rex"
else
  echo 'SKIP optional instrumentation (JSONRPC_INSTRUMENTATION_ROOT not set)'
fi

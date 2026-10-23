#!/bin/sh
set -eu
PKG=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${OOREXX_RUNTIME_ROOT:?An explicit ooRexx runtime root is required}"
BIN="$OOREXX_RUNTIME_ROOT/usr/local/bin"
LIB="$OOREXX_RUNTIME_ROOT/usr/local/lib"
[ -x "$BIN/rexx" ] || { echo 'Missing ooRexx runtime' >&2; exit 2; }
export REXX_PATH="$PKG/src:$BIN${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$BIN/rexx" "$PKG/tests/test_registry.rex"
if [ -n "${SOAP_ROOT:-}" ] && [ -n "${JSONRPC_ROOT:-}" ]; then
  [ -f "$SOAP_ROOT/src/SoapRpcBinding.cls" ] || { echo 'SOAP_ROOT missing source' >&2; exit 2; }
  [ -f "$JSONRPC_ROOT/src/JsonRpcFabric.cls" ] || { echo 'JSONRPC_ROOT missing source' >&2; exit 2; }
  export REXX_PATH="$PKG/src:$SOAP_ROOT/src:$JSONRPC_ROOT/src:$BIN${REXX_PATH:+:$REXX_PATH}"
  export LD_LIBRARY_PATH="$SOAP_ROOT/native:$LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  "$BIN/rexx" "$PKG/tests/test_protocols.rex"
fi

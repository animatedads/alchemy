#!/bin/sh
set -eu
PKG=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OOREXX_RUNTIME_ROOT:?Set an explicit ooRexx runtime root}"
: "${RPC_CORE_ROOT:?Set exact oorexx_rpc_service_core package root}"
[ -f "$RPC_CORE_ROOT/src/RpcServiceCore.cls" ] || { echo 'Required RPC core source missing' >&2; exit 2; }
RUNTIME_BIN="$OOREXX_RUNTIME_ROOT/usr/local/bin"
RUNTIME_LIB="$OOREXX_RUNTIME_ROOT/usr/local/lib"
[ -x "$RUNTIME_BIN/rexx" ] || { echo 'Runtime rexx not found' >&2; exit 2; }
[ -f "$PKG/native/libsoapxml.so" ] || { echo 'Run make -C native first' >&2; exit 2; }
export LD_LIBRARY_PATH="$PKG/native:$RUNTIME_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$PKG/src:$RPC_CORE_ROOT/src:$RUNTIME_BIN${REXX_PATH:+:$REXX_PATH}"
"$RUNTIME_BIN/rexx" "$PKG/tests/test_soap.rex"
if [ -n "${SERIALIZATION_SELECTOR_ROOT:-}" ]; then
 [ -f "$SERIALIZATION_SELECTOR_ROOT/src/SerializationSelector.cls" ] || { echo "SerializationSelector source root missing" >&2; exit 2; }
 export REXX_PATH="$PKG/src:$RPC_CORE_ROOT/src:$SERIALIZATION_SELECTOR_ROOT/src:$RUNTIME_BIN${REXX_PATH:+:$REXX_PATH}"
 "$RUNTIME_BIN/rexx" "$PKG/tests/test_serialization.rex"
fi
if [ -n "${JSONRPC_ROOT:-}" ] || [ -n "${CONNECT_SELECTOR_ROOT:-}" ]; then
 : "${JSONRPC_ROOT:?Set both JSONRPC_ROOT and CONNECT_SELECTOR_ROOT}"
 : "${CONNECT_SELECTOR_ROOT:?Set both JSONRPC_ROOT and CONNECT_SELECTOR_ROOT}"
 [ -f "$JSONRPC_ROOT/src/JsonRpcFabric.cls" ] || exit 2
 [ -f "$CONNECT_SELECTOR_ROOT/src/ConnectSelector.cls" ] || exit 2
 export REXX_PATH="$PKG/src:$RPC_CORE_ROOT/src:$JSONRPC_ROOT/src:$CONNECT_SELECTOR_ROOT/src:$RUNTIME_BIN${REXX_PATH:+:$REXX_PATH}"
 "$RUNTIME_BIN/rexx" "$PKG/tests/test_shared.rex"
fi

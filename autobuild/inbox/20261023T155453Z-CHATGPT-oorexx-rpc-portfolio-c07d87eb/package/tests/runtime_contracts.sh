#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
: "${OOREXX_RUNTIME_ROOT:?Select exact ooRexx runtime root for qualification}"
: "${SERIALIZATION_ROOT:?Select exact Serialisation Selector v0.4+ root}"
: "${CONNECT_SELECTOR_ROOT:?Select exact Connect Selector root}"
RPC_CORE_ROOT="$ROOT/components/oorexx_rpc_service_core_v0.1-dev1"
JSONRPC_ROOT="$ROOT/components/oorexx_json_rpc_fabric_v0.1-dev3"
SOAP_ROOT="$ROOT/components/oorexx_soap_rpc_binding_v0.1-dev2"
GRPC_ROOT="$ROOT/components/oorexx_grpc_rpc_binding_v0.1-dev3"
export OOREXX_RUNTIME_ROOT SERIALIZATION_ROOT CONNECT_SELECTOR_ROOT RPC_CORE_ROOT JSONRPC_ROOT SOAP_ROOT
make -C "$SOAP_ROOT/native" clean all OOREXX_INCLUDE="$OOREXX_RUNTIME_ROOT/usr/local/include"
make -C "$GRPC_ROOT/native" stream OOREXX_INCLUDE="$OOREXX_RUNTIME_ROOT/usr/local/include"
sh "$RPC_CORE_ROOT/tests/run.sh"
SERIALIZATION_SELECTOR_ROOT="$SERIALIZATION_ROOT" sh "$SOAP_ROOT/tests/run.sh"
sh "$JSONRPC_ROOT/tests/run-tests.sh"
sh "$GRPC_ROOT/tests/run.sh"
# Separate server-streaming process fixture, including native callback bridge.
sh "$GRPC_ROOT/tests/run_http2_stream.sh"

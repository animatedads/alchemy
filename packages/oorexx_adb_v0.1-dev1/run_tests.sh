#!/bin/sh
set -eu
: "${OOREXX_ROOT:=/usr/local}"
: "${EVENT_RUNTIME_ROOT:?set EVENT_RUNTIME_ROOT to oorexx_event_runtime_v0.1-dev1}"
: "${CRYPTO_ROOT:?set CRYPTO_ROOT to oorexx_crypto_v0.8.3}"
: "${FOREIGN_ROOT:?set FOREIGN_ROOT to oorexx_foreign_runtime_v0.22.6}"
export PATH="$OOREXX_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib:$FOREIGN_ROOT/build:${LD_LIBRARY_PATH:-}"
export REXX_PATH="$PWD/src:$EVENT_RUNTIME_ROOT/src:$CRYPTO_ROOT/src:$FOREIGN_ROOT/rexx:$OOREXX_ROOT/bin:${REXX_PATH:-}"
export OOREXX_ADB_TCP_BRIDGE="$PWD/bridge/libc-adb-tcp.bridge.json"
cd tests
rexx test_wire.rex
rexx test_session.rex
rexx test_auth.rex
rexx test_native_tcp_smoke.rex

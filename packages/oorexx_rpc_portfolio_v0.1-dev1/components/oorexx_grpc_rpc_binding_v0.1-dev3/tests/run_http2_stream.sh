#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
make -C "$HERE/native" stream-fixture
python3 "$HERE/tests/test_native_stream.py"
if [ -n "${OOREXX_RUNTIME_ROOT:-}" ] && [ -n "${RPC_CORE_ROOT:-}" ] && [ -n "${SERIALIZATION_ROOT:-}" ]; then
    make -C "$HERE/native" stream OOREXX_INCLUDE="$OOREXX_RUNTIME_ROOT/usr/local/include"
    T=$(mktemp -d)
    PID=''
    cleanup(){ [ -z "$PID" ] || kill "$PID" 2>/dev/null || :; rm -rf "$T"; }
    trap cleanup EXIT HUP INT TERM
    python3 "$HERE/tests/fixtures/h2_grpc_stream_fixture.py" "$T/port" >"$T/fixture.log" 2>&1 & PID=$!
    i=0
    while [ ! -s "$T/port" ] && [ "$i" -lt 60 ]; do sleep .1; i=$((i+1)); done
    if [ ! -s "$T/port" ]; then cat "$T/fixture.log";exit 1; fi
    export LD_LIBRARY_PATH="$HERE/native:$OOREXX_RUNTIME_ROOT/usr/local/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export REXX_PATH="$HERE/src:$RPC_CORE_ROOT/src:$SERIALIZATION_ROOT/src${REXX_PATH:+:$REXX_PATH}"
    "$OOREXX_RUNTIME_ROOT/usr/local/bin/rexx" "$HERE/tests/test_http2_stream.rex" "$(cat "$T/port")"
else
    echo 'SKIP ooRexx streaming test: exact OOREXX_RUNTIME_ROOT / RPC_CORE_ROOT / SERIALIZATION_ROOT are not all supplied'
fi

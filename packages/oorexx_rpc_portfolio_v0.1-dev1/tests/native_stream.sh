#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
G="$ROOT/components/oorexx_grpc_rpc_binding_v0.1-dev3"
command -v g++ >/dev/null || { echo 'ERROR C++ compiler missing' >&2; exit 2; }
python3 -c 'import h2' || { echo 'ERROR hyper-h2 needed for native HTTP/2 fixture' >&2; exit 2; }
make -C "$G/native" stream-fixture
python3 "$G/tests/test_native_stream.py"

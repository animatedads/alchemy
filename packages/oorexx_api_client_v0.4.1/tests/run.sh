#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REXX=${REXX:-rexx}
: "${FOREIGN_RUNTIME_HOME:?set FOREIGN_RUNTIME_HOME to extracted oorexx_foreign_runtime_v0.22.6}"
OO_REXX_BIN=${OO_REXX_BIN:-}
OLD_REXX_PATH=${REXX_PATH:-}
export REXX_PATH="$ROOT/src:$FOREIGN_RUNTIME_HOME/rexx${OO_REXX_BIN:+:$OO_REXX_BIN}${OLD_REXX_PATH:+:$OLD_REXX_PATH}"
export LD_LIBRARY_PATH="${OO_REXX_LIB:-}${OO_REXX_LIB:+:}$FOREIGN_RUNTIME_HOME/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

cd "$ROOT"
./native/build.sh >/dev/null
export LD_LIBRARY_PATH="$ROOT/bridge${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$REXX" tests/test_core.rex
(cd tests && "$REXX" test_http_parser.rex)

python3 tests/tls/server.py >tests/tls/server.log 2>&1 &
pid=$!
trap 'kill "$pid" >/dev/null 2>&1 || true' EXIT INT TERM
sleep 1
(cd src && "$REXX" ../tests/test_https_transport.rex ../bridge ../tests/tls/cert.pem)
(cd src && "$REXX" ../tests/test_tls_identity.rex ../bridge ../tests/tls/cert.pem)
kill "$pid" >/dev/null 2>&1 || true
trap - EXIT INT TERM

python3 tests/tls/h2_server.py >tests/tls/h2_server.log 2>&1 &
h2pid=$!
trap 'kill "$h2pid" >/dev/null 2>&1 || true' EXIT INT TERM
sleep 1
(cd src && "$REXX" ../tests/test_h2_redirect.rex ../bridge ../tests/tls/cert.pem)
kill "$h2pid" >/dev/null 2>&1 || true
trap - EXIT INT TERM

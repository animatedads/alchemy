#!/bin/sh
set -eu
REXX_BIN=${REXX_BIN:-rexx}
REXX_LIB=${REXX_LIB:-}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -n "$REXX_LIB" ]; then export LD_LIBRARY_PATH="$REXX_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"; fi
export REXX_PATH="$ROOT/rexx:$ROOT/vendor/imap${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT/tests"
"$REXX_BIN" test_mailreader_imap_roundtrip.rex

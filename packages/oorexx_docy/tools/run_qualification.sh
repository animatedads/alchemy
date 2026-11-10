#!/bin/sh
set -eu
REXX_BIN="${1:-rexx}"
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RDIR=$(dirname "$REXX_BIN")
RLIB=$(dirname "$RDIR")/lib
export REXX_PATH="$HERE:$RDIR${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$RLIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$HERE"
for casefile in tests/demo_test.rex tests/test_extension.rex tests/test_office_adapters.rex tests/test_native_odt_archive.rex tests/test_docy_archive_pipeline.rex tests/test_office_error_handling.rex; do
  echo "== $casefile =="
  "$REXX_BIN" "$casefile"
done

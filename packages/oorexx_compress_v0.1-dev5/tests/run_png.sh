#!/bin/sh
# compress dev5 PNG qualification: Rexx test + independent stdlib decode of
# both lanes, asserting identical pixels.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd); ROOT=$(dirname "$HERE")
export REXX_PATH="$ROOT/src:$ROOT/foreign${REXX_PATH:+:$REXX_PATH}"
export PYTHONPATH="$ROOT/python${PYTHONPATH:+:$PYTHONPATH}"
cd "$HERE"; rm -f png_pure.b64 png_foreign.b64
rexx test_png_encoder.rex
a=$(python3 validate_png.py png_pure.b64); echo "PURE    $a"
if [ -f png_foreign.b64 ]; then
  b=$(python3 validate_png.py png_foreign.b64); echo "FOREIGN $b"
  [ "$a" = "$b" ] || { echo 'FAIL lanes decode to different pixels'; exit 1; }
  echo 'PASS identical pixels across PURE and FOREIGN lanes'
fi
rm -f png_pure.b64 png_foreign.b64

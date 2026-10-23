#!/bin/sh
set -eu
python3 -m unittest discover -s tests -v
if command -v rexx >/dev/null 2>&1; then
  REXX_PATH="$(pwd)/src${REXX_PATH:+:$REXX_PATH}" rexx tests/test_front.rex
else
  echo 'ooRexx executable not found: native qualification requires separate rexx test' >&2
  exit 1
fi

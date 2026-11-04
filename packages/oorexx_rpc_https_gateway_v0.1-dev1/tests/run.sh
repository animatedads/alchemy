#!/bin/sh
set -eu
python3 tests/verify_contract.py
if command -v rexx >/dev/null 2>&1; then
  rexx tests/test_gateway.rex
else
  echo 'PENDING ooRexx runtime regression: rexx interpreter not installed' >&2
fi

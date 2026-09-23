#!/bin/sh
set -eu
: "${REXX:=rexx}"
cd "$(dirname "$0")"
"$REXX" ./test_native.rex
if grep -RniE 'address[[:space:]]+(system|cmd)|subprocess|import[[:space:]]+python|NullPointerException' ../src >/dev/null 2>&1; then
  echo 'FAIL bootstrap purity scan'
  exit 1
fi
echo 'PASS archive bootstrap purity scan'

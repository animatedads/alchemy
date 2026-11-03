#!/bin/sh
set -eu
: "${REXX:=rexx}"
cd "$(dirname "$0")"
"$REXX" ./test_native.rex

# Bootstrap purity is a source invariant. Comments/docs are not scanned.
if grep -REni 'ADDRESS[[:space:]]+SYSTEM|::requires.*LIBRARY|RxFuncAdd|python|java|zlib' ../src ../bin; then
  echo 'FAIL: bootstrap source contains a forbidden external-runtime dependency' >&2
  exit 1
fi
echo 'PASS bootstrap purity scan'

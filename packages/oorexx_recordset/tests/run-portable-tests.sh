#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${TMPDIR:-/tmp}/oorexx-recordset-native-test
c++ -std=c++98 -Wall -Wextra -pedantic -I"$HERE/include" \
  "$HERE/platform/portable/RecordSetNativePortable.cpp" "$HERE/tests/native_api_test.cpp" -o "$OUT"
"$OUT"
rm -f "$OUT"

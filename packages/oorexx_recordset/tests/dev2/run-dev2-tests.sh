#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
OUT=${OUT:-/tmp/oorexx-recordset-dev2-test}
mkdir -p "$OUT"
cc -std=c90 -pedantic -Wall -Wextra -I"$ROOT/include" \
  "$ROOT/platform/mvs/RecordSetNativeMvs.c" \
  "$ROOT/tests/mvs_fake_driver.c" \
  "$ROOT/tests/mvs_backend_test.c" \
  -o "$OUT/mvs_backend_test"
"$OUT/mvs_backend_test"
"$ROOT/tests/run-portable-tests.sh"

#!/bin/sh
set -eu
: "${REXX:=rexx}"
cd "$(dirname "$0")"
"$REXX" ./test_zstd_native.rex
"$REXX" ./test_zstd_entropy.rex

# Stage-0 Zstd source must not delegate to a process, foreign package, or other runtime.
if grep -Eni 'ADDRESS[[:space:]]+SYSTEM|::requires.*LIBRARY|RxFuncAdd|python|java|zlib|libzstd|ForeignRuntime|\.foreign~' \
  ../src/NativeZstdCodec.cls ../src/NativeXXH64.cls ../src/Zstd*.cls; then
  echo 'FAIL: native Zstd source contains a forbidden bootstrap dependency' >&2
  exit 1
fi
echo 'PASS native Zstandard purity scan'

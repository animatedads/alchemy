#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CC="${CC:-cc}"
CFLAGS="${CFLAGS:--O2 -fPIC -Wall -Wextra -Wpedantic}"
"$CC" $CFLAGS -shared -o "$HERE/libcrypto_compat.so" "$HERE/crypto_compat.c" -lcrypto

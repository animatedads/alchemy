#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT="$HERE/../bridge/liboorexx_api_h2.so"
cc -std=c11 -O2 -fPIC -shared -D_POSIX_C_SOURCE=200809L -o "$OUT" "$HERE/api_h2_bridge.c" -lnghttp2 -lssl -lcrypto
printf '%s\n' "$OUT"

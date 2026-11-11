#!/bin/sh
# Only compiles a native Foreign Runtime provider; no media processing here.
set -eu
cd "$(dirname "$0")"
: "${CC:=cc}"
: "${PKG_CONFIG:=pkg-config}"
"$PKG_CONFIG" --exists libavformat libavcodec libavutil libswresample || {
  echo 'BLOCKED: libavformat/libavcodec/libavutil/libswresample development packages missing' >&2
  exit 2
}
: "${BUILD_DIR:=$PWD/build}"
mkdir -p "$BUILD_DIR"
"$CC" -std=c11 -O2 -fPIC -Wall -Wextra -shared \
  $("$PKG_CONFIG" --cflags libavformat libavcodec libavutil libswresample) \
  spash_ogg_decode.c -o "$BUILD_DIR/libspash_ogg_decode.so" \
  $("$PKG_CONFIG" --libs libavformat libavcodec libavutil libswresample) -lm
printf 'BUILT_SOURCE_ONLY %s\n' "$BUILD_DIR/libspash_ogg_decode.so"

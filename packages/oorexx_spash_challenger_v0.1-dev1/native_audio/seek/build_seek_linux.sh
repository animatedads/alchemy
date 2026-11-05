#!/bin/sh
# Build only native Foreign Runtime provider. No audio processing by shell.
set -eu
cd "$(dirname "$0")"
: "${CC:=cc}"
: "${PKG_CONFIG:=pkg-config}"
"$PKG_CONFIG" --exists libavformat libavcodec libavutil libswresample || { echo 'BLOCKED_NATIVE_LIBAV_DEV_HEADERS' >&2; exit 2; }
: "${BUILD_DIR:=$PWD/build}"
mkdir -p "$BUILD_DIR"
"$CC" -std=c11 -O2 -fPIC -Wall -Wextra -Werror -shared \
  $("$PKG_CONFIG" --cflags libavformat libavcodec libavutil libswresample) \
  spash_ogg_seek.c -o "$BUILD_DIR/libspash_ogg_seek.so" \
  $("$PKG_CONFIG" --libs libavformat libavcodec libavutil libswresample) -lm
printf 'BUILT_UNQUALIFIED %s\n' "$BUILD_DIR/libspash_ogg_seek.so"

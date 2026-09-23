#!/usr/bin/env sh
set -eu
: "${CREXX_ROOT:?Set CREXX_ROOT to the pinned CREXX checkout}"
CC="${CREXX_CC:-cc}"
INC="${CREXX_INCLUDE:-$CREXX_ROOT/rxpa}"
OUT="${BUILD_DIR:-build}"
mkdir -p "$OUT"
case "$(uname -s)" in
  Darwin) SHARED="-dynamiclib" ;;
  *) SHARED="-shared" ;;
esac
"$CC" -std=c11 -Wall -Wextra -Werror -fPIC -DBUILD_DLL -I"$INC" $SHARED \
  native/alchemy_test_provider.c -o "$OUT/alchemytest.rxplugin"
printf '%s\n' "$OUT/alchemytest.rxplugin"

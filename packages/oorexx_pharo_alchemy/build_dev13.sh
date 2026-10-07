#!/bin/sh
set -eu
: "${OOREXX_ROOT:?set OOREXX_ROOT}"
CXX=${CXX:-g++}
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$HERE/build"
"$CXX" -shared -fPIC -std=c++11 -Wall -Wextra -Werror \
  -I"$OOREXX_ROOT/usr/local/include" \
  "$HERE/src/pharo_alchemy_dev13_combined.cpp" \
  -L"$OOREXX_ROOT/usr/local/lib" -lrexx \
  -Wl,-rpath,"$OOREXX_ROOT/usr/local/lib" \
  -o "$HERE/build/libpharo_alchemy_dev13.so"

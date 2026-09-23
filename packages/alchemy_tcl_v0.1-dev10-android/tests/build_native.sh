#!/data/data/com.termux/files/usr/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OOREXX_SRC=${OOREXX_SRC:-"$HOME/src/ooRexx"}
OOREXX_BUILD=${OOREXX_BUILD:-"$HOME/build/oorexx-xcover-safe"}
OOREXX_INCLUDE=${OOREXX_INCLUDE:-"$OOREXX_SRC/api"}
OOREXX_PLATFORM_INCLUDE=${OOREXX_PLATFORM_INCLUDE:-"$OOREXX_INCLUDE/platform/unix"}
OOREXX_LIB=${OOREXX_LIB:-"$OOREXX_BUILD/lib"}
CXX=${CXX:-clang++}
[ -f "$OOREXX_INCLUDE/oorexxapi.h" ] || { echo "ERROR missing $OOREXX_INCLUDE/oorexxapi.h" >&2; exit 2; }
[ -x "$OOREXX_BUILD/bin/rexx" ] || { echo "ERROR missing $OOREXX_BUILD/bin/rexx" >&2; exit 2; }
[ -d "$OOREXX_LIB" ] || { echo "ERROR missing $OOREXX_LIB" >&2; exit 2; }
OUT="$ROOT/build"; mkdir -p "$OUT"
echo "Architecture:     $(uname -m)"
echo "C++:              $($CXX --version | head -1)"
echo "ooRexx:           $OOREXX_BUILD/bin/rexx"
echo "API include:      $OOREXX_INCLUDE"
echo "Platform include: $OOREXX_PLATFORM_INCLUDE"
echo "Libraries:        $OOREXX_LIB"
"$CXX" -std=c++17 -fPIC -shared -Wall -Wextra -Werror \
  -I"$OOREXX_INCLUDE" -I"$OOREXX_PLATFORM_INCLUDE" \
  "$ROOT/native/alchemy_tcl.cpp" -ldl -o "$OUT/libalchemy_tcl.so"
echo "build-ok $OUT/libalchemy_tcl.so"

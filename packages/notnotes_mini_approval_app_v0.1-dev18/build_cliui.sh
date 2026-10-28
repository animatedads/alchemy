#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
CLI="$HERE/vendor/cliui"
: "${REXX_HOME:?Set REXX_HOME to the ooRexx installation prefix, e.g. /usr/local}"
CC=${CC:-cc}
CXX=${CXX:-c++}
mkdir -p "$CLI/build" "$CLI/lib"
"$CC" -std=c11 -fPIC -Wall -Wextra -Werror -I"$CLI/include" -c "$CLI/src/cliui_ansi.c" -o "$CLI/build/cliui_ansi.o"
"$CC" -std=c11 -fPIC -Wall -Wextra -Werror -I"$CLI/include" -c "$CLI/src/cliui_posix.c" -o "$CLI/build/cliui_posix.o"
"$CXX" -std=c++11 -fPIC -Wall -Wextra -Werror -I"$CLI/include" -I"$REXX_HOME/include" -c "$CLI/src/cliui_oorexx.cpp" -o "$CLI/build/cliui_oorexx.o"
LIBDIR="$REXX_HOME/lib"
if [ -d "$REXX_HOME/lib64" ]; then LIBDIR="$REXX_HOME/lib64"; fi
"$CXX" -shared -o "$CLI/lib/libcliui_oorexx.so" "$CLI/build/cliui_oorexx.o" "$CLI/build/cliui_ansi.o" "$CLI/build/cliui_posix.o" -L"$LIBDIR" -lrexx -lrexxapi
echo "Built $CLI/lib/libcliui_oorexx.so"

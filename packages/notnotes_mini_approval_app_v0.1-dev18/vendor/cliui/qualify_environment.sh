#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
: "${REXX_HOME:?Set REXX_HOME to the ooRexx installation prefix, e.g. /usr/local}"
REXX="$REXX_HOME/bin/rexx"
[ -x "$REXX" ] || { echo "FAIL: $REXX is not executable" >&2; exit 2; }
CC=${CC:-cc}; CXX=${CXX:-c++}
command -v "$CC" >/dev/null
command -v "$CXX" >/dev/null
command -v python3 >/dev/null
"$REXX" -v | head -4
mkdir -p "$ROOT/build" "$ROOT/lib"
"$CC" -std=c11 -fPIC -Wall -Wextra -Werror -I"$ROOT/include" -c "$ROOT/src/cliui_ansi.c" -o "$ROOT/build/cliui_ansi.o"
"$CC" -std=c11 -fPIC -Wall -Wextra -Werror -I"$ROOT/include" -c "$ROOT/src/cliui_posix.c" -o "$ROOT/build/cliui_posix.o"
"$CXX" -std=c++11 -fPIC -Wall -Wextra -Werror -I"$ROOT/include" -I"$REXX_HOME/include" -c "$ROOT/src/cliui_oorexx.cpp" -o "$ROOT/build/cliui_oorexx.o"
"$CXX" -shared -o "$ROOT/lib/libcliui_oorexx.so" "$ROOT/build/cliui_oorexx.o" "$ROOT/build/cliui_ansi.o" "$ROOT/build/cliui_posix.o" -L"$REXX_HOME/lib" -lrexx -lrexxapi
export PATH="$REXX_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$ROOT/lib:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/rexx:$ROOT/lib${REXX_PATH:+:$REXX_PATH}"
"$ROOT/run_tests.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
"$REXX" "$ROOT/tests/test_list_detail_action.rex"
"$REXX" "$ROOT/tests/test_prompt.rex"
"$REXX" "$ROOT/tests/test_action_map.rex"
"$REXX" "$ROOT/tests/test_form_screen.rex"
"$REXX" "$ROOT/tests/test_ansi_binding.rex" > "$TMP/ansi.out"
grep -q 'PASS ooRexx native ANSI renderer binding' "$TMP/ansi.out"
if printf '#include <ncursesw/curses.h>\nint main(void){return 0;}\n' | "$CC" -x c - -lncursesw -o "$TMP/ncurses-probe" >/dev/null 2>&1; then
  echo 'ncursesw development interface: AVAILABLE (provider not yet implemented)'
else
  echo 'ncursesw development interface: UNAVAILABLE; curses provider remains fail-closed'
fi
echo 'PASS unrelated-working-directory REXX_PATH qualification'

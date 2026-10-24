#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
CC=${CC:-cc}
mkdir -p "$ROOT/build"
$CC -std=c11 -Wall -Wextra -Werror -I"$ROOT/include" "$ROOT/src/cliui_ansi.c" "$ROOT/src/cliui_posix.c" "$ROOT/tests/test_ansi.c" -o "$ROOT/build/test_ansi"
"$ROOT/build/test_ansi"
python3 "$ROOT/tests/test_contract.py"
python3 "$ROOT/tests/test_rexx_shapes.py"
if command -v rexx >/dev/null 2>&1; then
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_document.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_editor.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_semantic.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_editor_projection.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_editor_controller.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_mailreader.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_list_detail_action.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_prompt.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_action_map.rex"
  REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx "$ROOT/tests/test_form_screen.rex"
  (cd "$ROOT/examples/editor" && REXX_PATH="$ROOT/rexx${REXX_PATH:+:$REXX_PATH}" rexx editor.rex sample.rex)
else
  echo 'SKIP ooRexx fixtures: rexx not installed'
fi

"$CC" -std=c11 -Wall -Wextra -Werror -I"$ROOT/include" "$ROOT/src/cliui_ansi.c" "$ROOT/tests/test_io.c" -o "$ROOT/build/test_io"
"$ROOT/build/test_io"

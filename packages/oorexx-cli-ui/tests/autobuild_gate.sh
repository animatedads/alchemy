#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
for file in VERSION run_tests.sh qualify_environment.sh include/oorexx_cli_ui.h src/cliui_ansi.c src/cliui_posix.c src/cliui_oorexx.cpp rexx/CliUiScreen.cls rexx/CliUiBoundedRenderer.cls rexx/CliUiSemantic.cls rexx/CliUiHeadlessRenderer.cls rexx/CliUiTable.cls rexx/CliUiForm.cls tests/test_region_isolation.rex; do
  if [ ! -f "$ROOT/$file" ]; then
    echo "FAIL: missing source: $file" >&2
    exit 1
  fi
done
if ! command -v rexx >/dev/null 2>&1; then
  echo 'FAIL: ooRexx runtime unavailable; no skip allowed' >&2
  exit 1
fi
sh "$ROOT/qualify_environment.sh"

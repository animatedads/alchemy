#!/usr/bin/env bash
set -euo pipefail
REPO="$ALCHEMY_REPO_ROOT"
if [[ -z "$REPO" ]]; then echo "NOT_RUN: ALCHEMY_REPO_ROOT missing" >&2; exit 69; fi
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$REPO/packages/notnotes_mini_approval_app_v0.1-dev18"
PATCH="$REPO/packages/notnotes_cli_bounded_patch_v0.1-dev1"
if [[ ! -f "$BASE/src/MiniNotesCliUi.cls" || ! -f "$PATCH/scripts/apply.py" ]]; then
  echo "NOT_RUN: exact source/accepted patch package missing" >&2; exit 69
fi
if ! command -v rexx >/dev/null; then echo "NOT_RUN: rexx missing" >&2; exit 69; fi
TMP="$(mktemp -d /tmp/nn-paged-qualified.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/dev18"
cp -a "$BASE/." "$TMP/dev18/"
python3 "$PATCH/scripts/apply.py" --source "$BASE/src/MiniNotesCliUi.cls" --output "$TMP/dev18/src/MiniNotesCliUi.cls"
APP="$TMP/dev18"
REXX_HOME="/usr/local"
export REXX_PATH="$APP:$APP/src:$APP/vendor/notnotes:$APP/vendor/nosql:$APP/vendor/cliui/rexx:$APP/vendor/pdf/src:$APP/vendor/spreadsheet:$APP/vendor/instrumentation:$APP/vendor/time/src:$APP/vendor/connect:$REXX_HOME/share/ooRexx:$REXX_HOME/bin"
export LD_LIBRARY_PATH="$REXX_HOME/lib64:$REXX_HOME/lib"
export MININOTES_DB_BACKEND=file
cd "$APP"
for TEST in "$HERE/tests/test_bounded_cli_startup.rex" tests/test_cli_ui_screen.rex tests/test_tps_designer.rex tests/test_semantic_application_projection.rex; do
  MININOTES_DB_ROOT="$TMP/$(basename "$TEST" .rex)" rexx "$TEST"
done
echo "NOTNOTES_DEV18_CLI_BOUNDED_NATIVE_PASS"

#!/usr/bin/env bash
set -eo pipefail
if [ -z "$REXX_HOME" ]; then echo "NOT_RUN REXX_HOME unset"; exit 2; fi
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export LD_LIBRARY_PATH="$REXX_HOME/lib64:$REXX_HOME/lib:$LD_LIBRARY_PATH"
"$REXX_HOME/bin/rexx" "$ROOT/tests/sort_contract.rex"
if [ -n "$MININOTES_APP_ROOT" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  cp -a "$MININOTES_APP_ROOT" "$tmp/app"
  patch --batch --forward -p1 -d "$tmp/app" < "$ROOT/patches/notnotes_doc_key_comparator.patch"
  APP="$tmp/app"
  export REXX_PATH="$APP:$APP/src:$APP/vendor/notnotes:$APP/vendor/nosql:$APP/vendor/cliui/rexx:$APP/vendor/pdf/src:$APP/vendor/spreadsheet:$REXX_HOME/share/ooRexx:$REXX_HOME/bin"
  export MININOTES_DB_ROOT="$tmp/db"
  (cd "$APP"; "$REXX_HOME/bin/rexx" tests/test_tps_designer.rex)
else
  echo 'NOT_RUN optional full NotNotes regression (MININOTES_APP_ROOT absent)'
fi

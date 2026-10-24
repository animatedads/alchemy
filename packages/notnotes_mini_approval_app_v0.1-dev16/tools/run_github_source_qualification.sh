#!/usr/bin/env bash
# Qualify the source-published Mini NotNotes app against the retained/selected ooRexx interpreter.
# This script deliberately derives all source roots from its own location.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REXX_ROOT="${OOREXX_ROOT:-}"
if [[ -n "$REXX_ROOT" ]]; then
  rexx="$REXX_ROOT/usr/local/bin/rexx"
  libs="$REXX_ROOT/usr/local/lib"
  runtime_bin="$REXX_ROOT/usr/local/bin"
else
  rexx="${REXX:-$(command -v rexx || true)}"
  libs="${LD_LIBRARY_PATH:-}"
  runtime_bin="$(dirname "$rexx")"
fi
[[ -x "$rexx" ]] || { echo 'FAIL: ooRexx executable not found' >&2; exit 2; }
export LD_LIBRARY_PATH="$libs${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$runtime_bin:$root:$root/src:$root/vendor/notnotes:$root/vendor/nosql:$root/vendor/pdf/src:$root/vendor/cliui/rexx:$root/vendor/instrumentation:$root/vendor/time/src:$root/vendor/spreadsheet:$root/vendor/connect:${REXX_PATH:-}"
"$rexx" -v | head -3
runroot="$(mktemp -d)"; trap 'rm -rf "$runroot"' EXIT
cd "$root"
for test in test_mini_notes test_query_guard test_tps_designer test_semantic_application_projection test_many_document_references test_instrumentation_mesh test_nosql_backend; do
  export MININOTES_TEST_ROOT="$runroot/$test" MININOTES_DB_ROOT="$runroot/$test"
  "$rexx" "tests/$test.rex"
done
echo 'PASS Mini NotNotes source-published basic qualification'

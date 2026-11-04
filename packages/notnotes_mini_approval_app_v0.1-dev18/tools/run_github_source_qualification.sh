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
# These inherited source-publication tests exercise the historical file store.
# Without this explicit selection dev18 would attempt the new SQLite default,
# require librexxsql.so, and fail for an unrelated reason.
export MININOTES_DB_BACKEND=file
# Both SQL persistence entrypoints must fail before doing SQL when a provider
# offers BEGIN but lacks COMMIT/ROLLBACK. This test uses a fake provider so it
# is valid even on the native-Library-absent source-qualification host.
"$rexx" tests/test_sqlite_transaction_capability_guard.rex
for test in test_mini_notes test_query_guard test_tps_designer test_semantic_application_projection test_many_document_references test_instrumentation_mesh test_nosql_backend test_temporal_evidence; do
  export MININOTES_TEST_ROOT="$runroot/$test" MININOTES_DB_ROOT="$runroot/$test"
  "$rexx" "tests/$test.rex"
done
echo 'PASS Mini NotNotes source-published basic qualification (explicit file store + SQLite capability guard)'

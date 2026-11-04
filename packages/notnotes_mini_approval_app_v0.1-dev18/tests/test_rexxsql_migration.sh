#!/usr/bin/env bash
# End-to-end migration/differential test. Runs only when the existing built
# Rexx/SQL native function package is available; never a fake SQLite engine.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
: "${REXX_BIN:=rexx}"
fixture="$here/tests/fixtures/management_review/data/mininotes"
if [[ ! -f "$fixture/database.yaml" ]]; then
  echo "NOTNOTES_MIGRATION_TEST_UNAVAILABLE: fixture missing" >&2; exit 2
fi
scratch=$(mktemp -d "${TMPDIR:-/tmp}/notnotes-migration-test.XXXXXX")
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/source"
cp -a -- "$fixture/." "$scratch/source/"
"$here/tools/migrate_file_to_rexxsql.sh" "$scratch/source" "$scratch/converted.sqlite"
if [[ ! -s "$scratch/converted.sqlite" ]]; then
  echo "NOTNOTES_MIGRATION_TEST_FAILED: SQLite file absent" >&2; exit 1
fi
# Re-open the independently converted store with the actual app and exercise
# its real persistence and management-review fixture test.
cd "$here"
: "${REXX_HOME:=/usr/local}"
sql_src="$here/../oorexx_rexxsql_backend_v0.1/src"
native_src="$here/../oorexx_native_database_backends_v0.1/src"
export REXX_PATH="$here:$here/src:$here/vendor/notnotes:$here/vendor/nosql:$here/vendor/cliui/rexx:$here/vendor/pdf/src:$here/vendor/spreadsheet:$here/vendor/instrumentation:$here/vendor/time/src:$here/vendor/connect:$sql_src:$native_src:$REXX_HOME/share/ooRexx:$REXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="${REXXSQL_LIB_DIR:+$REXXSQL_LIB_DIR:}$REXX_HOME/lib64:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
MININOTES_DB_ROOT="$scratch/converted.sqlite" MININOTES_DB_BACKEND=rexxsql-sqlite \
  "$REXX_BIN" tests/test_management_review_fixture.rex
echo "NOTNOTES_SQLITE_MIGRATION_DIFFERENTIAL_PASS"

#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE"
REXX_BIN=${REXX_BIN:-rexx}
: "${REXX_HOME:=/usr/local}"
export REXX_PATH="$HERE:$HERE/src:$HERE/vendor/notnotes:$HERE/vendor/nosql:$HERE/vendor/cliui/rexx:$HERE/vendor/pdf/src:$HERE/vendor/spreadsheet:$HERE/vendor/instrumentation:$HERE/vendor/time/src:$HERE/vendor/connect:$REXX_HOME/share/ooRexx:$REXX_HOME/bin${REXX_PATH:+:$REXX_PATH}"
# Consume neighbouring source providers; never vendor an alternative SQL driver.
REXXSQL_SRC="$HERE/../oorexx_rexxsql_backend_v0.1/src"
NATIVE_DB_SRC="$HERE/../oorexx_native_database_backends_v0.1/src"
if [[ -d "$REXXSQL_SRC" && -d "$NATIVE_DB_SRC" ]]; then
  export REXX_PATH="$REXXSQL_SRC:$NATIVE_DB_SRC:$REXX_PATH"
fi
export LD_LIBRARY_PATH="${REXXSQL_LIB_DIR:+$REXXSQL_LIB_DIR:}$REXX_HOME/lib64:$REXX_HOME/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
# The inherited suite exercises legacy FileDatabaseEngine behaviour explicitly.
# The production/default selector remains rexxsql-sqlite.
export MININOTES_DB_BACKEND=file
# Native fail-closed guard runs BEFORE the inherited long-running corpus suite.
# It has no external SQLite/Crypto dependency and remains a release gate.
"$REXX_BIN" tests/test_sqlite_transaction_capability_guard.rex
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/mininotes-tests.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT
run_rexx() {
  local name=$1
  local file=$2
  MININOTES_DB_ROOT="$TEST_ROOT/$name" "$REXX_BIN" "$file"
}
run_rexx mini tests/test_mini_notes.rex
run_rexx query tests/test_query_guard.rex
run_rexx projection tests/test_cli_projection.rex
run_rexx screen tests/test_cli_ui_screen.rex
run_rexx tps tests/test_tps_designer.rex
run_rexx nosql tests/test_nosql_backend.rex
run_rexx relationship tests/test_relationship_subview_calculations.rex
run_rexx manyrefs tests/test_many_document_references.rex
run_rexx evolution tests/test_schema_evolution.rex
run_rexx semantic_projection tests/test_semantic_application_projection.rex
run_rexx instrumentation tests/test_instrumentation_mesh.rex
run_rexx time_service tests/test_time_service_fields.rex
run_rexx temporal_evidence tests/test_temporal_evidence.rex
MGMT_ROOT="$TEST_ROOT/management-review"
mkdir -p "$MGMT_ROOT"
cp -a tests/fixtures/management_review/data/mininotes/. "$MGMT_ROOT/"
MININOTES_DB_ROOT="$MGMT_ROOT" "$REXX_BIN" tests/test_management_review_fixture.rex
mkdir -p "$TEST_ROOT/accounts-export"
MININOTES_DB_ROOT="$MGMT_ROOT" MININOTES_EXPORT_ROOT="$TEST_ROOT/accounts-export" "$REXX_BIN" tests/test_spreadsheet_export.rex
run_rexx submit tests/test_submit_lifecycle.rex
MININOTES_DB_ROOT="$TEST_ROOT/submit-entry" ./tests/test_submit_entrypoint.sh
MININOTES_DB_ROOT="$TEST_ROOT/entrypoint" ./tests/test_tps_entrypoint.sh
MININOTES_DB_ROOT="$TEST_ROOT/persistence" ./tests/test_save_print_persistence.sh
MININOTES_DB_ROOT="$TEST_ROOT/reporting" ./tests/test_report_designer_persistence.sh

run_rexx batch tests/test_batch_persistence.rex

# Guard the authentic NoSQL DatabaseRow values-column contract used in migration.
"$REXX_BIN" tests/test_migration_row_contract.rex

# Exercise actual MiniNotesApp~sortByKey on 10,002 objects, avoiding SQL.
"$REXX_BIN" tests/test_sort_regression.rex

# Preserve SQL NULL versus empty-text updates in both full and delta saves.
"$REXX_BIN" tests/test_sqlite_null_empty_change_detection.rex

# SQL adapter contract test with a fake function package, never in product path.
REXX_PATH="$HERE/tests/fixtures:$REXX_PATH" "$REXX_BIN" tests/test_rexxsql_adapter_mock.rex
# Opt-in real native SQL test; requires the existing built librexxsql.so.
if [[ "${MININOTES_TEST_SQLITE_LIVE:-0}" == "1" ]]; then
  if [[ ! -f "$REXXSQL_SRC/RexxSqlDatabaseProvider.cls" ]] || \
     [[ ! -f "$NATIVE_DB_SRC/DatabaseBackendSelector.cls" ]] || \
     ! grep -q 'REXXSQL-SQLITE' "$NATIVE_DB_SRC/DatabaseBackendSelector.cls"; then
    echo "NOTNOTES_PROVIDER_NOT_READY: native live test requires integrated shared REXXSQL-SQLITE provider" >&2
    exit 69
  fi
  MININOTES_DB_BACKEND=rexxsql-sqlite "$REXX_BIN" tests/test_rexxsql_adapter_live.rex
  "$HERE/tests/test_rexxsql_migration.sh"
fi

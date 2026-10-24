#!/bin/sh
# Run the Semantic Source Store's own live tests on Rexx/SQL + SQLite instead of NoSQLServer.
# Author: Claude (Opus 5.5), 2026-10-24. Architecture: Tom Dyer.
# The store package is not modified: each test is copied to a scratch directory and exactly
# one line is changed, the executor construction, plus ::requires NoSQLServer.cls is replaced
# by ::requires SemanticSourceSqliteIndexPlan.cls (Rexx/SQL session + the store index plan), so
# NoSQLServer cannot be used by accident.
# Usage: sh run_ssc_live_on_rexxsql.sh SSC_PACKAGE_DIR LIBREXXSQL_DIR [test ...]
#   Needs ALCHEMY_REPO_ROOT (dependencies) and FOREIGN_RUNTIME_ROOT (built Foreign Runtime, for crypto).
#   SSC_INDEX_PLAN=0 runs without the secondary indexes (primary keys only), for comparison.
set -eu
SSC=$(CDPATH= cd -- "${1:?SSC package dir}" && pwd)
LIB=$(CDPATH= cd -- "${2:?directory holding librexxsql.so}" && pwd)
shift 2
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
REPO=${ALCHEMY_REPO_ROOT:?set ALCHEMY_REPO_ROOT}
FR=${FOREIGN_RUNTIME_ROOT:?set FOREIGN_RUNTIME_ROOT to a built oorexx_foreign_runtime}
P="$REPO/packages"
TESTS=${*:-repository_roundtrip_test.rex mcp_operations_test.rex semantic_mutation_test.rex}
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
OLD='sql = .SemanticSourceSqlCompatibility~new(.NoSQLServerSQL~new(.FederatedDatabaseEngine~new(dbRoot)))'
NEW='sql = .SemanticSourceSqliteIndexPlan~open(dbRoot || "/ssc.sqlite")'
[ "${SSC_INDEX_PLAN:-1}" = 0 ] && NEW='sql = .RexxSqlSqliteSession~open(dbRoot || "/ssc.sqlite")'
export REXX_PATH="$SSC/src:$HERE/src:$HERE/adapters/ssc:$P/oorexx_native_database_backends_v0.1/src:$P/alchemy_objects_v0.8/src:$P/oorexx_crypto_v0.8.3/src:$P/runtime_reference_v0.4/src:$FR/rexx"
export LD_LIBRARY_PATH="$LIB:$FR/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SSC_FAST_CRYPTO=1
n=0
for t in $TESTS; do
  n=$((n + 1))
  [ "$(grep -cF "$OLD" "$SSC/test_live/$t")" = 1 ] || { echo "executor line not found exactly once in $t" >&2; exit 2; }
  [ "$(grep -cF '::requires "NoSQLServer.cls"' "$SSC/test_live/$t")" = 1 ] || { echo "NoSQLServer requires not found exactly once in $t" >&2; exit 2; }
  awk -v old="$OLD" -v new="$NEW" '$0 == old { print new; next } $0 == "::requires \"NoSQLServer.cls\"" { print "::requires \"SemanticSourceSqliteIndexPlan.cls\""; next } { print }' "$SSC/test_live/$t" > "$WORK/$t"
  mkdir -p "$WORK/db$n"
  echo "== $t on Rexx/SQL + SQLite"
  (cd "$WORK" && SSC_TEST_DB="$WORK/db$n" rexx "$t")
done
echo "SSC LIVE TESTS ON REXX/SQL: PASS"

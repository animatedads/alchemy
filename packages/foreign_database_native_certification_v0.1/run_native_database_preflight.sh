#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 --nosql-root DIR [--dbcore-root DIR] [--foreign-root DIR]"
  exit 2
}
NOSQL=""
DBCORE=""
FOREIGN=""
while (($#)); do
  case "$1" in
    --nosql-root) NOSQL="${2:-}"; shift 2 ;;
    --dbcore-root) DBCORE="${2:-}"; shift 2 ;;
    --foreign-root) FOREIGN="${2:-}"; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$NOSQL" && -d "$NOSQL" ]] || usage

echo "=== Native database certification preflight ==="
echo "nosql_root=$NOSQL"
[[ -n "$DBCORE" ]] && echo "dbcore_root=$DBCORE"
[[ -n "$FOREIGN" ]] && echo "foreign_root=$FOREIGN"

echo
echo "=== Host library discovery (informational) ==="
for lib in sqlite3 pq mariadb mysqlclient gdal geos_c proj; do
  found="$(ldconfig -p 2>/dev/null | grep -m1 -E "lib${lib}\.so" || true)"
  if [[ -n "$found" ]]; then
    echo "FOUND $found"
  else
    echo "ABSENT lib${lib}"
  fi
done

echo
echo "=== NoSQL expected dual-provider evidence ==="
if grep -Rqs --include='*.cls' --include='*.rex' 'SQLiteNativeDatabase' "$NOSQL"; then
  echo "PASS existing ooRexx SQLite fallback/reference remains present"
else
  echo "FAIL SQLiteNativeDatabase not found"
  exit 1
fi

if grep -Rqs --include='*.cls' --include='*.rex' -E 'SQLiteForeign|FOREIGN_LIBSQLITE3|libsqlite3' "$NOSQL"; then
  echo "PASS foreign SQLite implementation evidence present"
else
  echo "FAIL no Foreign Runtime/libsqlite3 SQLite implementation evidence"
  exit 1
fi

if grep -Rqs --include='*.cls' --include='*.rex' 'NOSQL_SQLITE_PROVIDER' "$NOSQL"; then
  echo "PASS explicit provider-selection control present"
else
  echo "FAIL NOSQL_SQLITE_PROVIDER selection surface not found"
  exit 1
fi

echo
echo "=== NoSQL owner suite ==="
if [[ -x "$NOSQL/run_tests.sh" ]]; then
  (cd "$NOSQL" && ./run_tests.sh)
elif [[ -f "$NOSQL/run_tests.sh" ]]; then
  (cd "$NOSQL" && bash ./run_tests.sh)
else
  echo "FAIL NoSQL package has no run_tests.sh"
  exit 1
fi

if [[ -n "$DBCORE" ]]; then
  echo
  echo "=== Database Core expected native-provider evidence ==="
  grep -Rqs --include='*.cls' --include='*.rex' -E 'PostgreSQLForeign|libpq|PQexecParams' "$DBCORE" \
    && echo "PASS PostgreSQL native provider evidence present" \
    || { echo "FAIL PostgreSQL native provider evidence absent"; exit 1; }
  grep -Rqs --include='*.cls' --include='*.rex' -E 'MySQLForeign|MariaDBForeign|libmariadb|mysql_stmt_' "$DBCORE" \
    && echo "PASS MySQL/MariaDB native provider evidence present" \
    || { echo "FAIL MySQL/MariaDB native provider evidence absent"; exit 1; }

  if [[ -x "$DBCORE/run_tests.sh" ]]; then
    (cd "$DBCORE" && ./run_tests.sh)
  elif [[ -f "$DBCORE/run_tests.sh" ]]; then
    (cd "$DBCORE" && bash ./run_tests.sh)
  else
    echo "FAIL Database Core package has no run_tests.sh"
    exit 1
  fi
fi

echo
echo "PREFLIGHT COMPLETE"
echo "NOTE: PASS here does not replace focused auto/foreign/native differential and loopback gates in certification_gate.json."

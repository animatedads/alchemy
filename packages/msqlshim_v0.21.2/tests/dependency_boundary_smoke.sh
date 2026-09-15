#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if find "$ROOT" -type f -name 'NoSQLServer.cls' -print -quit | grep -q .; then
  echo 'FAIL NoSQLServer.cls is embedded in msqlshim'
  exit 1
fi
if [ -d "$ROOT/vendor" ]; then
  echo 'FAIL vendor directory exists in msqlshim'
  exit 1
fi
grep -Fq '::requires "NoSQLServer.cls"' "$ROOT/src/MySQLWireServer.cls"
grep -Fq '::requires '\''NoSQLServer.cls'\''' "$ROOT/tests/v019_backend_package_smoke.rex"
echo 'PASS no NoSQLServer source is embedded in msqlshim'
echo 'PASS NoSQLServer is resolved only by package/class reference'
echo 'MSQLSHIM DEPENDENCY BOUNDARY SMOKE PASS'

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${OOREXX_ROOT:?set OOREXX_ROOT to extracted ooRexx r13196 prefix, e.g. /opt/oorexx/usr/local}"
export REXX_HOME="$OOREXX_ROOT"
export LD_LIBRARY_PATH="$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/src:$ROOT/mysql:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
"$ROOT/native/build_mariadb_bulk.sh"
"$OOREXX_ROOT/bin/rexxc" "$ROOT/mysql/MySQLNativeBackend.cls" /tmp/MySQLNativeBackend.cls.bin
"$OOREXX_ROOT/bin/rexxc" "$ROOT/tests/test_mysql_bulk_materialisation.rex" /tmp/test_mysql_bulk_materialisation.rex.bin
"$OOREXX_ROOT/bin/rexx" "$ROOT/tests/test_mysql_bulk_materialisation.rex"

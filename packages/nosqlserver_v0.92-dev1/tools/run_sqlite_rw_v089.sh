#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OOREXX_ROOT:?OOREXX_ROOT must point to ooRexx prefix with bin,include,lib}"
: "${ALCHEMY_ROOT:?ALCHEMY_ROOT must be Alchemy Objects package root}"
: "${CRYPTO_ROOT:?CRYPTO_ROOT must be ooRexx Crypto package root}"
make -C "$HERE/native" OOREXX_PREFIX="$OOREXX_ROOT"
export LD_LIBRARY_PATH="$HERE/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE/src:$HERE/tests:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_ROOT/bin/rexxc" "$HERE/src/NoSQLServer.cls" >/dev/null
"$OOREXX_ROOT/bin/rexxc" "$HERE/src/NoSQLServerSQLiteWritable.cls" >/dev/null
(
 cd "$HERE/tests"
 python3 create_v089_fixture.py
 "$OOREXX_ROOT/bin/rexx" v089_sqlite_wal_rejection.rex
 "$OOREXX_ROOT/bin/rexx" v089_sqlite_rw_contract.rex
 cp fixtures/v074_sqlite_native_fixture.sqlite fixtures/v089_rw_work.sqlite
 "$OOREXX_ROOT/bin/rexx" v089_sqlite_rw_smoke.rex
 rm -f fixtures/v089_new.sqlite
 "$OOREXX_ROOT/bin/rexx" v089_sqlite_create_smoke.rex
 "$OOREXX_ROOT/bin/rexx" v074_sqlite_native_smoke.rex
 "$OOREXX_ROOT/bin/rexx" v060_update_from_smoke.rex
 if [[ "${RUN_EXTENDED_TESTS:-0}" == "1" ]]; then
   for case in v079_alchemy_v08_adoption_smoke.rex v083_db2_isolation_smoke.rex v085_integer_precision_smoke.rex; do
     timeout 60 "$OOREXX_ROOT/bin/rexx" "$case"
   done
 fi
 python3 - <<'PY'
import sqlite3
for name in ("v089_rw_contract.sqlite", "v089_rw_work.sqlite", "v089_new.sqlite"):
    conn = sqlite3.connect('fixtures/' + name)
    assert conn.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert conn.execute('PRAGMA foreign_key_check').fetchall()==[]
    conn.close()
print('SQLITE INDEPENDENT INTEGRITY: PASS')
PY
)

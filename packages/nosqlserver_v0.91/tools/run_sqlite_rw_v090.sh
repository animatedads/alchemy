#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OOREXX_ROOT:?OOREXX_ROOT points to extracted ooRexx prefix}"
: "${ALCHEMY_ROOT:?ALCHEMY_ROOT points to Alchemy Objects root}"
: "${CRYPTO_ROOT:?CRYPTO_ROOT points to Crypto root}"
make -C "$HERE/native" -B OOREXX_PREFIX="$OOREXX_ROOT"
export LD_LIBRARY_PATH="$HERE/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE/src:$HERE/tests:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
export REXX="$OOREXX_ROOT/bin/rexx"
"$OOREXX_ROOT/bin/rexxc" "$HERE/src/NoSQLServer.cls" >/dev/null
"$OOREXX_ROOT/bin/rexxc" "$HERE/src/NoSQLServerSQLiteWritable.cls" >/dev/null
(
 cd "$HERE/tests"
 python3 create_v089_fixture.py
 "$REXX" v089_sqlite_rw_contract.rex
 cp fixtures/v074_sqlite_native_fixture.sqlite fixtures/v089_rw_work.sqlite
 "$REXX" v089_sqlite_rw_smoke.rex
 rm -f fixtures/v089_new.sqlite
 "$REXX" v089_sqlite_create_smoke.rex
 "$REXX" v074_sqlite_native_smoke.rex
 "$REXX" v060_update_from_smoke.rex
 python3 run_v090_concurrency.py
 if [[ "${RUN_EXTENDED_TESTS:-0}" == "1" ]]; then
  for case in v079_alchemy_v08_adoption_smoke.rex v083_db2_isolation_smoke.rex v085_integer_precision_smoke.rex; do
   timeout 60 "$REXX" "$case"
  done
 fi
 python3 - <<'PY'
import sqlite3
for name in ('v089_rw_contract.sqlite','v089_rw_work.sqlite','v089_new.sqlite','v090_wal_concurrent.sqlite'):
 db=sqlite3.connect('fixtures/'+name)
 assert db.execute('pragma integrity_check').fetchone()[0]=='ok',name
 assert db.execute('pragma foreign_key_check').fetchall()==[],name
 db.close()
print('SQLITE 0.90 INDEPENDENT INTEGRITY: PASS')
PY
)

#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$HERE/tools/run_sqlite_rw_v091.sh"
python3 "$HERE/tests/v092_sqlite_rowid_fixture.py"
(
  cd "$HERE/tests"
  export LD_LIBRARY_PATH="$HERE/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export REXX_PATH="$HERE/src:$HERE/tests:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
  "$OOREXX_ROOT/bin/rexx" v092_sqlite_rowid_seek.rex
)
python3 - "$HERE/tests/fixtures/v092_seek.sqlite" <<'PY'
import sqlite3,sys
with sqlite3.connect(sys.argv[1]) as db:
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert db.execute('SELECT body FROM notes WHERE id=1').fetchone()[0]=='updated'
print('NOSQLSERVER V0.92 SQLite integrity: PASS')
PY

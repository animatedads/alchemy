#!/usr/bin/env bash
set -euo pipefail
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
"$HERE/tools/run_sqlite_rw_v090.sh"
export LD_LIBRARY_PATH="$HERE/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$HERE/src:$HERE/tests:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
(
  cd "$HERE/tests"
  python3 - <<'PY'
from pathlib import Path
import sqlite3
p=Path('fixtures/v091_phantom.sqlite')
for filename in (p, Path(str(p)+'-wal'), Path(str(p)+'-shm')): filename.unlink(missing_ok=True)
with sqlite3.connect(p) as db:
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, body TEXT NOT NULL)')
    db.execute("INSERT INTO notes VALUES (1,'alpha')")
PY
  "$OOREXX_ROOT/bin/rexx" v091_sqlite_phantom_guard.rex
  python3 - <<'PY'
import sqlite3
with sqlite3.connect('fixtures/v091_phantom.sqlite') as db:
 assert db.execute('SELECT count(*) FROM notes').fetchone()[0]==0
 assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
print('NOSQLSERVER V0.91 SQLITE GUARD INTEGRITY: PASS')
PY
)

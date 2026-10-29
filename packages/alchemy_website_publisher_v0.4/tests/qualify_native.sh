#!/usr/bin/env bash
# Runtime integration qualification. Never deploys or publishes website content.
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${OOREXX_ROOT:?Set OOREXX_ROOT to the extracted ooRexx installation prefix}"
: "${ALCHEMY_ROOT:?Set ALCHEMY_ROOT to Alchemy Objects package root}"
: "${CRYPTO_ROOT:?Set CRYPTO_ROOT to Crypto package root}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# Explicitly private snapshot temp dir for NoSQLServer v0.90 native backups.
chmod 700 "$TMP"
export TMPDIR="$TMP"
NS="$ROOT/dependencies/nosqlserver_v0.90_sqlite_wal_read_write_candidate.zip"
unzip -q "$NS" -d "$TMP/vendor"
NSROOT="$TMP/vendor/nosqlserver_v090_sqlite_wal_rw"
make -C "$NSROOT/native" -B "OOREXX_PREFIX=$OOREXX_ROOT"
export LD_LIBRARY_PATH="$NSROOT/native:$OOREXX_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="$ROOT/native:$NSROOT/src:$ALCHEMY_ROOT/src:$CRYPTO_ROOT/src:$OOREXX_ROOT/bin${REXX_PATH:+:$REXX_PATH}"
"$OOREXX_ROOT/bin/rexxc" "$ROOT/native/CmsWebsiteSnapshotStore.cls" >/dev/null
DB="$TMP/publisher.sqlite"
"$OOREXX_ROOT/bin/rexx" "$ROOT/native/test_native_store.rex" "$DB"
python3 - "$DB" <<'PY'
import sqlite3,sys
con=sqlite3.connect(sys.argv[1]);mode=con.execute('PRAGMA journal_mode=WAL').fetchone()[0];con.close()
assert mode.lower()=='wal',mode
print('WAL_MODE:',mode)
PY
"$OOREXX_ROOT/bin/rexx" "$ROOT/native/test_native_wal.rex" "$DB"
python3 - "$DB" <<'PY'
import sqlite3,sys
con=sqlite3.connect(sys.argv[1]);
assert con.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
assert con.execute('SELECT COUNT(*) FROM publisher_snapshots').fetchone()[0]==3
assert con.execute('SELECT revision,parent_revision FROM publisher_snapshots ORDER BY revision').fetchall()==[(1,0),(2,1),(3,2)]
con.close()
print('PASS independent SQLite integrity and revision chain')
PY

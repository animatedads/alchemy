#!/usr/bin/env python3
"""Create a conventional SQLite database with an intentionally PK-less relation."""
import sqlite3, pathlib
p=pathlib.Path(__file__).resolve().parent/'fixtures/v089_rw_contract.sqlite'
p.unlink(missing_ok=True)
with sqlite3.connect(p) as db:
    db.execute('CREATE TABLE records (id INTEGER PRIMARY KEY, label TEXT NOT NULL, note BLOB, amount INTEGER)')
    db.execute('CREATE TABLE heap (value TEXT)')
    db.execute("INSERT INTO records (id,label,note,amount) VALUES (1,'first',NULL,1)")
    db.execute("INSERT INTO heap (value) VALUES ('old')")
print(p)

wal=p.with_name('v089_wal.sqlite')
for suffix in ('','-wal','-shm'):
    wal.with_name(wal.name+suffix).unlink(missing_ok=True)
with sqlite3.connect(wal) as db:
    db.execute('CREATE TABLE records (id INTEGER PRIMARY KEY,label TEXT)')
    db.execute('PRAGMA journal_mode=WAL')
    db.commit()

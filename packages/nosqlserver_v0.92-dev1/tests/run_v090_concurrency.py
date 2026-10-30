#!/usr/bin/env python3
"""Exercise committed uncheckpointed WAL pages and concurrent SQLite I/O.
This harness holds a SQLite connection open so WAL frames cannot be treated as
merely checkpointed/main-file data, and changes paired rows atomically while
NoSQLServer SELECTs them from SQLite-managed, transactionally consistent backups.
"""
import os
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import time
import threading

ROOT=pathlib.Path(__file__).resolve().parent
P=ROOT/'fixtures/v090_wal_concurrent.sqlite'
for suffix in ('','-wal','-shm'):
    pathlib.Path(str(P)+suffix).unlink(missing_ok=True)
conn=sqlite3.connect(P, timeout=5)
assert conn.execute('PRAGMA journal_mode=WAL').fetchone()[0]=='wal'
conn.execute('CREATE TABLE live (id INTEGER PRIMARY KEY,label TEXT NOT NULL)')
conn.execute('CREATE TABLE owned (id INTEGER PRIMARY KEY,label TEXT NOT NULL)')
conn.executemany('INSERT INTO live VALUES (?,?)',[(1,'initial'),(2,'initial')]);conn.commit()

stop=threading.Event()
writer_failures=[]
started=threading.Event()
def concurrent_writer():
    c=sqlite3.connect(P, timeout=5)
    try:
        for i in range(1500):
            if stop.is_set(): break
            c.execute('BEGIN IMMEDIATE')
            c.execute('UPDATE live SET label=?',(f'commit-{i:06d}',))
            c.commit()
            started.set()
            time.sleep(0.003)
    except Exception as e: writer_failures.append(repr(e))
    finally: c.close()

thread=threading.Thread(target=concurrent_writer)
thread.start()
assert started.wait(10), 'writer did not commit WAL'
assert pathlib.Path(str(P)+'-wal').exists(), 'test requires active WAL'
proc=subprocess.run([os.environ.get('REXX','rexx'),'v090_sqlite_wal_concurrent.rex'], cwd=ROOT, capture_output=True,text=True,timeout=90)
stop.set();thread.join(timeout=10)
conn.close()
print(proc.stdout,end='')
if proc.stderr:print(proc.stderr,file=sys.stderr,end='')
assert proc.returncode==0, f'Rexx test exit: {proc.returncode}'
assert 'WAL CONCURRENT SNAPSHOT RW: PASS' in proc.stdout
assert not writer_failures,writer_failures
with sqlite3.connect(P) as c:
    assert c.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert c.execute('PRAGMA foreign_key_check').fetchall()==[]
    assert c.execute('SELECT label FROM live WHERE id=1').fetchone()==c.execute('SELECT label FROM live WHERE id=2').fetchone()
    assert c.execute('SELECT COUNT(*) FROM owned').fetchone()[0]==0
    assert c.execute("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='wal_ddl'").fetchone()[0]==0
print('SQLITE V0.90 ACTIVE WAL + CONCURRENT WRITER + INTEGRITY: PASS')

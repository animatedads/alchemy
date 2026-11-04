from pathlib import Path
import sqlite3
p = Path(__file__).resolve().parent / "fixtures/v092_seek.sqlite"
for f in (p, Path(str(p)+"-wal"), Path(str(p)+"-shm")):
    f.unlink(missing_ok=True)
with sqlite3.connect(p) as db:
    db.execute("PRAGMA page_size=512")
    db.execute("CREATE TABLE notes(id INTEGER PRIMARY KEY, body TEXT NOT NULL, blobv BLOB)")
    db.execute("INSERT INTO notes VALUES (?,?,?)", (-9223372036854775808, "minimum", b""))
    db.execute("INSERT INTO notes VALUES (?,?,?)", (-1, "negative", b""))
    db.executemany("INSERT INTO notes VALUES (?,?,?)", ((i, f"note-{i}", b"\x00\xffA\x00" if i==42 else b"") for i in range(1, 10001)))
    assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
print(p)

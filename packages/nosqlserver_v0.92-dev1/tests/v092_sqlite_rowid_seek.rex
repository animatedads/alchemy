/* v0.92-dev1: indexed integer rowid B-tree seeks remain under NoSQL predicate authority. */
numeric digits 50
path = "fixtures/v092_seek.sqlite"
db = .SQLiteNativeDatabase~new(path)
t = db~table("notes")
call assert t \== .nil, "native table"
call assert t~columns[1]~rowidAlias, "rowid alias"
call assert db~pageCount > 80, "multi-page B-tree fixture"
call assert db~rowByRowid("notes", -9223372036854775808)["body"] = "minimum", "negative 64-bit minimum"
call assert db~rowByRowid("notes", -1)["body"] = "negative", "negative rowid"
call assert db~rowByRowid("notes", 1)["body"] = "note-1", "first positive rowid"
call assert db~rowByRowid("notes", 9999)["body"] = "note-9999", "deep multi-page rowid"
call assert db~rowByRowid("notes", 10001) == .nil, "missing high rowid"
call assert db~rowByRowid("notes", 0) == .nil, "missing zero rowid"
call assert db~rowByRowid("notes", -2) == .nil, "missing negative rowid"
call assert db~rowByRowid("notes", "invalid") == .nil, "invalid literal declined"
call assert db~rowByRowid("notes", 42)["blobv"]~hex = "00FF4100", "BLOB retained"

engine = .SQLiteDatabaseEngine~new(path)
call assert engine~table("notes")~definition~rowCount == .nil, "no eager count on discover"
rs = engine~execute("SELECT id,body FROM notes WHERE id=9999")
call check rs, "keyed SELECT"
call assert rs~rows~items = 1, "single candidate"
call assert rs~rows[1]["body"] = "note-9999", "NoSQL projection correct"
call assert rs~accessPath = "SQLITE_NATIVE_ROWID_SEEK", "seek path reported"
call assert rs~rowsScanned = 1, "single candidate counted"
rs = engine~execute("SELECT id FROM notes WHERE id=555555")
call check rs, "missing key"
call assert rs~rows~items = 0, "missing key invisible"
call assert rs~accessPath = "SQLITE_NATIVE_ROWID_SEEK", "missing key uses index"
rs = engine~execute("SELECT id,body FROM notes WHERE id=-1")
call check rs, "negative key"
call assert rs~rows[1]["body"] = "negative", "negative key projection"
rs = engine~execute("SELECT id FROM notes WHERE id=42")
call check rs, "BLOB row key"
call assert rs~rows[1]["id"] = 42, "BLOB row key result"
rs = engine~execute("SELECT id FROM notes WHERE id >= 9999")
call check rs, "range scan fallback"
call assert rs~accessPath = "SQLITE_NATIVE_SCAN", "unsupported predicate uses scan"
call assert rs~rows~items = 2, "range filter still correct"
call assert engine~tableRowCount("notes") = 10002, "on-demand exact count"
call assert engine~table("notes")~definition~rowCount = 10002, "count cached in definition"

writable = .SQLiteWritableDatabaseEngine~new(path)
rs = writable~execute("SELECT body FROM notes WHERE id=1")
call check rs, "writable selected SQLite index"
call assert rs~accessPath = "SQLITE_NATIVE_ROWID_SEEK", "writable path uses indexed row seek"
call assert rs~rows[1]["body"] = "note-1", "writable read correct"
rs = writable~execute("UPDATE notes SET body='updated' WHERE id=1")
call check rs, "guarded update still works"
rs = writable~execute("SELECT body FROM notes WHERE id=1")
call check rs, "read after indexed mutation"
call assert rs~rows[1]["body"] = "updated", "committed indexed mutation visible"
say "NOSQLSERVER V0.92 SQLITE INTEGER ROWID SEEK: PASS"
exit 0
check: procedure
 use arg rs, label
 if rs~status \= .Error~SUCCESS then do
  say "FAIL" label rs~status rs~error rs~message
  exit 1
 end
 return
assert: procedure
 use arg condition, label
 if \condition then do
  say "FAIL" label
  exit 1
 end
 return
::requires "../src/NoSQLServerSQLiteWritable.cls"

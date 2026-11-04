/* NoSQLServer v0.89 SQLite READ / WRITE qualification. */
path = "fixtures/v089_rw_work.sqlite"
engine = .SQLiteWritableDatabaseEngine~new(path)
sql = .NoSQLServerSQL~new(engine)
say "engine=" engine~version~storage
call check sql~execute("INSERT INTO typed (id,neg,big,realv,txt,nullable) VALUES (501,-17,9223372036854775807,1.25,'new note',NULL)"), "insert"
q = sql~execute("SELECT id,txt,neg FROM typed WHERE id=501")
call check q, "select after insert"
call assert q~rows~items = 1, "inserted record visible"
call assert q~rows[1]["txt"] = "new note", "inserted record text"
call check sql~execute("UPDATE typed SET txt='changed note',neg=-18 WHERE id=501"), "update"
q = sql~execute("SELECT id,txt,neg FROM typed WHERE id=501")
call check q, "select after update"
call assert q~rows[1]["txt"] = "changed note", "updated text"
call assert q~rows[1]["neg"] = -18, "updated integer"
call check sql~execute("DELETE FROM typed WHERE id=501"), "delete"
q = sql~execute("SELECT id FROM typed WHERE id=501")
call check q, "select after delete"
call assert q~rows~items = 0, "delete persisted"
call check sql~execute("CREATE TABLE notes_rw (id INTEGER PRIMARY KEY, title TEXT NOT NULL)"), "create"
call check sql~execute("INSERT INTO notes_rw (id,title) VALUES (1,'hello')"), "create insert"
call check sql~execute("UPDATE notes_rw SET title='updated' WHERE id=1"), "create update"
q = sql~execute("SELECT title FROM notes_rw WHERE id=1")
call check q, "create select"
call assert q~rows[1]["title"] = "updated", "created table read back"
call check sql~execute("DROP TABLE notes_rw"), "drop"
call assert engine~table("notes_rw") == .nil, "dropped table invisible"
reopen = .SQLiteDatabaseEngine~new(path)
q = reopen~execute("SELECT id FROM typed WHERE id=501")
call check q, "reopen read-only"
call assert q~rows~items = 0, "write durable in read-only reader"
say "NOSQLSERVER V0.89 SQLITE RW: PASS"
exit 0
check: procedure
 use arg rs, label
 if rs~status \= .Error~SUCCESS then do
  say "FAIL" label rs~status rs~error rs~message
  exit 1
 end
 return
assert: procedure
 use arg cond, label
 if \cond then do
  say "FAIL" label
  exit 1
 end
 return
::requires "../src/NoSQLServerSQLiteWritable.cls"

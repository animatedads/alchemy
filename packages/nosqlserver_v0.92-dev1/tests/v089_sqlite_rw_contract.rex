/* NoSQLServer v0.89 — SQLite native writable storage acceptance. */
engine=.SQLiteWritableDatabaseEngine~new("fixtures/v089_rw_contract.sqlite")
sql=.NoSQLServerSQL~new(engine)
call assert engine~version~storage="SQLITE_NATIVE_READWRITE", "opt-in writable backend"

r=sql~execute("INSERT INTO records (id,label,note,amount) VALUES (5,'five',NULL,5),(6,'six',NULL,6)")
call ok r,"multi INSERT"
call assert r~affectedRows=2, "two committed inserts"
r=sql~execute("UPDATE records SET label='all done' WHERE id>=5")
call ok r,"multi-row update"
call assert r~affectedRows=2,"two updates in atomic batch"
r=sql~execute("INSERT INTO records (id,label,note) VALUES (7,'new','x'),(5,'duplicate','x')")
call assert r~status\=.Error~SUCCESS,"duplicate PK rejected"
r=sql~execute("SELECT id FROM records WHERE id=7")
call ok r, "rollback query"
call assert r~rows~items=0,"whole duplicate INSERT batch rolled back"

r=sql~execute("UPDATE records SET label='broken' WHERE id=5")
call ok r,"single-row update"
r=sql~execute("SELECT label FROM records WHERE id=5")
call ok r,"read updated"
call assert r~rows[1]["label"]="broken","committed update visible"

values=.table~new
values["id"] = 8
values["label"] = "O'Reilly; DELETE FROM records; --"
values["note"] = .SQLiteNativeBlob~new("00FEFF810041"x)
r=engine~insert("records",values)
call ok r, "binary blob insert"
r=sql~execute("SELECT label,note FROM records WHERE id=8")
call ok r,"read binary blob"
call assert r~rows[1]["label"] = "O'Reilly; DELETE FROM records; --", "SQL injection remained text"
call assert r~rows[1]["note"]~hex="00FEFF810041", "binary BLOB exact roundtrip"

r=sql~execute("UPDATE records SET amount=-9223372036854775808 WHERE id=8")
call ok r,"signed INT64 minimum"
r=sql~execute("SELECT amount FROM records WHERE id=8")
call ok r,"read signed INT64"
call assert r~rows[1]["amount"]~string=="-9223372036854775808", "INT64 losslessness"

-- Case-insensitive SQL identifier names are normalized to table metadata.
r=sql~execute("INSERT INTO records (ID,LABEL) VALUES (9,'mixedCase')")
call ok r,"case-insensitive insert"
r=sql~execute("UPDATE records SET LABEL='revisedCase' WHERE id=9")
call ok r,"case-insensitive update"
r=sql~execute("SELECT label FROM records WHERE id=9")
call ok r,"case-insensitive verification"
call assert r~rows[1]["label"] = "revisedCase", "canonical name mapping"
r=sql~execute("DELETE FROM records WHERE id=9")
call ok r,"case cleanup"

r=sql~execute("DELETE FROM records WHERE id>=5")
call ok r,"delete matching rows"
call assert r~affectedRows=3,"delete count"
r=sql~execute("SELECT id FROM records")
call ok r,"remaining rows"
call assert r~rows~items=1,"delete retained nonmatching row"

r=sql~execute("UPDATE heap SET value='invalid' WHERE value='old'")
call assert r~error=.Error~SQLUNSUPPORTED,"no-PK update fails closed"
r=sql~execute("DELETE FROM heap WHERE value='old'")
call assert r~error=.Error~SQLUNSUPPORTED,"no-PK delete fails closed"

r=sql~execute("CREATE TABLE from_nosql (id INTEGER PRIMARY KEY,label TEXT NOT NULL)")
call ok r,"NoSQL CREATE TABLE"
r=sql~execute("INSERT INTO from_nosql (id,label) VALUES (1,'from own schema')")
call ok r,"new table insert"
r=sql~execute("DROP TABLE from_nosql")
call ok r,"NoSQL DROP TABLE"

say "NOSQLSERVER V0.89 SQLITE ATOMIC RW CONTRACT: PASS"
exit 0
ok: procedure
 use arg rs, label
 if rs~status\=.Error~SUCCESS then do
  say "FAIL" label rs~status rs~error rs~message
  exit 1
 end
 return
assert: procedure
 use arg cond,label
 if \cond then do
  say "FAIL" label
  exit 1
 end
 return
::requires "../src/NoSQLServerSQLiteWritable.cls"

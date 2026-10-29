/* Explicit NoSQLServer-backed SQLite database provisioning */
file="fixtures/v089_new.sqlite"
engine=.SQLiteWritableDatabaseEngine~create(file)
sql=.NoSQLServerSQL~new(engine)
call ok sql~execute("CREATE TABLE newnotes (id INTEGER PRIMARY KEY,body TEXT NOT NULL)"),"create"
call ok sql~execute("INSERT INTO newnotes (id,body) VALUES (1,'saved')"),"insert"
call ok sql~execute("UPDATE newnotes SET body='saved again' WHERE id=1"),"update"
q=sql~execute("SELECT body FROM newnotes WHERE id=1")
call ok q,"select"
if q~rows[1]["body"] \= "saved again" then exit 2
say "NOSQLSERVER V0.89 SQLITE BOOTSTRAP: PASS"
exit 0
ok: procedure
 use arg r,label
 if r~status \= .Error~SUCCESS then do
  say "FAIL" label r~status r~message
  exit 1
 end
 return
::requires "../src/NoSQLServerSQLiteWritable.cls"

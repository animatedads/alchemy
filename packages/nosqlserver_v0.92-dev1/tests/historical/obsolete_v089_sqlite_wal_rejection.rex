/* Writer must not mutate a WAL-mode file the native binary reader cannot track. */
engine = .SQLiteWritableDatabaseEngine~new("fixtures/v089_wal.sqlite")
r = engine~execute("INSERT INTO records (id,label) VALUES (2,'must not commit')")
if r~status = .Error~SUCCESS then do
 say "FAIL WAL was accepted"
 exit 1
end
if r~message~translate~pos("WAL") = 0 then do
 say "FAIL unexpected WAL error" r~error r~message
 exit 2
end
say "NOSQLSERVER V0.89 WAL WRITE REJECTION: PASS"
exit 0
::requires "../src/NoSQLServerSQLiteWritable.cls"

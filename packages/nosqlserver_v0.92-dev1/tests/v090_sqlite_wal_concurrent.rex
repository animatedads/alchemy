/* NoSQLServer v0.90: WAL commits must be visible through coherent snapshots;
 * mutations remain governed by NoSQLServer and executable while the external
 * writer continues modifying a different table. */
engine=.SQLiteWritableDatabaseEngine~new("fixtures/v090_wal_concurrent.sqlite")
sql=.NoSQLServerSQL~new(engine)

r=sql~execute("SELECT id,label FROM live ORDER BY id")
call ok r,"live WAL snapshot"
call assert r~rows~items=2, "live row count"
call assert r~rows[1]["label"]=r~rows[2]["label"], "one consistent WAL snapshot"

r=sql~execute("INSERT INTO owned (id,label) VALUES (10,'written in WAL')")
call ok r,"concurrent WAL INSERT"
r=sql~execute("SELECT label FROM owned WHERE id=10")
call ok r,"concurrent WAL INSERT readback"
call assert r~rows~items=1, "insert row visible"
call assert r~rows[1]["label"]="written in WAL", "WAL INSERT value"

r=sql~execute("UPDATE owned SET label='updated in WAL' WHERE id=10")
call ok r,"concurrent WAL UPDATE"
r=sql~execute("SELECT label FROM owned WHERE id=10")
call ok r,"concurrent WAL UPDATE readback"
call assert r~rows[1]["label"]="updated in WAL", "WAL UPDATE value"

-- Direct engine API also refreshes its snapshot, rather than reusing one
-- acquired during an earlier SQL statement.
do i=1 to 14
  j=engine~selectWhere("live", .nil)
  call ok j,"direct coherent read"
  call assert j~rows~items=2,"direct row count"
  call assert j~rows[1]["label"]==j~rows[2]["label"],"direct fresh snapshot"
end

-- Verify that statements do not combine rows from different commits.
do i=1 to 55
  r=sql~execute("SELECT id,label FROM live ORDER BY id")
  call ok r,"repeated coherent read"
  call assert r~rows~items=2, "stable live row count"
  call assert r~rows[1]["label"]==r~rows[2]["label"], "read saw no mixed-epoch rows"
end

r=sql~execute("DELETE FROM owned WHERE id=10")
call ok r,"concurrent WAL DELETE"
r=sql~execute("SELECT id FROM owned WHERE id=10")
call ok r,"concurrent WAL DELETE readback"
call assert r~rows~items=0,"WAL delete visible"

r=sql~execute("CREATE TABLE wal_ddl (id INTEGER PRIMARY KEY, label TEXT)")
call ok r,"WAL schema CREATE"
r=sql~execute("INSERT INTO wal_ddl (id,label) VALUES (1,'new relation')")
call ok r,"WAL schema write"
r=sql~execute("SELECT label FROM wal_ddl WHERE id=1")
call ok r,"WAL schema read"
call assert r~rows[1]["label"]="new relation","WAL schema projection"
r=sql~execute("DROP TABLE wal_ddl")
call ok r,"WAL schema DROP"

say "NOSQLSERVER V0.90 WAL CONCURRENT SNAPSHOT RW: PASS"
exit 0
ok: procedure
  use arg rs, label
  if rs~status \=.Error~SUCCESS then do
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

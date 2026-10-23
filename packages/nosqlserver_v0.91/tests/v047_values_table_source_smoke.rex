root=.NoSQLServerTestSupport~createBlankDatabase("v047")
sql=.NoSQLServerSQL~new(.FileDatabaseEngine~new(root))

call ok sql~execute("CREATE TABLE person (id INTEGER PRIMARY KEY, name VARCHAR)")
call ok sql~execute("INSERT INTO person VALUES (1,'one'),(2,'two')")

q="SELECT v.id,v.note,p.name FROM (VALUES (2,'found'),(3,'missing')) AS v(id,note) LEFT JOIN person p ON p.id=v.id ORDER BY v.id"
r=sql~execute(q)
call assert r~status=.Error~SUCCESS, "VALUES source LEFT JOIN"
call assert r~rows~items=2, "VALUES row count"
call assert r~rows[1]["v.id"]=2, "first id"
call assert r~rows[1]["v.note"]="found", "first note"
call assert r~rows[1]["p.name"]="two", "matched value"
call assert r~rows[2]["v.id"]=3, "second id"
call assert r~rows[2]["v.note"]="missing", "second note"
call assert r~rows[2]["p.name"]==.nil, "LEFT JOIN null extension"

db=.FileDatabaseEngine~new(root)
call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("VALUES_TABLE_SOURCE"), "VALUES survives newer release"
call assert db~version~supports("VALUES_TABLE_SOURCE"), "VALUES capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.47 VALUES TABLE SOURCE SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "setup"
  return
assert: procedure
  use arg condition,message
  if \condition then do
    say "ASSERT FAILED:" message
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"

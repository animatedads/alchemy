root=.NoSQLServerTestSupport~createBlankDatabase("v048")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE customer (id INTEGER PRIMARY KEY, name VARCHAR, note VARCHAR)")

dataPath=root || "/tables/customer/data"
size0=stream(dataPath,"c","query size")

call ok sql~execute("INSERT INTO customer VALUES (1,'one','simple')")
size1=stream(dataPath,"c","query size")
call assert size1>size0, "first append grows file"

call ok sql~execute("INSERT INTO customer VALUES (2,'two,quoted','has ""quote"" and comma')")
size2=stream(dataPath,"c","query size")
call assert size2>size1, "second append grows file"

q=sql~execute("SELECT * FROM customer ORDER BY id")
call assert q~rows~items=2, "two rows"
call assert q~rows[2]["name"]="two,quoted", "CSV comma survives"
call assert q~rows[2]["note"]='has "quote" and comma', "CSV quote survives"

-- Multi-row INSERT deliberately remains on the whole-file atomic publication path.
call ok sql~execute("INSERT INTO customer VALUES (3,'three','a'),(4,'four','b')")
q=sql~execute("SELECT id FROM customer ORDER BY id")
call assert q~rows~items=4, "multi row still works"

call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("APPEND_ONLY_SINGLE_INSERT"), "append insert survives newer release"
call assert db~version~supports("APPEND_ONLY_SINGLE_INSERT"), "append capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.48 APPEND INSERT SMOKE: OK"
exit 0

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "operation"
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

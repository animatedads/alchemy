root=.NoSQLServerTestSupport~createBlankDatabase("v062")
db=.FileDatabaseEngine~new(root)
sql=.NoSQLServerSQL~new(db)

call ok sql~execute("CREATE TABLE customer (id INTEGER PRIMARY KEY, name VARCHAR)")
call ok sql~execute("INSERT INTO customer VALUES (1,'one')")
call verifyJournal root, "customer", 1, "INSERT"

call ok sql~execute("UPDATE customer SET name='uno' WHERE id=1")
call verifyJournal root, "customer", 2, "UPDATE"

call ok sql~execute("DELETE FROM customer WHERE id=1")
call verifyJournal root, "customer", 3, "DELETE"

call assert db~version~product="NoSQLServer", "version product"
call assert db~version~supports("JOURNAL_UTC_TIMESTAMP"), "timestamp capability"

ignore=.NoSQLServerTestSupport~removeDatabase(root)
say "NOSQLSERVER V0.62 JOURNAL TIMESTAMP SMOKE: OK"
exit 0

verifyJournal: procedure
  use arg root, tableName, generation, operation
  fileName=generation~format(10,0)~strip~changestr(" ","0") || ".yaml"
  journal=.Yaml~new~parseFile(root || "/tables/" || tableName || "/journal/" || fileName)
  call assert journal["generation"]=generation, "journal generation" generation
  call assert journal["operation"]=operation, "journal operation" operation
  stamp=journal["timestamp"]
  call assert stamp \== .nil, "timestamp present" generation
  call assert stamp~length>=27, "timestamp precision" stamp
  call assert stamp~substr(5,1)="-", "timestamp date" stamp
  call assert stamp~substr(8,1)="-", "timestamp date separator" stamp
  call assert stamp~substr(11,1)="T", "timestamp T separator" stamp
  call assert stamp~pos(".")>0, "timestamp fractional seconds" stamp
  call assert stamp~right(1)="Z", "timestamp UTC Z" stamp
  return

ok: procedure
  use arg rs
  call assert rs~status=.Error~SUCCESS, "operation"
  return

assert: procedure
  use arg condition,message,detail=""
  if \condition then do
    say "ASSERT FAILED:" message detail
    exit 1
  end
  return

::requires "../src/NoSQLServer.cls"
::requires "TestSupport.cls"
